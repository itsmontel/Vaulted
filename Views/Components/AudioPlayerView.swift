import SwiftUI

// MARK: - AudioPlayerView
struct AudioPlayerView: View {
    @ObservedObject var audioService: AudioService
    let audioURL: URL?
    let totalDuration: Double

    @State private var waveformSamples: [Float] = []

    var body: some View {
        VStack(spacing: 10) {
            // Waveform (seekable) or fallback progress bar
            GeometryReader { geo in
                let w = geo.size.width
                let h: CGFloat = 32
                if !waveformSamples.isEmpty {
                    PlaybackWaveformView(
                        levels: waveformSamples,
                        progress: displayDuration > 0 ? (audioService.currentTime / displayDuration) : 0
                    )
                    .frame(height: h)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let ratio = min(1, max(0, val.location.x / w))
                                let time = ratio * displayDuration
                                audioService.seek(to: time)
                            }
                    )
                } else {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.borderMuted)
                            .frame(height: 6)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentGold)
                            .frame(width: progressWidth(in: w), height: 6)
                    }
                    .frame(height: 6)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { val in
                                let ratio = min(1, max(0, val.location.x / w))
                                let time = ratio * displayDuration
                                audioService.seek(to: time)
                            }
                    )
                }
            }
            .frame(height: 32)
            .onChange(of: audioURL?.path) { _ in loadWaveform() }
            .onAppear { loadWaveform() }

            HStack {
                // Play/Pause
                Button {
                    if let url = audioURL {
                        if audioService.isPlaying {
                            audioService.pause()
                        } else if audioService.currentTime > 0 {
                            audioService.resume()
                        } else {
                            try? audioService.play(url: url)
                        }
                    }
                } label: {
                    Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.inkPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.borderMuted.opacity(0.4))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                // Time display
                HStack(spacing: 4) {
                    Text(formatTime(audioService.currentTime))
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                    Text("/")
                        .font(.cardCaption)
                        .foregroundColor(.borderMuted)
                    Text(formatTime(displayDuration))
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                }
            }
        }
        .padding(14)
        .background(Color.cardSurface)
        .vaultCard()
    }

    private var displayDuration: Double {
        audioService.duration > 0 ? audioService.duration : totalDuration
    }

    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        let d = displayDuration
        guard d > 0 else { return 0 }
        let ratio = audioService.currentTime / d
        return CGFloat(ratio) * totalWidth
    }

    private func formatTime(_ secs: TimeInterval) -> String {
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func loadWaveform() {
        guard let url = audioURL else { waveformSamples = []; return }
        Task {
            let samples = await AudioService.loadPlaybackWaveformSamples(from: url, barCount: 60)
            waveformSamples = samples
        }
    }
}

// MARK: - Playback waveform (bar chart with progress)
private struct PlaybackWaveformView: View {
    let levels: [Float]
    let progress: Double

    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let barCount = levels.count
            let barWidth = max(2, (geo.size.width - CGFloat(barCount - 1) * 2) / CGFloat(barCount))
            let spacing: CGFloat = 2
            HStack(spacing: spacing) {
                ForEach(Array(levels.enumerated()), id: \.offset) { index, level in
                    let ratio = Double(index + 1) / Double(barCount)
                    let isPlayed = ratio <= progress
                    let raw = CGFloat(level)
                    let height = minBarHeight + raw * (maxBarHeight - minBarHeight)
                    RoundedRectangle(cornerRadius: barWidth / 2)
                        .fill(isPlayed ? Color.accentGold.opacity(0.9) : Color.borderMuted.opacity(0.6))
                        .frame(width: barWidth, height: max(minBarHeight, height))
                        .frame(height: geo.size.height, alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
