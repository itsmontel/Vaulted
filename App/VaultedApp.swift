import SwiftUI

// MARK: - VaultedApp
@main
struct VaultedApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var security = SecurityService.shared
    @StateObject private var audioService = AudioService()
    @StateObject private var themeManager = ThemeManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.viewContext)
                .environmentObject(security)
                .environmentObject(audioService)
                .environmentObject(themeManager)
                .environmentObject(SubscriptionService.shared)
                .environmentObject(OnboardingManager.shared)
                .onboardingOverlay()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        OnboardingManager.shared.startOnboarding()
                    }
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didEnterBackgroundNotification
                )) { _ in
                    let lockOnBg = UserDefaults.standard.object(forKey: "Vaulted.lockOnBackground") as? Bool ?? true
                    if lockOnBg {
                        Task { @MainActor in security.lockPrivateDrawer() }
                    }
                }
        }
    }
}

// Tab order: 0 Ideas, 1 Work, 2 Capture, 3 Journal, 4 Settings
extension Notification.Name {
    static let vaultedRefreshTabCounts = Notification.Name("Vaulted.RefreshTabCounts")
}

// MARK: - Onboarding Overlay (Welcome → Paywall → Privacy)
extension View {
    func onboardingOverlay() -> some View {
        modifier(OnboardingOverlayModifier(onboarding: OnboardingManager.shared))
    }
}

struct OnboardingOverlayModifier: ViewModifier {
    @ObservedObject var onboarding: OnboardingManager

    init(onboarding: OnboardingManager) {
        self._onboarding = ObservedObject(wrappedValue: onboarding)
    }

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $onboarding.showWelcome) {
                WelcomeSplashView(onContinue: { onboarding.dismissWelcome() })
            }
            .fullScreenCover(isPresented: $onboarding.showPaywall) {
                PaywallView(onDismiss: {
                    onboarding.dismissPaywall()
                })
                .interactiveDismissDisabled()
            }
            .overlay {
                if onboarding.showPrivacyModal {
                    PrivacyModalView(onDismiss: { onboarding.dismissPrivacyModal() })
                }
            }
    }
}

// MARK: - ContentView (Tab Navigation)
struct ContentView: View {
    @State private var selectedTab = 2  // Start on Capture (middle)
    @State private var ideasCount = 0
    @State private var workCount = 0
    @State private var journalCount = 0
    @State private var badgeAnimationTab: Int? = nil

    var body: some View {
        ZStack {
            // Content views
            Group {
                if selectedTab == 0 {
                    NavigationStack {
                        LibraryScreen(drawerKey: "ideas", drawerName: "Ideas")
                    }
                } else if selectedTab == 1 {
                    NavigationStack {
                        LibraryScreen(drawerKey: "work", drawerName: "Work")
                    }
                } else if selectedTab == 2 {
                    NavigationStack {
                        HomeCaptureScreen()
                    }
                } else if selectedTab == 3 {
                    NavigationStack {
                        LibraryScreen(drawerKey: "journal", drawerName: "Journal")
                    }
                } else if selectedTab == 4 {
                    NavigationStack {
                        SettingsScreen()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 80)  // Space for custom tab bar

            // Custom tab bar overlay
            VStack {
                Spacer()
                customTabBar
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear {
            UITabBar.appearance().isHidden = true
            refreshTabCounts()
        }
        .onReceive(NotificationCenter.default.publisher(for: .vaultedRefreshTabCounts)) { _ in
            let before = (ideasCount, workCount, journalCount)
            refreshTabCounts()
            if ideasCount > before.0   { badgeAnimationTab = 0 }
            else if workCount > before.1 { badgeAnimationTab = 1 }
            else if journalCount > before.2 { badgeAnimationTab = 3 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { badgeAnimationTab = nil }
        }
    }

    private func refreshTabCounts() {
        let dr = DrawerRepository()
        let cr = CardRepository()
        if let d = dr.fetchDrawer(bySystemKey: "ideas") { ideasCount = cr.cardCount(drawer: d) }
        if let d = dr.fetchDrawer(bySystemKey: "work") { workCount = cr.cardCount(drawer: d) }
        if let d = dr.fetchDrawer(bySystemKey: "journal") { journalCount = cr.cardCount(drawer: d) }
    }

    // MARK: - Custom Tab Bar (order: Ideas, Work, Capture, Journal, Settings)
    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabBarButton(icon: "lightbulb", label: "Ideas", tag: 0, isSelected: selectedTab == 0, count: ideasCount)
            tabBarButton(icon: "briefcase", label: "Work", tag: 1, isSelected: selectedTab == 1, count: workCount)

            Button {
                selectedTab = 2
            } label: {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .fill(selectedTab == 2 ? Color.accentGold : Color.inkMuted.opacity(0.2))
                            .frame(width: 56, height: 56)
                        Image(systemName: "mic.circle.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(selectedTab == 2 ? .white : .inkMuted)
                    }
                    Text("Capture")
                        .font(.system(size: 10, weight: selectedTab == 2 ? .semibold : .regular))
                        .foregroundColor(selectedTab == 2 ? .accentGold : .inkMuted)
                }
            }
            .buttonStyle(.plain)

            tabBarButton(icon: "book", label: "Journal", tag: 3, isSelected: selectedTab == 3, count: journalCount)
            tabBarButton(icon: "gearshape", label: "Settings", tag: 4, isSelected: selectedTab == 4, count: nil)
        }
        .frame(height: 80)
        .background(
            Color.paperBackground
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
        )
        .overlay(
            Rectangle()
                .fill(Color.borderMuted.opacity(0.3))
                .frame(height: 0.5),
            alignment: .top
        )
    }

    private func tabBarButton(icon: String, label: String, tag: Int, isSelected: Bool, count: Int? = nil) -> some View {
        Button {
            selectedTab = tag
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .accentGold : .inkMuted)
                    Text(label)
                        .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(isSelected ? .accentGold : .inkMuted)
                }
                .frame(maxWidth: .infinity)
                .scaleEffect(badgeAnimationTab == tag ? 1.18 : 1.0)
                .animation(.spring(response: 0.25, dampingFraction: 0.5), value: badgeAnimationTab)
                if let count = count, count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.accentGold)
                        .clipShape(Capsule())
                        .scaleEffect(badgeAnimationTab == tag ? 1.35 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.45), value: badgeAnimationTab)
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
}