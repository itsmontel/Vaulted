import SwiftUI

// MARK: - Privacy modal (shown after first save + paywall)
// Explains Face ID protection
struct PrivacyModalView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundColor(Color.accentGold)

                VStack(spacing: 10) {
                    Text("Your thoughts are private")
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.theme.inkPrimary)

                    Text("Everything in Vaulted is protected by Face ID. Your notes stay on your device and never leave without your permission.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(themeManager.theme.inkMuted)
                        .multilineTextAlignment(.center)
                }

                Button("Got it") {
                    onDismiss()
                }
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(themeManager.theme.isDark ? themeManager.theme.inkPrimary : .white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Capsule().fill(Color.accentGold))
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(themeManager.theme.cardSurface)
            )
            .padding(.horizontal, 28)
        }
    }
}
