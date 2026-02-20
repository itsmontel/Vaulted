import AVFoundation
import Combine
import Foundation

// MARK: - AudioService
@MainActor
final class AudioService: NSObject, ObservableObject {

    // MARK: - Published state
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var permissionGranted: Bool? = nil   // nil = not determined
    /// Normalized 0...1 for current input level; used for live waveform.
    @Published var recordingLevel: Float = 0
    /// Rolling buffer of recent levels for waveform display (oldest first).
    @Published var recordingLevels: [Float] = []
    @Published var recordingElapsed: TimeInterval = 0

    // MARK: - Private
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var tempRecordingURL: URL?
    private var playbackTimer: Timer?
    private var playbackCompletionHandler: (() -> Void)?
    private var meterTimer: Timer?
    private let maxLevelSamples = 80

    // MARK: - Request mic permission (AVAudioSession for iOS 16 compatibility)
    func requestPermission() async {
        let session = AVAudioSession.sharedInstance()
        let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            session.requestRecordPermission { continuation.resume(returning: $0) }
        }
        permissionGranted = granted
    }

    func checkPermission() {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:   permissionGranted = true
        case .denied:    permissionGranted = false
        case .undetermined: permissionGranted = nil
        @unknown default: permissionGranted = nil
        }
    }

    // MARK: - Recording
    func startRecording() throws {
        guard permissionGranted == true else { throw AudioError.permissionDenied }

        let session = AVAudioSession.sharedInstance()
        // Voice chat mode enables automatic gain control for louder, clearer voice notes
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
        try session.setActive(true)
        
        // Set preferred sample rate for speech recognition
        try session.setPreferredSampleRate(44100)
        try session.setPreferredIOBufferDuration(0.005) // Lower latency

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        // Optimized settings for speech recognition
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,  // High sample rate for better quality
            AVNumberOfChannelsKey: 1,  // Mono is better for speech
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
            AVEncoderBitRateKey: 128000,  // Higher bitrate for better quality
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]

        recorder = try AVAudioRecorder(url: tempURL, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.record()

        tempRecordingURL = tempURL
        isRecording = true
        recordingLevel = 0
        recordingLevels = []
        recordingElapsed = 0
        startMeterTimer()
    }

    private func startMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }
        RunLoop.main.add(meterTimer!, forMode: .common)
    }

    private func updateMeters() {
        guard let recorder = recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)
        // dB: roughly -160 (silence) to 0 (clip). Map to 0...1 with soft curve.
        let normalized = max(0, min(1, (power + 55) / 55))
        recordingLevel = normalized
        recordingElapsed = recorder.currentTime
        recordingLevels.append(normalized)
        if recordingLevels.count > maxLevelSamples {
            recordingLevels.removeFirst()
        }
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    /// Returns (audioFileName, duration). Moves file to Documents/Audio/<cardId>.m4a
    func stopRecording(cardId: UUID) throws -> (fileName: String, duration: Double) {
        guard let recorder, let tempURL = tempRecordingURL else {
            throw AudioError.noActiveRecording
        }
        let dur = recorder.currentTime
        stopMeterTimer()
        recorder.stop()
        self.recorder = nil
        isRecording = false
        recordingLevel = 0
        recordingLevels = []
        recordingElapsed = 0

        let fileName = "\(cardId.uuidString).m4a"
        let destURL = AudioDirectoryHelper.audioDirectory.appendingPathComponent(fileName)

        try? FileManager.default.removeItem(at: destURL)
        try FileManager.default.moveItem(at: tempURL, to: destURL)
        tempRecordingURL = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        return (fileName, dur)
    }

    func cancelRecording() {
        stopMeterTimer()
        recorder?.stop()
        if let url = tempRecordingURL { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        tempRecordingURL = nil
        isRecording = false
        recordingLevel = 0
        recordingLevels = []
        recordingElapsed = 0
    }

    // MARK: - Playback
    func play(url: URL, onFinish: (() -> Void)? = nil) throws {
        stopPlayback()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)

        player = try AVAudioPlayer(contentsOf: url)
        player?.delegate = self
        player?.prepareToPlay()
        duration = player?.duration ?? 0
        playbackCompletionHandler = onFinish
        player?.play()
        isPlaying = true
        currentTime = 0

        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }

    func pause() {
        player?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
    }

    func resume() {
        player?.play()
        isPlaying = true
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.currentTime = self?.player?.currentTime ?? 0
            }
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        isPlaying = false
        currentTime = 0
        playbackTimer?.invalidate()
        playbackTimer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Playback waveform (precomputed from file)
    /// Load normalized amplitude samples (e.g. 60 bars) for waveform display. Runs off main thread.
    static func loadPlaybackWaveformSamples(from url: URL, barCount: Int = 60) async -> [Float] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let result = AudioWaveformHelper.computeWaveformSamples(from: url, barCount: barCount)
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Audio waveform helper (runs off main actor)
private enum AudioWaveformHelper {
    static func computeWaveformSamples(from url: URL, barCount: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0 else { return [] }
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return [] }
        guard (try? file.read(into: buffer)) != nil else { return [] }

        let channelCount = Int(format.channelCount)
        let frames = Int(buffer.frameLength)
        guard frames > 0, channelCount > 0 else { return [] }

        var samples: [Float] = []
        if let channelData = buffer.floatChannelData {
            for f in 0..<frames {
                var sum: Float = 0
                for c in 0..<channelCount { sum += abs(channelData[c][f]) }
                samples.append(sum / Float(channelCount))
            }
        } else if let channelData = buffer.int16ChannelData {
            let scale: Float = 1 / 32768
            for f in 0..<frames {
                var sum: Float = 0
                for c in 0..<channelCount { sum += abs(Float(channelData[c][f]) * scale) }
                samples.append(sum / Float(channelCount))
            }
        } else { return [] }

        let step = max(1, samples.count / barCount)
        var bars: [Float] = []
        for i in 0..<barCount {
            let start = i * step
            let end = min(start + step, samples.count)
            guard start < end else { bars.append(0); continue }
            let slice = samples[start..<end]
            let avg = slice.reduce(0, +) / Float(slice.count)
            bars.append(avg)
        }
        let maxVal = bars.max() ?? 1
        if maxVal > 0 { bars = bars.map { $0 / maxVal } }
        return bars
    }
}

// MARK: - AVAudioRecorderDelegate
extension AudioService: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in self.isRecording = false }
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.currentTime = 0
            self.playbackTimer?.invalidate()
            self.playbackCompletionHandler?()
        }
    }
}

// MARK: - Errors
enum AudioError: LocalizedError {
    case permissionDenied
    case noActiveRecording

    var errorDescription: String? {
        switch self {
        case .permissionDenied: return "Microphone access is required. Please enable it in Settings."
        case .noActiveRecording: return "No recording in progress."
        }
    }
}
