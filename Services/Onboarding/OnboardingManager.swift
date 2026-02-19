import Foundation

// MARK: - Onboarding Manager
// Flow: Welcome splash → Capture with mic prompt → First save → Paywall → Privacy modal
@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    static let welcomeSeenKey = "Vaulted.onboardingWelcomeSeen"
    static let firstSaveDoneKey = "Vaulted.onboardingFirstSaveDone"
    static let privacyModalSeenKey = "Vaulted.onboardingPrivacyModalSeen"

    @Published var showWelcome = false
    @Published var showPaywall = false
    @Published var showPrivacyModal = false

    var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: Self.welcomeSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.welcomeSeenKey) }
    }

    var hasSavedFirstNote: Bool {
        get { UserDefaults.standard.bool(forKey: Self.firstSaveDoneKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.firstSaveDoneKey) }
    }

    var hasSeenPrivacyModal: Bool {
        get { UserDefaults.standard.bool(forKey: Self.privacyModalSeenKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.privacyModalSeenKey) }
    }

    /// Show mic prompt ("Hold to record your first thought") when user hasn't saved yet
    var shouldShowMicPrompt: Bool {
        hasSeenWelcome && !hasSavedFirstNote
    }

    /// User has completed full onboarding (welcome + first save + paywall/subscribed + privacy)
    var hasCompletedOnboarding: Bool {
        hasSeenWelcome && hasSavedFirstNote && (SubscriptionService.shared.hasAccess || hasSeenPrivacyModal)
    }

    private init() {
        if VaultedTutorialManager.shared.hasCompleted {
            hasSeenWelcome = true
        }
    }

    func startOnboarding() {
        Task { @MainActor in
            await SubscriptionService.shared.updateAccess()
            if hasSavedFirstNote && !SubscriptionService.shared.hasAccess {
                showPaywall = true
                return
            }
            guard !hasSeenWelcome else { return }
            showWelcome = true
        }
    }

    func dismissWelcome() {
        hasSeenWelcome = true
        showWelcome = false
    }

    func onFirstSave() {
        guard !hasSavedFirstNote else { return }
        hasSavedFirstNote = true
        // Delay paywall so the card fly animation (into Ideas/Work/Journal) can complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { [weak self] in
            self?.showPaywall = true
        }
    }

    func dismissPaywall() {
        showPaywall = false
        if SubscriptionService.shared.hasAccess {
            showPrivacyModal = true
        }
    }

    func dismissPrivacyModal() {
        hasSeenPrivacyModal = true
        showPrivacyModal = false
    }
}
