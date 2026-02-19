import SwiftUI
import CoreData

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: TutorialMockSeeder
// Creates real CardEntity objects in a throw-away child context so the live
// Ideas / Work / Journal screens look full during the tutorial.
// The context is never saved — no CoreData side effects whatsoever.
// MARK: ─────────────────────────────────────────────────────────────────────
final class TutorialMockSeeder {
    static let shared = TutorialMockSeeder()

    let ideasCards:   [CardEntity]
    let workCards:    [CardEntity]
    let journalCards: [CardEntity]

    private init() {
        let ctx = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        ctx.persistentStoreCoordinator =
            PersistenceController.shared.viewContext.persistentStoreCoordinator

        let mockDrawer = DrawerEntity(context: ctx)
        mockDrawer.systemKey = "ideas"

        let cal = Calendar.current
        let now = Date()
        func ago(_ n: Int) -> Date { cal.date(byAdding: .day, value: -n, to: now) ?? now }

        func text(_ title: String, _ body: String, starred: Bool = false, days: Int) -> CardEntity {
            let c = CardEntity(context: ctx)
            c.title     = title
            c.bodyText  = body
            c.snippet   = String(body.prefix(160))
            c.starred   = starred
            c.createdAt = ago(days)
            c.drawer    = mockDrawer
            return c
        }

        func voice(_ title: String, _ transcript: String, dur: Double, days: Int) -> CardEntity {
            let c = CardEntity(context: ctx)
            c.title         = title
            c.typedCopy     = transcript
            c.snippet       = String(transcript.prefix(160))
            c.audioFileName = "tutorial_mock_\(UUID().uuidString).m4a"
            c.durationSec   = dur
            c.createdAt     = ago(days)
            c.drawer        = mockDrawer
            return c
        }

        ideasCards = [
            text("Design system colour tokens",
                 "Map every semantic colour to a token before the design review next week.",
                 starred: true, days: 0),
            voice("Automate my invoices",
                  "Script that reads Notion, generates a PDF and emails the client automatically.",
                  dur: 102, days: 0),
            text("App name brainstorm",
                 "Vaulted, Archive, Capsule, Pocket, Vault, Memo — need to shortlist to three.",
                 days: 1),
            voice("Side project pitch angle",
                  "Lead with the privacy angle — it resonates much more than speed does.",
                  dur: 58, days: 1),
            text("Reading list for Q1",
                 "SICP, Shape Up, The Manager's Path, Four Thousand Weeks.",
                 days: 8),
            voice("Podcast episode concept",
                  "Solo episode on building in public — what I'd do differently this time.",
                  dur: 134, days: 21),
        ]

        workCards = [
            text("Q1 goals — action items",
                 "Ship v1.2 by Feb 1, present at all-hands, hire one engineer.",
                 starred: true, days: 0),
            voice("Client feedback on onboarding",
                  "Step 3 confuses users — too many options shown at once. Simplify.",
                  dur: 78, days: 1),
            text("Sprint 22 planning notes",
                 "Focus areas: auth polish, empty states, and notification settings.",
                 days: 2),
            voice("Standup blockers",
                  "Waiting on legal to sign off before we can launch in the EU market.",
                  dur: 44, days: 2),
            text("Interview debrief — Maya",
                 "Strong on system design; would need mentoring on communication and soft skills.",
                 days: 9),
            voice("API rate limit discussion",
                  "Move to per-user quotas — agreed with the infra team on Slack this afternoon.",
                  dur: 65, days: 22),
        ]

        journalCards = [
            text("Clarity after the morning walk",
                 "Left the phone at home. First time in months I actually felt present.",
                 days: 0),
            voice("Finished the book last night",
                  "The ending completely recontextualised the first act. Didn't see it coming.",
                  dur: 151, days: 1),
            text("Three things I'm grateful for",
                 "Good coffee, a quiet office, and a lunch that wasn't at my desk.",
                 days: 2),
            voice("What I'd tell my younger self",
                  "Stop optimising for being impressive — just try to be genuinely useful.",
                  dur: 112, days: 3),
            text("2024 reflection",
                 "Shipped more than expected. Rested considerably less than I needed.",
                 starred: true, days: 14),
            text("Conversation with mum",
                 "She asked if I was happy. I realised I had to think about it for a moment.",
                 days: 28),
        ]
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: VaultedTutorialStep
// MARK: ─────────────────────────────────────────────────────────────────────
enum VaultedTutorialStep: Int, CaseIterable {
    case welcome        = 0
    case capture        = 1
    case saveToDrawer   = 2
    case textNotes      = 3
    case ideas          = 4
    case work           = 5
    case journal        = 6
    case stackView      = 7
    case lockSecurity   = 8
    case search         = 9
    case themes         = 10
    case complete       = 11

    // MARK: - Tab this step navigates to (0 Ideas, 1 Work, 2 Capture, 3 Journal, 4 Settings)
    var targetTab: Int {
        switch self {
        case .welcome, .capture, .saveToDrawer, .textNotes, .search: return 2  // Capture tab for steps 1–3, 9
        case .ideas, .stackView:      return 0  // Ideas with Bookshelf for Stack
        case .work:                   return 1
        case .journal:                return 3
        case .lockSecurity, .themes, .complete: return 4
        }
    }

    // MARK: - Full-screen splash (welcome / complete)
    var isSplash: Bool { self == .welcome || self == .complete }

    // MARK: - Content
    var title: String {
        switch self {
        case .welcome:      return "Welcome to Vaulted"
        case .capture:      return "Voice First"
        case .saveToDrawer: return "Organise Your Thoughts"
        case .textNotes:    return "Type It Out"
        case .ideas:        return "Ideas"
        case .work:         return "Work"
        case .journal:      return "Journal"
        case .stackView:    return "The Stack View"
        case .lockSecurity: return "Private & Secure"
        case .search:       return "Find Anything"
        case .themes:       return "Make It Yours"
        case .complete:     return "You're All Set!"
        }
    }

    var description: String {
        switch self {
        case .welcome:
            return "Vaulted is your voice-first note vault. Capture ideas, work thoughts and journal entries — all in one beautifully private place."
        case .capture:
            return "Tap the big mic circle to record a voice note. Speak naturally — Vaulted transcribes on-device and generates a title for you automatically."
        case .saveToDrawer:
            return "After recording, a sheet slides up asking where to save it — Ideas, Work, or Journal. Choose one and your note lands instantly."
        case .textNotes:
            return "Prefer typing? Switch the picker at the bottom from Voice to Type. The same drawers apply — just a keyboard instead of a mic."
        case .ideas:
            return "All your idea captures live here. Tap any stack to fan out the individual notes inside. Swipe left on a card to star or delete."
        case .work:
            return "A focused space for meeting notes, action items and decisions — completely separate from your personal thoughts."
        case .journal:
            return "Your private diary. Journal entries sit in their own drawer so they never mix with work or creative ideas."
        case .stackView:
            return "Switch between Stack, Shelf and Drawers views using the buttons at the top. Each shows your notes in a different way."
        case .lockSecurity:
            return "Every note is protected by Face ID by default. Toggle this or the background lock in Settings › Security anytime."
        case .search:
            return "Tap the magnifying glass in the Capture screen header to search every note, transcript and tag — across all your drawers at once."
        case .themes:
            return "Tap Colour Theme here to switch between Parchment, Midnight, Forest, Rose and Slate. The whole app updates instantly."
        case .complete:
            return "You're ready. Tap the mic, speak your mind, and let Vaulted do the rest. Your thoughts deserve a beautiful home."
        }
    }

    var icon: String {
        switch self {
        case .welcome:      return "lock.fill"
        case .capture:      return "mic.fill"
        case .saveToDrawer: return "tray.and.arrow.down.fill"
        case .textNotes:    return "square.and.pencil"
        case .ideas:        return "lightbulb.fill"
        case .work:         return "briefcase.fill"
        case .journal:      return "book.fill"
        case .stackView:    return "square.stack.fill"
        case .lockSecurity: return "faceid"
        case .search:       return "magnifyingglass"
        case .themes:       return "paintpalette.fill"
        case .complete:     return "checkmark.seal.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .welcome:      return Color(hex: "#C49245")
        case .capture:      return Color(hex: "#C49245")
        case .saveToDrawer: return Color(hex: "#B8893C")
        case .textNotes:    return Color(hex: "#8B6272")
        case .ideas:        return Color(hex: "#C49245")
        case .work:         return Color(hex: "#5B8DB8")
        case .journal:      return Color(hex: "#7A9E6E")
        case .stackView:    return Color(hex: "#A89070")
        case .lockSecurity: return Color(hex: "#C49245")
        case .search:       return Color(hex: "#70A0C0")
        case .themes:       return Color(hex: "#A78BFA")
        case .complete:     return Color(hex: "#57CC78")
        }
    }

    // Arrow direction: .up = card has top arrow pointing at content above,
    //                 .down = card has bottom arrow pointing at tab bar below
    //                 .none = no arrow (splash screens)
    var arrowDirection: TutorialArrowDir {
        switch self {
        case .welcome, .complete:       return .none
        case .capture, .saveToDrawer,
             .textNotes, .stackView,
             .lockSecurity, .search,
             .themes:                   return .up
        case .ideas, .work, .journal:   return .down   // pointing to tab bar
        }
    }

    // Steps that form the progress pill row (excludes splash)
    static var progressable: [VaultedTutorialStep] {
        allCases.filter { !$0.isSplash }
    }

    /// Horizontal offset for UP arrow so it points at the right element (e.g. search icon, theme selector).
    func upArrowOffsetX(containerWidth: CGFloat) -> CGFloat {
        switch self {
        case .search:  return containerWidth * 0.36   // Search magnifying glass is top-right
        case .themes:  return -containerWidth * 0.22  // Colour Theme section is left side of Settings
        default:       return 0
        }
    }

    /// Extra bottom padding to move card UP (positive = card higher). For search, card moves up so arrow points at header.
    func overlayCardBottomPadding(geo: GeometryProxy) -> CGFloat {
        switch self {
        case .search:  return geo.safeAreaInsets.bottom + 240  // Card higher so arrow reaches search icon
        default:       return geo.safeAreaInsets.bottom + 96   // Above tab bar
        }
    }

    /// Horizontal offset for DOWN arrow so it points at the correct tab (Ideas / Work / Journal).
    func downArrowOffsetX(containerWidth: CGFloat) -> CGFloat {
        // Tab centers: 0.1, 0.3, 0.5, 0.7, 0.9 of width. Arrow at 0.5 → offset = (tabCenter - 0.5) * width
        switch self {
        case .ideas:   return (0.10 - 0.5) * containerWidth  // point at Ideas tab
        case .work:    return (0.30 - 0.5) * containerWidth  // point at Work tab
        case .journal: return (0.70 - 0.5) * containerWidth   // point at Journal tab
        default:       return 0
        }
    }
}

enum TutorialArrowDir { case up, down, none }

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: VaultedTutorialManager
// MARK: ─────────────────────────────────────────────────────────────────────
final class VaultedTutorialManager: ObservableObject {
    static let shared = VaultedTutorialManager()
    static let completedKey = "Vaulted.tutorialCompleted"

    @Published var isActive      = false
    @Published var step: VaultedTutorialStep = .welcome
    @Published var showCard      = false
    @Published var slideFromRight = true          // transition direction
    // ContentView observes this to switch tabs
    @Published var requestedTab: Int = 2
    /// When true, present the real Save to sheet (step 2) as if user just recorded.
    @Published var showSaveToDrawerForTutorial = false
    /// True for first-time onboarding (no Skip); false when replaying from Settings (can Skip).
    @Published var isOnboarding = true

    var hasCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: Self.completedKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.completedKey) }
    }

    private init() {}

    func startIfNeeded() {
        guard !hasCompleted else { return }
        isOnboarding = true
        start()
    }

    func start(isOnboarding: Bool = true) {
        self.isOnboarding = isOnboarding
        step         = .welcome
        showCard     = false
        requestedTab = 2
        isActive     = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.44, dampingFraction: 0.78)) {
                self.showCard = true
            }
        }
    }

    func next() {
        guard let idx = VaultedTutorialStep.allCases.firstIndex(of: step) else { return }
        let nextIdx = idx + 1
        guard nextIdx < VaultedTutorialStep.allCases.count else { complete(); return }
        slideFromRight = true
        advance(to: VaultedTutorialStep.allCases[nextIdx])
    }

    func previous() {
        guard let idx = VaultedTutorialStep.allCases.firstIndex(of: step), idx > 0 else { return }
        slideFromRight = false
        advance(to: VaultedTutorialStep.allCases[idx - 1])
    }

    private func advance(to newStep: VaultedTutorialStep) {
        showSaveToDrawerForTutorial = (newStep == .saveToDrawer)
        step = newStep
        requestedTab = newStep.targetTab
        withAnimation(.easeOut(duration: 0.17)) { showCard = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.76)) {
                self.showCard = true
            }
        }
    }

    func skip() {
        withAnimation(.easeOut(duration: 0.22)) { showCard = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.22)) { self.isActive = false }
        }
    }

    func complete() {
        hasCompleted = true
        requestedTab = 2  // Return user to Capture when tutorial ends
        withAnimation(.easeOut(duration: 0.28)) { showCard = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation { self.isActive = false }
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: VaultedTutorialOverlay  — sits on top of the live app
// MARK: ─────────────────────────────────────────────────────────────────────
struct VaultedTutorialOverlay: View {
    @ObservedObject var manager: VaultedTutorialManager
    @ObservedObject var themeManager = ThemeManager.shared

    // Sparkle state for welcome screen
    @State private var sparkleOpacity:  [Double]  = Array(repeating: 0,   count: 8)
    @State private var sparkleScale:    [CGFloat] = Array(repeating: 0.3, count: 8)
    @State private var sparkleDistance: [CGFloat] = Array(repeating: 0,   count: 8)
    @State private var glowPulse = false
    @State private var iconBounce: CGFloat = 0
    @State private var cardShake: CGFloat = 0

    private let cardCornerRadius: CGFloat = 22

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {

                // ── Backdrop for splash screens only ─────────────────────
                if manager.step.isSplash && manager.showCard {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                }

                // ── Sparkles for welcome ─────────────────────────────────
                if manager.step == .welcome && manager.showCard {
                    sparkleLayer(in: geo)
                }

                // ── Main card ────────────────────────────────────────────
                if manager.showCard {
                    Group {
                        if manager.step.isSplash {
                            splashCard(in: geo)
                        } else {
                            overlayCard(in: geo)
                        }
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: manager.slideFromRight ? .trailing : .leading)
                                .combined(with: .opacity),
                            removal: .move(edge: manager.slideFromRight ? .leading : .trailing)
                                .combined(with: .opacity)
                        )
                    )
                }

                // ── Progress bar (non-splash steps, top of screen) ───────
                if !manager.step.isSplash && manager.showCard {
                    VStack {
                        progressBar
                            .padding(.top, geo.safeAreaInsets.top + 28)
                        Spacer()
                    }
                    .ignoresSafeArea(edges: .top)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                // ── Mock Passcode (Private & Secure step) ──────────────────
                if manager.step == .lockSecurity && manager.showCard {
                    MockPasscodeOverlay()
                }
            }
        }
        .ignoresSafeArea()
        .onAppear { glowPulse = true }
        .onChange(of: manager.step) { newStep in
            if newStep == .welcome { triggerSparkles() }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { iconBounce = -10 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.55)) { iconBounce = 0 }
            }
        }
        .onAppear {
            if manager.step == .welcome { triggerSparkles() }
        }
    }

    // MARK: - Progress bar (top strip, like reference screenshots)
    private var progressBar: some View {
        HStack(spacing: 0) {
            // Skip button (only when replaying from Settings, not onboarding)
            if !manager.isOnboarding {
                Button {
                    manager.skip()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("Skip")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(themeManager.theme.inkMuted)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 2)
                }
                .buttonStyle(.plain)
                .frame(width: 66, alignment: .leading)
            }

            Spacer()

            // Progress pills
            HStack(spacing: 4) {
                ForEach(VaultedTutorialStep.progressable, id: \.rawValue) { s in
                    let isActive = s == manager.step
                    let isPast   = s.rawValue < manager.step.rawValue
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            isActive ? manager.step.accentColor :
                            isPast   ? manager.step.accentColor.opacity(0.45) :
                                       Color(hex: "#D0C8BC").opacity(0.5)
                        )
                        .frame(width: isActive ? 18 : 7, height: 7)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: manager.step)
                }
            }

            Spacer()

            // Step counter
            let progressIdx = (VaultedTutorialStep.progressable.firstIndex(of: manager.step) ?? 0) + 1
            let total = VaultedTutorialStep.progressable.count
            Text("\(progressIdx)/\(total)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(manager.step.accentColor)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.theme.cardSurface)
                .shadow(color: .black.opacity(0.10), radius: 12, x: 0, y: 4)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Floating tooltip card (steps shown on top of live app)
    @ViewBuilder
    private func overlayCard(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(alignment: .leading, spacing: 0) {

                // ── Arrow pointing UP (content above) ────────────────────
                if manager.step.arrowDirection == .up {
                    HStack {
                        Spacer()
                        ArrowTriangle(direction: .up)
                            .fill(themeManager.theme.cardSurface)
                            .frame(width: 20, height: 11)
                            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: -2)
                        Spacer()
                    }
                    .offset(x: manager.step.upArrowOffsetX(containerWidth: geo.size.width))
                }

                // ── Card body ────────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {

                    // Header row
                    HStack(spacing: 14) {
                        // Icon circle
                        ZStack {
                            Circle()
                                .fill(manager.step.accentColor.opacity(0.14))
                                .frame(width: 46, height: 46)
                            Image(systemName: manager.step.icon)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(manager.step.accentColor)
                                .offset(y: iconBounce)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(manager.step.title)
                                .font(.system(size: 17, weight: .bold, design: .serif))
                                .foregroundColor(themeManager.theme.inkPrimary)

                            let idx = (VaultedTutorialStep.progressable.firstIndex(of: manager.step) ?? 0) + 1
                            Text("Step \(idx) of \(VaultedTutorialStep.progressable.count)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(manager.step.accentColor)
                        }

                        Spacer()

                        // Back chevron
                        if manager.step.rawValue > 1 {
                            Button { manager.previous() } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(themeManager.theme.inkMuted.opacity(0.55))
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(themeManager.theme.borderMuted.opacity(0.25))
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Description
                    Text(manager.step.description)
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundColor(themeManager.theme.inkMuted)
                        .lineSpacing(4.5)
                        .fixedSize(horizontal: false, vertical: true)

                    // Tap to continue
                    HStack {
                        Spacer()
                        HStack(spacing: 5) {
                            Text("Tap to continue")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 11))
                        }
                        .foregroundColor(manager.step.accentColor)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .fill(themeManager.theme.cardSurface)
                        .shadow(color: .black.opacity(0.14), radius: 22, x: 0, y: -6)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cardCornerRadius)
                        .stroke(manager.step.accentColor.opacity(0.15), lineWidth: 1.2)
                )

                // ── Arrow pointing DOWN (toward tab bar below) ────────────
                if manager.step.arrowDirection == .down {
                    HStack {
                        Spacer()
                        ArrowTriangle(direction: .down)
                            .fill(themeManager.theme.cardSurface)
                            .frame(width: 20, height: 11)
                            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
                        Spacer()
                    }
                    .offset(x: manager.step.downArrowOffsetX(containerWidth: geo.size.width))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, manager.step.overlayCardBottomPadding(geo: geo))
        }
        .contentShape(Rectangle())
        .onTapGesture { manager.next() }
    }

    // MARK: - Splash card (Welcome / Complete)
    @ViewBuilder
    private func splashCard(in geo: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 26) {

                // Icon hero with glow rings
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(manager.step.accentColor.opacity(0.10 - Double(i) * 0.025), lineWidth: 1)
                            .frame(width: CGFloat(132 + i * 26), height: CGFloat(132 + i * 26))
                    }
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    manager.step.accentColor.opacity(0.22),
                                    manager.step.accentColor.opacity(0.05)
                                ],
                                center: .center, startRadius: 20, endRadius: 65
                            )
                        )
                        .frame(width: 110, height: 110)
                        .scaleEffect(glowPulse ? 1.07 : 0.95)
                        .animation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true), value: glowPulse)

                    Circle()
                        .stroke(manager.step.accentColor.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 110, height: 110)

                    Image(systemName: manager.step.icon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(manager.step.accentColor)
                        .offset(y: iconBounce)
                }

                // Title + subtitle pill
                VStack(spacing: 12) {
                    Text(manager.step.title)
                        .font(.system(size: 27, weight: .bold, design: .serif))
                        .foregroundColor(themeManager.theme.inkPrimary)
                        .multilineTextAlignment(.center)

                    if manager.step == .welcome {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.fill").font(.system(size: 9))
                            Text("Voice-first · Private · Beautiful")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(manager.step.accentColor)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(manager.step.accentColor.opacity(0.1)))
                        .overlay(Capsule().stroke(manager.step.accentColor.opacity(0.25), lineWidth: 1))
                    }
                }

                // Description
                Text(manager.step.description)
                    .font(.system(size: 15, weight: .medium, design: .serif))
                    .foregroundColor(themeManager.theme.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .padding(.horizontal, 12)

                // CTA button
                Button {
                    if manager.step == .complete { manager.complete() }
                    else { manager.next() }
                } label: {
                    HStack(spacing: 10) {
                        Text(manager.step == .complete ? "Start Exploring" : "Let's Go")
                            .font(.system(size: 17, weight: .bold, design: .serif))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundColor(themeManager.theme.isDark ? themeManager.theme.inkPrimary : .white)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(manager.step.accentColor)
                            .shadow(color: manager.step.accentColor.opacity(0.45), radius: 14, x: 0, y: 6)
                    )
                }
                .buttonStyle(.plain)

                // Skip Tour (welcome only, and only when replaying from Settings — hidden during onboarding)
                if manager.step == .welcome && !manager.isOnboarding {
                    Button { manager.skip() } label: {
                        Text("Skip Tour")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(themeManager.theme.inkMuted.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(30)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(themeManager.theme.cardSurface)
                    .shadow(color: .black.opacity(0.18), radius: 30, x: 0, y: 14)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(manager.step.accentColor.opacity(0.12), lineWidth: 1.5)
            )
            .padding(.horizontal, 24)
            .padding(.bottom, geo.safeAreaInsets.bottom + 50)
        }
    }

    // MARK: - Sparkle layer (welcome)
    private func sparkleLayer(in geo: GeometryProxy) -> some View {
        let cx = geo.size.width  / 2
        let cy = geo.size.height * 0.35
        return ZStack {
            ForEach(0..<8, id: \.self) { i in
                let angle = Double(i) * 45.0 * .pi / 180.0
                let dx = cos(angle) * Double(sparkleDistance[i])
                let dy = sin(angle) * Double(sparkleDistance[i])
                Image(systemName: i % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: i % 3 == 0 ? 15 : 10, weight: .bold))
                    .foregroundColor(manager.step.accentColor)
                    .scaleEffect(sparkleScale[i])
                    .opacity(sparkleOpacity[i])
                    .position(x: cx + CGFloat(dx), y: cy + CGFloat(dy))
            }
        }
        .allowsHitTesting(false)
    }

    private func triggerSparkles() {
        for i in 0..<8 {
            sparkleOpacity[i]  = 0
            sparkleScale[i]    = 0.3
            sparkleDistance[i] = 0
            let delay = Double(i) * 0.065
            withAnimation(.easeOut(duration: 0.55).delay(delay)) {
                sparkleOpacity[i]  = 1.0
                sparkleScale[i]    = 1.0
                sparkleDistance[i] = CGFloat.random(in: 60...100)
            }
            withAnimation(.easeIn(duration: 0.38).delay(delay + 0.5)) {
                sparkleOpacity[i] = 0
            }
        }
    }
}

// MARK: - Mock Passcode overlay (visual only, for tutorial — mimics iOS passcode screen)
struct MockPasscodeOverlay: View {
    private let keyLabels: [(digit: String, letters: String?)] = [
        ("1", nil),
        ("2", "ABC"),
        ("3", "DEF"),
        ("4", "GHI"),
        ("5", "JKL"),
        ("6", "MNO"),
        ("7", "PQRS"),
        ("8", "TUV"),
        ("9", "WXYZ"),
        ("0", nil)
    ]

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer().frame(height: 80)

                // Instructional text
                VStack(spacing: 4) {
                    Text("Enter iPhone Passcode for")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                    Text("\"Vaulted\"")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black)
                    Text("Unlock your Private drawer")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                }
                .multilineTextAlignment(.center)

                // Passcode circles (6 digits)
                HStack(spacing: 14) {
                    ForEach(0..<6, id: \.self) { _ in
                        Circle()
                            .stroke(Color.black.opacity(0.3), lineWidth: 2)
                            .frame(width: 12, height: 12)
                    }
                }
                .padding(.top, 32)

                Spacer()

                // Numeric keypad
                VStack(spacing: 18) {
                    ForEach([0, 1, 2], id: \.self) { row in
                        HStack(spacing: 32) {
                            ForEach(1...3, id: \.self) { col in
                                let idx = row * 3 + col - 1
                                keypadKey(digit: keyLabels[idx].digit, letters: keyLabels[idx].letters)
                            }
                        }
                    }
                    keypadKey(digit: "0", letters: nil)
                }
                .padding(.bottom, 50)

                // Cancel
                HStack {
                    Spacer()
                    Text("Cancel")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.black)
                        .padding(.trailing, 28)
                        .padding(.bottom, 40)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func keypadKey(digit: String, letters: String?) -> some View {
        VStack(spacing: 2) {
            Text(digit)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.black)
            if let letters = letters {
                Text(letters)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundColor(Color(hex: "#8E8E93"))
            }
        }
        .frame(width: 76, height: 76)
        .background(
            Circle()
                .fill(Color(hex: "#E5E5EA"))
        )
    }
}

// MARK: - Arrow triangle shape
struct ArrowTriangle: Shape {
    let direction: TutorialArrowDir
    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch direction {
        case .up:
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .down:
            p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        default:
            break
        }
        p.closeSubpath()
        return p
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: ViewModifier — wrap ContentView
// MARK: ─────────────────────────────────────────────────────────────────────
struct VaultedTutorialViewModifier: ViewModifier {
    @ObservedObject fileprivate var manager = VaultedTutorialManager.shared

    func body(content: Content) -> some View {
        ZStack {
            content
            if manager.isActive {
                VaultedTutorialOverlay(manager: manager)
                    .zIndex(999)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: manager.isActive)
    }
}

extension View {
    func vaultedTutorial() -> some View {
        modifier(VaultedTutorialViewModifier())
    }
}