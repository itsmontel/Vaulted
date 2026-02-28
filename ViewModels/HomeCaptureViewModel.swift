import SwiftUI
import Combine

// MARK: - Capture Mode
enum CaptureMode { case voice, text }

// MARK: - HomeCaptureViewModel
@MainActor
final class HomeCaptureViewModel: ObservableObject {

    @Published var mode: CaptureMode = .voice
    @Published var isRecording = false
    @Published var showTextComposer = false
    @Published var showCardPrintAnimation = false
    @Published var selectedDrawerKey: String  // From Settings (Ideas / Work / Journal)
    @Published var animationTargetTab: Int = 0  // Tab index: 0 Ideas, 1 Work, 3 Journal
    @Published var animationTargetIsBin: Bool = false  // true = fly into bin (discard)
    /// Label for the drawer the animation is flying to (for display on card).
    var animationDrawerLabel: String {
        if animationTargetIsBin { return "Discard" }
        switch animationTargetTab {
        case 0: return "Ideas"
        case 1: return "Work"
        case 3: return "Journal"
        default: return "Ideas"
        }
    }
    /// After recording, user picks Ideas / Work / Journal; we save and animate to that tab.
    @Published var showSaveToDrawerSheet = false
    @Published var pendingVoiceFileName: String?
    @Published var pendingVoiceDuration: Double?
    /// Transcript for the pending voice note (populated when Save sheet appears)
    @Published var pendingVoiceTranscript: String?
    @Published var isTranscribingPendingVoice = false
    /// When user taps Save in text composer we show "Save to" sheet; these hold the draft until they pick a drawer.
    @Published var showSaveToDrawerSheetForText = false
    @Published var pendingTextTitle: String?
    @Published var pendingTextBody: String?
    @Published var inboxCount = 0
    @Published var ideasCount = 0
    @Published var workCount = 0
    @Published var journalCount = 0
    @Published var todayCount = 0
    @Published var errorMessage: String?
    @Published var showMicPermissionAlert = false
    
    /// Daily prompt recording state
    @Published var isRecordingDailyPrompt = false
    @Published var dailyPromptCategory: DailyPromptCategory?
    @Published var dailyPromptText: String?

    let audioService: AudioService
    let cardRepo: CardRepository
    let drawerRepo: DrawerRepository
    private var currentRecordingId: UUID?

    init(audioService: AudioService,
         cardRepo: CardRepository = CardRepository(),
         drawerRepo: DrawerRepository = DrawerRepository()) {
        self.audioService = audioService
        self.cardRepo = cardRepo
        self.drawerRepo = drawerRepo
        self.selectedDrawerKey = UserDefaults.standard.string(forKey: "Vaulted.defaultSaveDrawer") ?? "ideas"
        refreshCounts()
        Task { audioService.checkPermission() }
    }

    func refreshCounts() {
        if let inbox = drawerRepo.fetchDrawer(bySystemKey: "inbox") {
            inboxCount = cardRepo.cardCount(drawer: inbox)
        }
        if let ideas = drawerRepo.fetchDrawer(bySystemKey: "ideas") {
            ideasCount = cardRepo.cardCount(drawer: ideas)
        }
        if let work = drawerRepo.fetchDrawer(bySystemKey: "work") {
            workCount = cardRepo.cardCount(drawer: work)
        }
        if let journal = drawerRepo.fetchDrawer(bySystemKey: "journal") {
            journalCount = cardRepo.cardCount(drawer: journal)
        }
        todayCount = cardRepo.todayCardCount()
    }

    // MARK: - Recording
    func beginRecording() {
        guard audioService.permissionGranted != false else {
            showMicPermissionAlert = true
            return
        }
        if audioService.permissionGranted == nil {
            Task {
                await audioService.requestPermission()
                if audioService.permissionGranted == true {
                    startRecord()
                } else {
                    showMicPermissionAlert = true
                }
            }
            return
        }
        startRecord()
    }

    private func startRecord() {
        let id = UUID()
        currentRecordingId = id
        do {
            try audioService.startRecording()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func endRecording() {
        guard isRecording, let id = currentRecordingId else { return }
        do {
            let (fileName, dur) = try audioService.stopRecording(cardId: id)
            isRecording = false
            currentRecordingId = nil
            pendingVoiceFileName = fileName
            pendingVoiceDuration = dur
            
            // If this was a daily prompt recording, show the same preview sheet (transcript, title, star, reminder)
            if isRecordingDailyPrompt, dailyPromptCategory != nil {
                isRecordingDailyPrompt = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    self.showSaveToDrawerSheet = true
                }
                return
            }
            
            // Small settle time before showing the drawer sheet so the audio session
            // can fully deactivate — this also helps the 2nd recording start cleanly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                self.showSaveToDrawerSheet = true
            }
        } catch {
            errorMessage = error.localizedDescription
            isRecording = false
            isRecordingDailyPrompt = false
            dailyPromptCategory = nil
            dailyPromptText = nil
        }
    }
    
    /// Start recording for a daily prompt
    func beginDailyPromptRecording(category: DailyPromptCategory, promptText: String) {
        isRecordingDailyPrompt = true
        dailyPromptCategory = category
        dailyPromptText = promptText
        beginRecording()
    }
    
    /// Call when user picks a drawer from the "Save to" sheet after recording. Saves voice note to that drawer and runs fly-to animation.
    func saveVoiceCardToDrawer(_ drawerKey: String, transcriptOverride: String? = nil, customTitle: String? = nil, reminderDate: Date? = nil, starred: Bool = false) {
        guard let fileName = pendingVoiceFileName, let duration = pendingVoiceDuration,
              let drawer = drawerRepo.fetchDrawer(bySystemKey: drawerKey) else {
            showSaveToDrawerSheet = false
            pendingVoiceFileName = nil
            pendingVoiceDuration = nil
            pendingVoiceTranscript = nil
            return
        }
        let transcript = transcriptOverride ?? pendingVoiceTranscript
        let title: String
        let snippet: String
        if let custom = customTitle, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            title = custom.trimmingCharacters(in: .whitespaces)
            snippet = transcript.map { String($0.prefix(200)) } ?? "Voice note"
        } else if let t = transcript, !t.isEmpty {
            let hint = CardTypeHint.from(systemKey: drawer.systemKey ?? drawerKey)
            title = NLTitleGenerator.generateTitle(
                transcript: t,
                cardTypeHint: hint,
                fallbackDate: Date()
            )
            snippet = String(t.prefix(200))
        } else {
            title = "New card"
            snippet = "Voice note"
        }
        let card = cardRepo.createVoiceCard(drawer: drawer, audioFileName: fileName, duration: duration, title: title, snippet: snippet)
        if let t = transcript, !t.isEmpty {
            cardRepo.update(card: card, typedCopy: t)
        }
        if starred { cardRepo.toggleStar(card) }
        if let rem = reminderDate { cardRepo.setReminder(card, date: rem) }
        pendingVoiceFileName = nil
        pendingVoiceDuration = nil
        pendingVoiceTranscript = nil
        showSaveToDrawerSheet = false
        refreshCounts()
        // Tab indices: 0 Ideas, 1 Work, 3 Journal
        animationTargetIsBin = false
        switch drawerKey {
        case "ideas": animationTargetTab = 0
        case "work": animationTargetTab = 1
        case "journal": animationTargetTab = 3
        default: animationTargetTab = 0
        }
        triggerPrintAnimation()
        NotificationCenter.default.post(name: .vaultedRefreshTabCounts, object: nil)
        if transcript == nil || transcript?.isEmpty == true {
            Task { await transcribeAndUpdateSnippet(fileName: fileName, drawerKey: drawerKey) }
        }
    }

    /// Dismiss "Save to" sheet without saving to a specific drawer; save to default drawer so recording isn't lost.
    func savePendingVoiceToDefaultDrawer() {
        let defaultKey = UserDefaults.standard.string(forKey: "Vaulted.defaultSaveDrawer") ?? "ideas"
        saveVoiceCardToDrawer(defaultKey)
    }

    /// Discard the pending recording (delete file, no card) and play "fly into bin" animation.
    func discardPendingVoice() {
        audioService.stopPlayback()
        guard let fileName = pendingVoiceFileName else {
            showSaveToDrawerSheet = false
            dailyPromptCategory = nil
            dailyPromptText = nil
            return
        }
        let fileURL = AudioDirectoryHelper.audioDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
        pendingVoiceFileName = nil
        pendingVoiceDuration = nil
        pendingVoiceTranscript = nil
        showSaveToDrawerSheet = false
        dailyPromptCategory = nil
        dailyPromptText = nil
        animationTargetIsBin = true
        animationTargetTab = 2  // center (bin is middle bottom)
        triggerPrintAnimation()
    }
    
    /// Save daily prompt recording from the preview sheet (with optional transcript/title/star/reminder).
    func saveDailyPromptFromSheet(transcriptOverride: String? = nil, customTitle: String? = nil, reminderDate: Date? = nil, starred: Bool = false) {
        guard let category = dailyPromptCategory,
              let fileName = pendingVoiceFileName,
              let duration = pendingVoiceDuration,
              let drawer = drawerRepo.fetchDrawer(bySystemKey: category.drawerKey) else {
            showSaveToDrawerSheet = false
            pendingVoiceFileName = nil
            pendingVoiceDuration = nil
            pendingVoiceTranscript = nil
            dailyPromptCategory = nil
            dailyPromptText = nil
            return
        }
        let transcript = transcriptOverride ?? pendingVoiceTranscript
        let title: String
        let snippet: String
        if let custom = customTitle, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            title = custom.trimmingCharacters(in: .whitespaces)
            snippet = transcript.map { String($0.prefix(200)) } ?? "Voice note"
        } else if let t = transcript, !t.isEmpty {
            let hint = CardTypeHint.from(systemKey: category.rawValue)
            title = NLTitleGenerator.generateTitle(transcript: t, cardTypeHint: hint, fallbackDate: Date())
            snippet = String(t.prefix(200))
        } else {
            title = "Daily Prompt"
            snippet = dailyPromptText ?? "Voice note"
        }
        let card = cardRepo.createVoiceCard(
            drawer: drawer,
            audioFileName: fileName,
            duration: duration,
            title: title,
            snippet: snippet,
            tags: "daily-prompt"
        )
        if let t = transcript, !t.isEmpty {
            cardRepo.update(card: card, typedCopy: t)
        }
        if starred { cardRepo.toggleStar(card) }
        if let rem = reminderDate { cardRepo.setReminder(card, date: rem) }
        pendingVoiceFileName = nil
        pendingVoiceDuration = nil
        pendingVoiceTranscript = nil
        showSaveToDrawerSheet = false
        dailyPromptCategory = nil
        dailyPromptText = nil
        refreshCounts()
        animationTargetIsBin = false
        switch category.drawerKey {
        case "ideas": animationTargetTab = 0
        case "work": animationTargetTab = 1
        case "journal": animationTargetTab = 3
        default: animationTargetTab = 0
        }
        triggerPrintAnimation()
        NotificationCenter.default.post(name: .vaultedRefreshTabCounts, object: nil)
        if let cardId = card.uuid {
            DailyPromptService.shared.setLastSavedCard(id: cardId, drawerKey: category.drawerKey)
        }
        DailyPromptService.shared.markPromptAnswered()
        if transcript == nil || transcript?.isEmpty == true {
            Task { await transcribeAndUpdateSnippet(fileName: fileName, drawerKey: category.drawerKey) }
        }
    }

    func cancelRecording() {
        audioService.cancelRecording()
        isRecording = false
        currentRecordingId = nil
    }

    /// Transcribe the pending voice note for display in the Save sheet. Called when the Save sheet appears.
    func transcribePendingVoice() {
        guard let fileName = pendingVoiceFileName else { return }
        Task {
            let audioURL = AudioDirectoryHelper.audioDirectory.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: audioURL.path) else { return }
            await MainActor.run { isTranscribingPendingVoice = true }
            try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s for AVAudioSession to settle
            _ = await SpeechTranscriptionService.shared.requestAuthorization()
            var transcript: String?
            for attempt in 1...3 {
                transcript = await SpeechTranscriptionService.shared.transcribe(audioURL: audioURL)
                if let t = transcript, !t.isEmpty { break }
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
                }
            }
            await MainActor.run {
                guard pendingVoiceFileName != nil else { return } // User discarded while transcribing
                pendingVoiceTranscript = transcript?.isEmpty == false ? transcript : nil
                isTranscribingPendingVoice = false
            }
        }
    }

    /// On-device Apple Speech transcription; updates card with transcript, NLP-generated title, and snippet.
    /// Includes a delay to let the AVAudioSession fully deactivate after recording, plus retry logic
    /// for cases where the recognizer temporarily fails (common on second consecutive recording).
    private func transcribeAndUpdateSnippet(fileName: String, drawerKey: String) async {
        let audioURL = AudioDirectoryHelper.audioDirectory.appendingPathComponent(fileName)
        guard FileManager.default.fileExists(atPath: audioURL.path) else { return }

        // ⚠️ Critical: give the AVAudioSession time to fully deactivate after stopRecording.
        // Without this delay the speech recognizer often silently fails on the 2nd+ recording.
        try? await Task.sleep(nanoseconds: 700_000_000) // 0.7s

        _ = await SpeechTranscriptionService.shared.requestAuthorization()

        // Retry up to 3 times — the recognizer can return nil on first attempt if the audio
        // session hasn't fully settled, even with the delay above.
        var transcript: String?
        for attempt in 1...3 {
            transcript = await SpeechTranscriptionService.shared.transcribe(audioURL: audioURL)
            if let t = transcript, !t.isEmpty { break }
            if attempt < 3 {
                // Progressive backoff: 0.5s, 1.0s between retries
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 500_000_000)
            }
        }

        guard let finalTranscript = transcript, !finalTranscript.isEmpty else { return }
        guard let drawer = drawerRepo.fetchDrawer(bySystemKey: drawerKey) else { return }
        let cards = cardRepo.fetchCards(drawer: drawer)
        guard let card = cards.first(where: { $0.audioFileName == fileName }) else { return }
        let hint = CardTypeHint.from(systemKey: drawer.systemKey ?? drawerKey)
        let title = NLTitleGenerator.generateTitle(
            transcript: finalTranscript,
            cardTypeHint: hint,
            fallbackDate: card.createdAt ?? Date()
        )
        await MainActor.run {
            cardRepo.update(card: card,
                            title: title,
                            snippet: String(finalTranscript.prefix(200)),
                            typedCopy: finalTranscript)
            refreshCounts()
            NotificationCenter.default.post(name: .vaultedRefreshTabCounts, object: nil)
        }
    }

    /// Called when user picks a drawer from the "Save to" sheet for a text note.
    func saveTextCardToDrawer(_ drawerKey: String) {
        guard let title = pendingTextTitle, let body = pendingTextBody,
              let drawer = drawerRepo.fetchDrawer(bySystemKey: drawerKey) else {
            showSaveToDrawerSheetForText = false
            pendingTextTitle = nil
            pendingTextBody = nil
            return
        }
        cardRepo.createTextCard(drawer: drawer, bodyText: body, title: title)
        pendingTextTitle = nil
        pendingTextBody = nil
        showSaveToDrawerSheetForText = false
        refreshCounts()
        animationTargetIsBin = false
        switch drawerKey {
        case "ideas": animationTargetTab = 0
        case "work": animationTargetTab = 1
        case "journal": animationTargetTab = 3
        default: animationTargetTab = 0
        }
        triggerPrintAnimation()
        NotificationCenter.default.post(name: .vaultedRefreshTabCounts, object: nil)
    }

    /// Call from text composer Save: show "Save to" sheet so user picks Ideas / Work / Journal.
    func setPendingTextAndShowSaveSheet(title: String, body: String) {
        pendingTextTitle = title.isEmpty ? "New card" : title
        pendingTextBody = body
        showSaveToDrawerSheetForText = true
    }

    /// Dismiss "Save to" sheet for text without saving (discard draft).
    func cancelPendingText() {
        pendingTextTitle = nil
        pendingTextBody = nil
        showSaveToDrawerSheetForText = false
    }

    func saveTextCard(body: String, title: String = "New card") {
        guard let drawer = drawerRepo.fetchDrawer(bySystemKey: selectedDrawerKey) else { return }
        cardRepo.createTextCard(drawer: drawer, bodyText: body, title: title)
        refreshCounts()
        animationTargetIsBin = false
        switch selectedDrawerKey {
        case "ideas": animationTargetTab = 0
        case "work": animationTargetTab = 1
        case "journal": animationTargetTab = 3
        default: animationTargetTab = 0
        }
        triggerPrintAnimation()
        NotificationCenter.default.post(name: .vaultedRefreshTabCounts, object: nil)
    }

    private func triggerPrintAnimation() {
        // animationTargetTab is set before calling this function
        // For voice cards: always 0 (Inbox)
        // For text cards: based on selectedDrawerKey
        refreshCounts()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            showCardPrintAnimation = true
        }
        // Refresh counts again after a short delay to ensure they're updated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshCounts()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation { self.showCardPrintAnimation = false }
            self.animationTargetIsBin = false
            self.refreshCounts()
        }
    }
}
