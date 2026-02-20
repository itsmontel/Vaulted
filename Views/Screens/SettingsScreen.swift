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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.accentGold)
                Text("Settings")
                    .font(.catalogTitle)
                    .foregroundColor(.inkPrimary)
            }
            Text("Customize your Vaulted experience")
                .font(.cardSnippet)
                .foregroundColor(.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 32)
    }

    // MARK: - Theme Section
    private var themeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Appearance")

            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGold.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.accentGold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Colour Theme")
                            .font(.cardTitle)
                            .foregroundColor(.inkPrimary)
                        Text("Choose your preferred theme")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                    }
                }

                // Theme swatches grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 5), spacing: 14) {
                    ForEach(AppThemeStyle.allCases) { style in
                        ThemeSwatch(style: style, isSelected: themeManager.current == style) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                themeManager.current = style
                            }
                        }
                    }
                }
                .padding(.top, 4)

                // Selected theme label
                HStack(spacing: 8) {
                    Image(systemName: themeManager.current.theme.icon)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.accentGold)
                    Text(themeManager.current.theme.name)
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                    Text("·")
                        .foregroundColor(.borderMuted)
                        .font(.cardCaption)
                    Text(themeManager.current.theme.isDark ? "Dark" : "Light")
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSurface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    // MARK: - Security Section
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Security")

            VStack(spacing: 12) {
                settingsRow(icon: "lock.fill", 
                           title: "Require unlock to view content",
                           subtitle: "Face ID or passcode when opening a card or section") {
                    Toggle("", isOn: $lockContentByDefault)
                        .labelsHidden()
                        .tint(.accentGold)
                }

                settingsRow(icon: "lock.rotation", 
                           title: "Lock when app goes to background",
                           subtitle: "Re-authenticate when returning to the app") {
                    Toggle("", isOn: $lockOnBackground)
                        .labelsHidden()
                        .tint(.accentGold)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    // MARK: - Capture Section
    private var captureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Capture")
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGold.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "tray.and.arrow.down.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.accentGold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default save location")
                            .font(.cardTitle)
                            .foregroundColor(.inkPrimary)
                        Text("Where new notes are saved by default")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                    }
                }
                
                Picker("", selection: $defaultSaveDrawer) {
                    Text("Ideas").tag("ideas")
                    Text("Work").tag("work")
                    Text("Journal").tag("journal")
                }
                .pickerStyle(.segmented)
                .tint(.accentGold)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.cardSurface)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.borderMuted.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    // MARK: - About Section
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Help & About")

            VStack(spacing: 12) {
                NavigationLink {
                    LegalPolicyScreen(policyType: .termsOfService)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentGold.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentGold)
                        }
                        Text("Terms of Service")
                            .font(.cardTitle)
                            .foregroundColor(.inkPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkMuted.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cardSurface)
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.borderMuted.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    LegalPolicyScreen(policyType: .privacyPolicy)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentGold.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentGold)
                        }
                        Text("Privacy Policy")
                            .font(.cardTitle)
                            .foregroundColor(.inkPrimary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkMuted.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cardSurface)
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.borderMuted.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Tutorial row
                Button {
                    showTutorial = true
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.accentGold.opacity(0.15))
                                .frame(width: 40, height: 40)
                            Image(systemName: "book.pages.fill")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.accentGold)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("App Tutorial")
                                .font(.cardTitle)
                                .foregroundColor(.inkPrimary)
                            Text("Replay the guided tour")
                                .font(.cardCaption)
                                .foregroundColor(.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.inkMuted.opacity(0.5))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.cardSurface)
                            .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.borderMuted.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // App info
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.accentGold.opacity(0.15))
                            .frame(width: 40, height: 40)
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.accentGold)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vaulted")
                            .font(.cardTitle)
                            .foregroundColor(.inkPrimary)
                        Text("Voice-first notes, organised by Ideas, Work & Journal")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.cardSurface)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.borderMuted.opacity(0.25), lineWidth: 1)
                )
            }
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
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.inkMuted.opacity(0.8))
            .tracking(1.2)
            .padding(.bottom, 10)
            .padding(.leading, 2)
    }

    private func settingsRow<Trailing: View>(icon: String, title: String, subtitle: String,
                                             @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.accentGold.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentGold)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.cardTitle)
                    .foregroundColor(.inkPrimary)
                Text(subtitle)
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
            }
            Spacer()
            trailing()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cardSurface)
                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.borderMuted.opacity(0.3), lineWidth: 1)
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
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? style.theme.accentGold : style.theme.borderMuted.opacity(0.4),
                                        lineWidth: isSelected ? 3 : 1.5)
                        )
                    Circle()
                        .fill(style.theme.accentGold)
                        .frame(width: 22, height: 22)

                    if isSelected {
                        // Checkmark on accent circle
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(style.theme.isDark ? .black : .white)
                    }
                }
                .shadow(color: style.theme.accentGold.opacity(isSelected ? 0.4 : 0),
                        radius: isSelected ? 8 : 0, x: 0, y: isSelected ? 3 : 0)

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


#Preview {
    NavigationStack { SettingsScreen() }
}