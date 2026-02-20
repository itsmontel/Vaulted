import SwiftUI

// MARK: - BulletizeButton
/// A compact button that triggers transcript → bullet conversion.
/// Shows a spinner while converting and handles success/failure inline.
struct BulletizeButton: View {
    @ObservedObject var themeManager = ThemeManager.shared

    let isEnabled: Bool
    let isConverting: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                if isConverting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: themeManager.theme.accentGold))
                        .scaleEffect(0.75)
                    Text("Converting…")
                        .font(.cardCaption)
                        .foregroundColor(themeManager.theme.inkMuted)
                } else {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(isEnabled ? themeManager.theme.accentGold : themeManager.theme.inkMuted)
                    Text("Bullet points")
                        .font(.cardCaption)
                        .foregroundColor(isEnabled ? themeManager.theme.accentGold : themeManager.theme.inkMuted)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .strokeBorder(
                        isEnabled ? themeManager.theme.accentGold.opacity(0.45) : themeManager.theme.borderMuted,
                        lineWidth: 1
                    )
                    .background(
                        Capsule().fill(themeManager.theme.accentGold.opacity(isEnabled ? 0.07 : 0.0))
                    )
            )
        }
        .disabled(!isEnabled || isConverting)
        .animation(.easeInOut(duration: 0.2), value: isConverting)
    }
}

// MARK: - BulletizerState
/// Encapsulates conversion state for a single transcript editor.
/// Inject into a view via @StateObject or @ObservedObject.
@MainActor
final class BulletizerState: ObservableObject {
    @Published var isConverting = false
    @Published var conversionError: String?
    /// Retains original transcript so user can optionally revert (toggle UX)
    @Published private(set) var originalTranscript: String?

    var hasOriginal: Bool { originalTranscript != nil }

    /// Run bullet conversion off the main thread, call `onSuccess` with the result.
    func convert(text: String, onSuccess: @escaping (String) -> Void) {
        guard !isConverting else { return }
        originalTranscript = text
        isConverting = true
        conversionError = nil

        Task {
            do {
                let bullets = try await TranscriptBulletizer.bulletizeAsync(text)
                await MainActor.run {
                    self.isConverting = false
                    onSuccess(bullets)
                }
            } catch {
                await MainActor.run {
                    self.isConverting = false
                    self.conversionError = "Couldn't convert — transcript kept."
                    self.originalTranscript = nil  // No original to restore if failed
                }
            }
        }
    }

    /// Restore the pre-conversion transcript.
    func revert(onRevert: @escaping (String) -> Void) {
        guard let original = originalTranscript else { return }
        onRevert(original)
        originalTranscript = nil
        conversionError = nil
    }

    func clearError() {
        conversionError = nil
    }
}

// MARK: - Preview
#if DEBUG
struct BulletizeButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            BulletizeButton(isEnabled: true, isConverting: false) {}
            BulletizeButton(isEnabled: true, isConverting: true) {}
            BulletizeButton(isEnabled: false, isConverting: false) {}
        }
        .padding()
        .background(Color.paperBackground)
    }
}
#endif
