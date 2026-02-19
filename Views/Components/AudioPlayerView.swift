import SwiftUI

// MARK: - AudioPlayerView
struct AudioPlayerView: View {
    @ObservedObject var audioService: AudioService
    let audioURL: URL?
    let totalDuration: Double

    var body: some View {
        VStack(spacing: 10) {
            // Seekable progress bar — drag or tap to skip to any position
            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.borderMuted)
                        .frame(height: 6)

                    // Progress
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.accentGold)
                        .frame(width: progressWidth(in: width), height: 6)
                }
                .frame(height: 6)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { val in
                            let ratio = min(1, max(0, val.location.x / width))
                            let time = ratio * displayDuration
                            audioService.seek(to: time)
                        }
                )
            }
            .frame(height: 6)

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
}
