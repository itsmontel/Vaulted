import SwiftUI
import Combine

// MARK: - CardDetailViewModel
@MainActor
final class CardDetailViewModel: ObservableObject {

    @Published var card: CardEntity
    @Published var editingTitle: String
    @Published var editingBody: String
    @Published var editingTypedCopy: String
    @Published var tagsInput: String
    @Published var showDrawerPicker = false
    @Published var showTagEditor = false
    @Published var isLocked = false
    @Published var isUnlocked = false   // for private card auth

    let cardRepo: CardRepository
    let drawerRepo: DrawerRepository
    let audioService: AudioService
    let securityService: SecurityService

    var drawers: [DrawerEntity] { drawerRepo.fetchAllDrawers() }

    init(card: CardEntity,
         cardRepo: CardRepository = CardRepository(),
         drawerRepo: DrawerRepository = DrawerRepository(),
         audioService: AudioService,
         securityService: SecurityService) {
        self.card = card
        self.editingTitle = card.title ?? "New card"
        self.editingBody  = card.bodyText ?? ""
        self.editingTypedCopy = card.typedCopy ?? ""
        self.tagsInput    = card.tags ?? ""
        self.isLocked     = card.isLocked
        self.cardRepo = cardRepo
        self.drawerRepo = drawerRepo
        self.audioService = audioService
        self.securityService = securityService
        self.isUnlocked   = securityService.privateDrawerIsUnlocked
    }

    var requiresAuth: Bool {
        card.drawer?.isPrivate == true && !securityService.privateDrawerIsUnlocked
    }

    func saveTitle() {
        cardRepo.update(card: card, title: editingTitle)
    }

    /// Regenerate title using on-device NLP from typedCopy/transcript. Returns new title if successful.
    func regenerateTitle() -> String? {
        let transcript = card.typedCopy ?? card.bodyText ?? card.snippet ?? ""
        guard !transcript.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        let hint = CardTypeHint.from(systemKey: card.drawer?.systemKey)
        let newTitle = NLTitleGenerator.generateTitle(
            transcript: transcript,
            cardTypeHint: hint,
            fallbackDate: card.createdAt ?? Date()
        )
        cardRepo.update(card: card, title: newTitle)
        editingTitle = newTitle
        objectWillChange.send()
        return newTitle
    }

    func saveBody() {
        cardRepo.update(card: card, bodyText: editingBody)
    }

    func saveTypedCopy() {
        cardRepo.update(card: card, typedCopy: editingTypedCopy)
    }

    func saveTags() {
        cardRepo.update(card: card, tags: tagsInput)
    }

    func toggleStar() {
        cardRepo.toggleStar(card)
        objectWillChange.send()
    }

    func moveTo(drawer: DrawerEntity) {
        cardRepo.moveCard(card, toDrawer: drawer)
        isLocked = card.isLocked
        objectWillChange.send()
    }

    func moveToPrivate() async {
        guard let privateDrawer = drawerRepo.fetchDrawer(bySystemKey: "private") else { return }
        let success = await securityService.authenticateAndUnlock()
        if success {
            cardRepo.moveCard(card, toDrawer: privateDrawer)
            cardRepo.setLocked(card, locked: true)
            isLocked = true
            objectWillChange.send()
        }
    }

    func unlockCard() async {
        let success = await securityService.authenticateAndUnlock()
        isUnlocked = success
    }

    // MARK: - Playback helpers
    func playAudio() {
        guard let url = card.audioURL else { return }
        try? audioService.play(url: url)
    }

    func togglePlayback() {
        if audioService.isPlaying {
            audioService.pause()
        } else if audioService.currentTime > 0 {
            audioService.resume()
        } else {
            playAudio()
        }
    }
}
