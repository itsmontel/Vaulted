import AVFoundation
import Foundation
import Speech

// MARK: - SpeechTranscriptionService
/// On-device speech-to-text using Apple's Speech framework.
/// Audio is always split into 28-second chunks because the framework silently drops the
/// beginning of single-file requests longer than ~30 seconds (confirmed behaviour
/// where e.g. a 52-second file only returns seconds 30–52).
@MainActor
final class SpeechTranscriptionService {

    static let shared = SpeechTranscriptionService()

    /// Chunk length in seconds. Keep well under 30 s — Apple's Speech framework
    /// has a silent-drop bug on the leading portion of longer single-file requests.
    private static let chunkDuration: TimeInterval = 28
    /// 1-second overlap so words at a chunk boundary are never cut off.
    private static let chunkOverlap: TimeInterval = 1

    private init() {}

    /// Request speech recognition authorization. Call before transcribing.
    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// Transcribe audio file to text. Returns nil if unavailable or on error.
    /// All audio — even short clips — goes through the chunking pipeline so that
    /// the framework's leading-drop bug never affects the result.
    func transcribe(audioURL: URL) async -> String? {
        let duration = Self.audioDuration(url: audioURL) ?? 0

        let preferredLocale = Locale.current
        guard let recognizer = SFSpeechRecognizer(locale: preferredLocale),
              recognizer.isAvailable else {
            let preferredLanguageCode: String
            if #available(iOS 16.0, *) {
                preferredLanguageCode = preferredLocale.language.languageCode?.identifier ?? ""
            } else {
                preferredLanguageCode = preferredLocale.languageCode ?? ""
            }
            if let fallback = SFSpeechRecognizer.supportedLocales().first(where: { locale in
                let code: String
                if #available(iOS 16.0, *) { code = locale.language.languageCode?.identifier ?? "" }
                else { code = locale.languageCode ?? "" }
                return code == preferredLanguageCode
            }),
               let fallbackRecognizer = SFSpeechRecognizer(locale: fallback),
               fallbackRecognizer.isAvailable {
                return await transcribeInChunks(recognizer: fallbackRecognizer, audioURL: audioURL, duration: duration)
            }
            return nil
        }

        // Always chunk — even a 10-second clip goes through the same safe path.
        return await transcribeInChunks(recognizer: recognizer, audioURL: audioURL, duration: duration)
    }

    // MARK: - Chunked transcription

    /// Split audio into <=28-second chunks, transcribe each, stitch together.
    private func transcribeInChunks(recognizer: SFSpeechRecognizer, audioURL: URL, duration: TimeInterval) async -> String? {
        let step = Self.chunkDuration - Self.chunkOverlap
        var start: TimeInterval = 0
        var parts: [String] = []

        while start < duration {
            let chunkEnd        = min(start + Self.chunkDuration, duration)
            let segmentDuration = chunkEnd - start
            guard segmentDuration >= 2 else { break }   // skip sub-2-second tail

            guard let segmentURL = await exportSegment(from: audioURL, start: start, duration: segmentDuration) else {
                start += step
                continue
            }
            defer { try? FileManager.default.removeItem(at: segmentURL) }

            if let text = await performTranscription(recognizer: recognizer,
                                                     audioURL: segmentURL,
                                                     duration: segmentDuration),
               !text.isEmpty {
                parts.append(text)
            }
            start += step
        }

        guard !parts.isEmpty else { return nil }
        return stitchParts(parts)
    }

    /// Join chunk transcriptions, removing words duplicated by the 1-second overlap.
    private func stitchParts(_ parts: [String]) -> String {
        var joined = parts[0]
        for i in 1..<parts.count {
            let next      = parts[i]
            let prevWords = joined.split(separator: " ").map(String.init)
            let nextWords = next.split(separator: " ").map(String.init)
            // 1-second overlap at normal speaking pace = ~3-5 words; search up to 10.
            let window       = min(10, min(prevWords.count, nextWords.count))
            var overlapCount = 0
            for length in stride(from: window, through: 1, by: -1) {
                let tail = Array(prevWords.suffix(length)).map { $0.lowercased() }
                let head = Array(nextWords.prefix(length)).map { $0.lowercased() }
                if tail == head { overlapCount = length; break }
            }
            let trimmed = overlapCount > 0
                ? nextWords.dropFirst(overlapCount).joined(separator: " ")
                : next
            if !trimmed.isEmpty { joined += " " + trimmed }
        }
        return joined
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Audio utilities

    private static func audioDuration(url: URL) -> TimeInterval? {
        let asset = AVURLAsset(url: url, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        let d = asset.duration
        guard d.isNumeric else { return nil }
        return CMTimeGetSeconds(d)
    }

    /// Export [start, start+duration) of audio to a temporary M4A file.
    private func exportSegment(from sourceURL: URL, start: TimeInterval, duration: TimeInterval) async -> URL? {
        let asset = AVURLAsset(url: sourceURL, options: [AVURLAssetPreferPreciseDurationAndTimingKey: true])
        guard let exportSession = AVAssetExportSession(asset: asset,
                                                       presetName: AVAssetExportPresetAppleM4A)
        else { return nil }

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        exportSession.outputURL      = outURL
        exportSession.outputFileType = .m4a
        exportSession.timeRange      = CMTimeRange(
            start:    CMTime(seconds: start,    preferredTimescale: 600),
            duration: CMTime(seconds: duration, preferredTimescale: 600)
        )
        try? await exportSession.export()
        guard exportSession.status == .completed else { return nil }
        return outURL
    }

    // MARK: - Core recognition

    private func performTranscription(recognizer: SFSpeechRecognizer,
                                      audioURL: URL,
                                      duration: TimeInterval = 0) async -> String? {
        let request      = SFSpeechURLRecognitionRequest(url: audioURL)
        request.taskHint = .dictation
        // Do NOT force on-device recognition — the on-device model has an even shorter
        // reliable audio window and may drop audio more aggressively than the server model.
        request.shouldReportPartialResults = true   // salvage best-effort if isFinal never fires
        request.contextualStrings = [
            "note", "notes", "idea", "ideas", "work", "journal", "today", "tomorrow",
            "remember", "think", "thought", "important", "meeting", "task", "todo",
            "vaulted", "inbox", "private", "voice", "recording"
        ]

        // Timeout = chunk duration + 20-second grace, clamped to [30 s, 60 s].
        let timeoutSecs        = min(60.0, max(30.0, duration + 20.0))
        let timeoutNanoseconds = UInt64(timeoutSecs) * 1_000_000_000

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                var didResume   = false
                var bestPartial = ""

                func resumeOnce(_ value: String?) {
                    guard !didResume else { return }
                    didResume = true
                    continuation.resume(returning: value)
                }

                // Retain the task — `_ =` lets ARC free it before recognition finishes.
                let task = recognizer.recognitionTask(with: request) { result, error in
                    if let result = result {
                        let text = result.bestTranscription.formattedString
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                            .replacingOccurrences(of: "  ", with: " ")
                        if !text.isEmpty { bestPartial = text }
                        if result.isFinal { resumeOnce(text.isEmpty ? nil : text); return }
                    }

                    if let error = error {
                        let nsError = error as NSError
                        let isFatal = (nsError.domain == "kAFAssistantErrorDomain" ||
                                       nsError.domain == "com.apple.SpeechRecognition") &&
                                      [216, 201, 209].contains(nsError.code)
                        // Always resume on any error — original code left non-listed errors
                        // hanging until the timeout, silently losing that chunk's text.
                        resumeOnce(isFatal || bestPartial.isEmpty ? nil : bestPartial)
                    }
                }

                // Cancel the retained task on timeout; return best partial seen so far.
                Task {
                    try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                    guard !didResume else { return }
                    task.cancel()
                    resumeOnce(bestPartial.isEmpty ? nil : bestPartial)
                }
            }
        } onCancel: { }
    }
}