import SwiftUI
import CoreData

// MARK: - LibraryScreen
struct LibraryScreen: View {
    let drawerKey: String
    let drawerName: String
    @EnvironmentObject private var security: SecurityService
    @EnvironmentObject private var audioService: AudioService
    @Environment(\.managedObjectContext) private var moc

    var body: some View {
        LibraryScreenContent(
            drawerKey: drawerKey,
            drawerName: drawerName,
            securityService: security,
            audioService: audioService,
            moc: moc
        )
    }
}

// Inner view so we can create @StateObject with injected security (from environment).
private struct LibraryScreenContent: View {
    let drawerKey: String
    let drawerName: String
    let securityService: SecurityService
    let audioService: AudioService
    let moc: NSManagedObjectContext

    @StateObject private var vm: LibraryViewModel
    @ObservedObject private var tutorialManager = VaultedTutorialManager.shared
    @State private var selectedCard: CardEntity?
    @State private var showCapture = false
    @State private var searchText = ""

    init(drawerKey: String, drawerName: String, securityService: SecurityService, audioService: AudioService, moc: NSManagedObjectContext) {
        self.drawerKey = drawerKey
        self.drawerName = drawerName
        self.securityService = securityService
        self.audioService = audioService
        self.moc = moc
        _vm = StateObject(wrappedValue: LibraryViewModel(filterDrawerKey: drawerKey, securityService: securityService))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.paperBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                libraryHeader

                // View mode switcher
                viewModeSwitcher

                Divider()

                // Content (card selection goes through auth when "Require unlock to view content" is on)
                contentArea
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // FAB for quick capture
            captureButton
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showCapture, onDismiss: { vm.load() }) {
            HomeCaptureScreen()
                .environment(\.managedObjectContext, moc)
                .environmentObject(audioService)
        }
        .sheet(item: $selectedCard) { card in
            CardDetailScreen(card: card,
                             audioService: audioService,
                             securityService: securityService,
                             onDismiss: { vm.load() })
        }
        .onAppear {
            vm.load()
            // If tutorial is already active on appear, apply the correct view mode immediately
            applyTutorialViewMode(tutorialManager.step)
        }
        .onChange(of: tutorialManager.step) { step in
            applyTutorialViewMode(step)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.load()
        }
    }

    /// Sets the real view mode on the VM so the user sees Stack / Shelf / Drawers
    /// with populated mock data during the relevant tutorial step.
    private func applyTutorialViewMode(_ step: VaultedTutorialStep) {
        guard tutorialManager.isActive else { return }
        switch step {
        case .ideas where drawerKey == "ideas",
             .work  where drawerKey == "work",
             .journal where drawerKey == "journal":
            // Show the Stack (timeline) view so users see their notes in a list
            withAnimation(.easeInOut(duration: 0.25)) { vm.viewMode = .stack }
        case .stackView where drawerKey == "ideas":
            // Cycle through all three views with short delays so the user can see each one
            withAnimation(.easeInOut(duration: 0.25)) { vm.viewMode = .stack }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                guard tutorialManager.isActive && tutorialManager.step == .stackView else { return }
                withAnimation(.easeInOut(duration: 0.35)) { vm.viewMode = .shelf }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                guard tutorialManager.isActive && tutorialManager.step == .stackView else { return }
                withAnimation(.easeInOut(duration: 0.35)) { vm.viewMode = .drawer }
            }
        default:
            break
        }
    }

    // MARK: - Header
    private var libraryHeader: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(drawerName)
                        .font(.catalogTitle)
                        .foregroundColor(.inkPrimary)
                    let lockContent = (UserDefaults.standard.object(forKey: "Vaulted.lockContentByDefault") as? Bool) ?? true
                    HStack(spacing: 4) {
                        if drawerKey == "private" {
                            Text("🔒 Locked by default")
                        } else if lockContent {
                            Image(systemName: "faceid")
                                .font(.cardCaption)
                            Text("Tap to unlock content")
                        } else {
                            Text("Vaulted")
                        }
                    }
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
                }
                Spacer()
                if drawerKey == "private" {
                    Button {
                        Task {
                            if vm.isPrivateUnlocked {
                                securityService.lockPrivateDrawer()
                                vm.isPrivateUnlocked = false
                                vm.reloadCards()
                            } else {
                                _ = await vm.unlockPrivate()
                            }
                        }
                    } label: {
                        Image(systemName: vm.isPrivateUnlocked ? "lock.open.fill" : "lock.fill")
                            .foregroundColor(.accentGold)
                            .font(.title3)
                    }
                }
            }
            
            // Search bar
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.inkMuted)
                    .font(.system(size: 16))
                TextField("Search notes...", text: $searchText)
                    .font(.cardSnippet)
                    .foregroundColor(.inkPrimary)
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { q in
                        vm.searchQuery = q
                        vm.reloadCards()
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        vm.searchQuery = ""
                        vm.reloadCards()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.inkMuted)
                            .font(.system(size: 16))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.borderMuted, lineWidth: 1)
            )
            .cornerRadius(8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - View mode switcher
    private var viewModeSwitcher: some View {
        HStack(spacing: 0) {
            ForEach(LibraryViewMode.allCases, id: \.self) { mode in
                Button {
                    let lockContent = (UserDefaults.standard.object(forKey: "Vaulted.lockContentByDefault") as? Bool) ?? true
                    if lockContent && vm.viewMode != mode {
                        Task {
                            let ok = await securityService.authenticateAndUnlock()
                            if ok {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    vm.viewMode = mode
                                    UserDefaults.standard.set(mode.rawValue, forKey: "Vaulted.lastLibraryViewMode")
                                }
                            }
                        }
                    } else {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            vm.viewMode = mode
                            UserDefaults.standard.set(mode.rawValue, forKey: "Vaulted.lastLibraryViewMode")
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.systemImage)
                            .font(.system(size: 12))
                        Text(mode.rawValue)
                            .font(.cardCaption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(vm.viewMode == mode ? Color.accentGold.opacity(0.15) : Color.clear)
                    .foregroundColor(vm.viewMode == mode ? .accentGold : .inkMuted)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    /// When "Require unlock to view content" is on, opening a card requires Face ID / passcode first.
    private var authWrappedSelectedCard: Binding<CardEntity?> {
        Binding(
            get: { selectedCard },
            set: { newValue in
                guard let card = newValue else { selectedCard = nil; return }
                let lockContentByDefault = (UserDefaults.standard.object(forKey: "Vaulted.lockContentByDefault") as? Bool) ?? true
                if !lockContentByDefault {
                    selectedCard = card
                    return
                }
                Task { @MainActor in
                    let ok = await securityService.authenticateAndUnlock()
                    if ok { selectedCard = card }
                }
            }
        )
    }

    // MARK: - Content area
    @ViewBuilder
    private var contentArea: some View {
        let lockContentByDefault = (UserDefaults.standard.object(forKey: "Vaulted.lockContentByDefault") as? Bool) ?? true
        switch vm.viewMode {
        case .stack:
            TimelineStackView(vm: vm, selectedCard: authWrappedSelectedCard, showLockIndicator: lockContentByDefault || drawerKey == "private")
        case .drawer:
            DrawerCabinetView(vm: vm, selectedCard: authWrappedSelectedCard, showLockIndicator: lockContentByDefault || drawerKey == "private")
        case .shelf:
            BookshelfMonthView(vm: vm, selectedCard: authWrappedSelectedCard, showLockIndicator: lockContentByDefault || drawerKey == "private")
        }
    }

    // MARK: - Floating action button
    private var captureButton: some View {
        Button { showCapture = true } label: {
            ZStack {
                Circle()
                    .fill(Color.accentGold)
                    .frame(width: 56, height: 56)
                    .shadow(color: .inkPrimary.opacity(0.2), radius: 6, x: 0, y: 3)
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 30)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        LibraryScreen(drawerKey: "inbox", drawerName: "Inbox")
    }
    .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
    .environmentObject(SecurityService.shared)
    .environmentObject(AudioService())
}