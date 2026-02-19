import SwiftUI

// MARK: - Single welcome splash
// "Tap the mic. Speak your mind." → Let's Go → Capture screen
struct WelcomeSplashView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            themeManager.theme.paperBackground.ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Color.accentGold)

                VStack(spacing: 12) {
                    Text("Welcome to Vaulted")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.theme.inkPrimary)

                    Text("Tap the mic. Speak your mind.")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundColor(themeManager.theme.inkMuted)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button {
                    onContinue()
                } label: {
                    HStack(spacing: 10) {
                        Text("Let's Go")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(themeManager.theme.isDark ? themeManager.theme.inkPrimary : .white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(Color.accentGold)
                            .shadow(color: Color.accentGold.opacity(0.45), radius: 14, x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 60)
            }
            .padding(.horizontal, 32)
        }
    }
}
