import SwiftUI

// MARK: - Settings Keys
enum VaultedSettings {
    static let lockContentByDefaultKey = "Vaulted.lockContentByDefault"
    static let lockOnBackgroundKey     = "Vaulted.lockOnBackground"
    static let defaultSaveDrawerKey    = "Vaulted.defaultSaveDrawer"

    static var lockContentByDefault: Bool {
        get {
            if UserDefaults.standard.object(forKey: lockContentByDefaultKey) == nil { return true }
            return UserDefaults.standard.bool(forKey: lockContentByDefaultKey)
        }
        set { UserDefaults.standard.set(newValue, forKey: lockContentByDefaultKey) }
    }
    static var lockOnBackground: Bool {
        get { UserDefaults.standard.bool(forKey: lockOnBackgroundKey) }
        set { UserDefaults.standard.set(newValue, forKey: lockOnBackgroundKey) }
    }
    static var defaultSaveDrawer: String {
        get { UserDefaults.standard.string(forKey: defaultSaveDrawerKey) ?? "ideas" }
        set { UserDefaults.standard.set(newValue, forKey: defaultSaveDrawerKey) }
    }
}

// MARK: - SettingsScreen
struct SettingsScreen: View {
    @AppStorage("Vaulted.lockContentByDefault") private var lockContentByDefault = true
    @AppStorage("Vaulted.lockOnBackground")     private var lockOnBackground = true
    @AppStorage("Vaulted.defaultSaveDrawer")    private var defaultSaveDrawer = "ideas"

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showTutorial = false

    var body: some View {
        ZStack {
            Color.paperBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    header
                    themeSection
                    securitySection
                    captureSection
                    aboutSection
                }
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
    }

    // MARK: - Header
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Settings")
                .font(.catalogTitle)
                .foregroundColor(.inkPrimary)
            Text("App preferences and security")
                .font(.cardCaption)
                .foregroundColor(.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Theme Section
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Appearance")

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentGold)
                        .frame(width: 28)
                    Text("Colour Theme")
                        .font(.cardTitle)
                        .foregroundColor(.inkPrimary)
                }

                // Theme swatches grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
                    ForEach(AppThemeStyle.allCases) { style in
                        ThemeSwatch(style: style, isSelected: themeManager.current == style) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                themeManager.current = style
                            }
                        }
                    }
                }

                // Selected theme label
                HStack(spacing: 6) {
                    Image(systemName: themeManager.current.theme.icon)
                        .font(.cardCaption)
                        .foregroundColor(.accentGold)
                    Text(themeManager.current.theme.name)
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                    Text("·")
                        .foregroundColor(.borderMuted)
                    Text(themeManager.current.theme.isDark ? "Dark" : "Light")
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                }
            }
            .padding(16)
            .background(Color.cardSurface.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Security")
            settingsRow(icon: "lock.fill", title: "Require unlock to view content") {
                Toggle("", isOn: $lockContentByDefault)
                    .labelsHidden()
                    .tint(.accentGold)
            }
            .subtitle("Face ID or passcode when opening a card or section")

            settingsRow(icon: "lock.rotation", title: "Lock when app goes to background") {
                Toggle("", isOn: $lockOnBackground)
                    .labelsHidden()
                    .tint(.accentGold)
            }
            .subtitle("Re-authenticate when returning to the app")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    // MARK: - Capture Section
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Capture")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18))
                        .foregroundColor(.accentGold)
                        .frame(width: 28)
                    Text("Default save location")
                        .font(.cardTitle)
                        .foregroundColor(.inkPrimary)
                }
                Picker("", selection: $defaultSaveDrawer) {
                    Text("Ideas").tag("ideas")
                    Text("Work").tag("work")
                    Text("Journal").tag("journal")
                }
                .pickerStyle(.segmented)
                .tint(.accentGold)
                Text("Fallback drawer when dismissing the save sheet without choosing.")
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
            }
            .padding(16)
            .background(Color.cardSurface.opacity(0.7))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 28)
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionTitle("Help & About")

            NavigationLink {
                LegalPolicyScreen(policyType: .termsOfService)
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentGold)
                        .frame(width: 28)
                    Text("Terms of Service")
                        .font(.cardTitle)
                        .foregroundColor(.inkPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.inkMuted.opacity(0.4))
                }
                .padding(16)
                .background(Color.cardSurface.opacity(0.7))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                LegalPolicyScreen(policyType: .privacyPolicy)
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentGold)
                        .frame(width: 28)
                    Text("Privacy Policy")
                        .font(.cardTitle)
                        .foregroundColor(.inkPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.inkMuted.opacity(0.4))
                }
                .padding(16)
                .background(Color.cardSurface.opacity(0.7))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Tutorial row
            Button {
                showTutorial = true
            } label: {
                HStack(alignment: .center) {
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.accentGold)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("App Tutorial")
                            .font(.cardTitle)
                            .foregroundColor(.inkPrimary)
                        Text("Replay the guided tour of Vaulted")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.inkMuted.opacity(0.4))
                }
                .padding(16)
                .background(Color.cardSurface.opacity(0.7))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            settingsRow(icon: "info.circle",
                        title: "Vaulted",
                        subtitle: "Voice-first notes, organised by Ideas, Work & Journal.")
        }
        .padding(.horizontal, 20)
        .fullScreenCover(isPresented: $showTutorial) {
            VaultedTutorialOverlay(manager: VaultedTutorialManager.shared)
                .onAppear { VaultedTutorialManager.shared.start(isOnboarding: false) }
                .ignoresSafeArea()
        }
    }

    // MARK: - Helpers
    private func sectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundColor(.inkMuted)
            .tracking(0.8)
            .padding(.bottom, 8)
    }

    private func settingsRow<Trailing: View>(icon: String, title: String,
                                             @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentGold)
                .frame(width: 28)
            Text(title)
                .font(.cardTitle)
                .foregroundColor(.inkPrimary)
            Spacer()
            trailing()
        }
        .padding(16)
        .background(Color.cardSurface.opacity(0.7))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
        )
    }

    private func settingsRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.accentGold)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.cardTitle)
                    .foregroundColor(.inkPrimary)
                Text(subtitle)
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
            }
            Spacer()
        }
        .padding(16)
        .background(Color.cardSurface.opacity(0.7))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderMuted.opacity(0.4), lineWidth: 1)
        )
    }
}

// MARK: - Theme Swatch
private struct ThemeSwatch: View {
    let style: AppThemeStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Double-circle swatch: paper bg outer, accent inner
                ZStack {
                    Circle()
                        .fill(style.theme.paperBackground)
                        .frame(width: 44, height: 44)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? style.theme.accentGold : style.theme.borderMuted,
                                        lineWidth: isSelected ? 2.5 : 1)
                        )
                    Circle()
                        .fill(style.theme.accentGold)
                        .frame(width: 20, height: 20)

                    if isSelected {
                        // Checkmark on accent circle
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(style.theme.isDark ? .black : .white)
                    }
                }
                .shadow(color: style.theme.accentGold.opacity(isSelected ? 0.35 : 0),
                        radius: 6, x: 0, y: 2)

                Text(style.theme.name)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular, design: .rounded))
                    .foregroundColor(isSelected ? .accentGold : .inkMuted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.06 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isSelected)
    }
}

// MARK: - Subtitle helper
private extension View {
    func subtitle(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            self
            Text(text)
                .font(.cardCaption)
                .foregroundColor(.inkMuted)
                .padding(.leading, 36)
        }
    }
}

#Preview {
    NavigationStack { SettingsScreen() }
}