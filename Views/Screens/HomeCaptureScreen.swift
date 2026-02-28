import SwiftUI

// MARK: - HomeCaptureScreen
struct HomeCaptureScreen: View {
    @EnvironmentObject private var audioService: AudioService

    var body: some View {
        HomeCaptureScreenContent(audioService: audioService)
    }
}

// Create ViewModel on MainActor in onAppear to avoid "main actor-isolated initializer in nonisolated context".
private struct HomeCaptureScreenContent: View {
    let audioService: AudioService
    @StateObject private var vm: HomeCaptureViewModel
    @State private var showTextComposer = false
    @State private var recordButtonScale: CGFloat = 1.0
    @State private var outerPulse: CGFloat = 1.0

    init(audioService: AudioService) {
        self.audioService = audioService
        _vm = StateObject(wrappedValue: HomeCaptureViewModel(audioService: audioService))
    }

    var body: some View {
        HomeCaptureScreenBody(
            vm: vm,
            audioService: audioService,
            showTextComposer: $showTextComposer,
            recordButtonScale: $recordButtonScale,
            outerPulse: $outerPulse
        )
    }
}

private struct HomeCaptureScreenBody: View {
    @ObservedObject var vm: HomeCaptureViewModel
    @ObservedObject var audioService: AudioService
    @ObservedObject private var onboarding = OnboardingManager.shared
    @ObservedObject private var tutorialManager = VaultedTutorialManager.shared
    @ObservedObject private var dailyPromptService = DailyPromptService.shared
    @Binding var showTextComposer: Bool
    @Binding var recordButtonScale: CGFloat
    @Binding var outerPulse: CGFloat
    @State private var showSearch = false
    @State private var micPulseScale: CGFloat = 1.0
    @State private var showStreakCelebration = false

    var body: some View {
        ZStack {
            Color.paperBackground.ignoresSafeArea()
            GrainOverlay()

            VStack(spacing: 0) {
                headerView
                Spacer()
                if vm.isRecording {
                    recordingView
                } else {
                    mainButtonArea
                    Spacer()
                    voiceTypePicker
                }
                Spacer().frame(height: 16)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .onAppear {
                if tutorialManager.step == .textNotes { vm.mode = .text }
                else if tutorialManager.step == .capture || tutorialManager.step == .saveToDrawer { vm.mode = .voice }
            }
            .onChange(of: tutorialManager.step) { step in
                if step == .textNotes { vm.mode = .text }
                else if step == .capture || step == .saveToDrawer { vm.mode = .voice }
            }

            // Card fly animation overlay
            if vm.showCardPrintAnimation {
                CardSlideAnimationView(
                    targetTab: vm.animationTargetTab,
                    targetIsBin: vm.animationTargetIsBin,
                    drawerLabel: vm.animationDrawerLabel
                )
                .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            }
            
            // Streak celebration overlay
            if showStreakCelebration {
                streakCelebrationOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .onChange(of: dailyPromptService.answeredToday) { answered in
            if answered && dailyPromptService.currentStreak > 0 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showStreakCelebration = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation { showStreakCelebration = false }
                }
            }
        }
        .sheet(isPresented: $showTextComposer, onDismiss: {
            vm.refreshCounts()
        }) {
            TextComposerSheet { title, body in
                vm.setPendingTextAndShowSaveSheet(title: title, body: body)
                showTextComposer = false
            }
        }
        .sheet(isPresented: Binding(
            get: { vm.showSaveToDrawerSheet || vm.showSaveToDrawerSheetForText || tutorialManager.showSaveToDrawerForTutorial },
            set: { if !$0 {
                vm.showSaveToDrawerSheet = false
                vm.showSaveToDrawerSheetForText = false
                tutorialManager.showSaveToDrawerForTutorial = false
            } }
        ), onDismiss: {
            if vm.pendingVoiceFileName != nil { vm.discardPendingVoice() }
            if vm.pendingTextTitle != nil { vm.cancelPendingText() }
            tutorialManager.showSaveToDrawerForTutorial = false
        }) {
            SaveToDrawerSheet(vm: vm, tutorialManager: tutorialManager)
        }
        .alert("Microphone Access Required",
               isPresented: $vm.showMicPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Vaulted needs microphone access to record voice notes. Please enable it in Settings.")
        }
        .sheet(isPresented: $showSearch) {
            GlobalSearchScreen()
                .environment(\.managedObjectContext, PersistenceController.shared.viewContext)
        }
        .onAppear { vm.refreshCounts() }
    }

    // MARK: - Header
    // Title "Vaulted" with subtitle "Private Voice Journal"; lock inline; search to the right
    private var headerView: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 7) {
                    Text("Vaulted")
                        .font(.catalogTitle)
                        .foregroundColor(.inkPrimary)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.accentGold)
                        .offset(y: 1)
                }
                Text("Private Voice Journal")
                    .font(.system(.subheadline, design: .serif))
                    .foregroundColor(.inkMuted)
            }

            Spacer()

            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.accentGold)
                    .font(.title3)
                    .padding(8)
                    .background(Color.accentGold.opacity(0.08))
                    .clipShape(Circle())
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Drawer selector — Ideas / Work / Journal (no count badges)
    private var drawerSelector: some View {
        VStack(spacing: 8) {
            Text("Save to")
                .font(.cardCaption)
                .foregroundColor(.inkMuted)
            HStack(spacing: 10) {
                drawerButton(key: "ideas",   icon: "lightbulb", label: "Ideas")
                drawerButton(key: "work",    icon: "briefcase", label: "Work")
                drawerButton(key: "journal", icon: "book",      label: "Journal")
            }
        }
        .padding(.vertical, 12)
    }

    private func drawerButton(key: String, icon: String, label: String) -> some View {
        let isSelected = vm.selectedDrawerKey == key
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { vm.selectedDrawerKey = key }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentGold : .inkMuted)
                Text(label)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .accentGold : .inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentGold.opacity(0.12) : Color.cardSurface.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.accentGold.opacity(0.55) : Color.borderMuted.opacity(0.4),
                            lineWidth: isSelected ? 1.5 : 1)
            )
            .cornerRadius(10)
            .scaleEffect(isSelected ? 1.03 : 1.0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Recording view (waveform + timer + controls when isRecording)
    private var recordingView: some View {
        VStack(spacing: 28) {
            // Waveform
            RecordingWaveformView(levels: audioService.recordingLevels, currentLevel: audioService.recordingLevel)
                .frame(height: 120)
                .padding(.horizontal, 8)

            // Elapsed time
            Text(formatRecordingTime(audioService.recordingElapsed))
                .font(.system(size: 42, weight: .light, design: .monospaced))
                .foregroundColor(.inkPrimary)
                .contentTransition(.numericText())

            // Cancel | Stop
            HStack(spacing: 40) {
                Button {
                    vm.cancelRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.inkMuted.opacity(0.2))
                            .frame(width: 56, height: 56)
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.inkPrimary)
                    }
                }
                .buttonStyle(.plain)

                Button {
                    vm.endRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 72, height: 72)
                            .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                        Image(systemName: "stop.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(Color.clear)
                    .frame(width: 56, height: 56)
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 20)
    }

    private func formatRecordingTime(_ secs: TimeInterval) -> String {
        let m = Int(secs) / 60
        let s = Int(secs) % 60
        return String(format: "%02d:%02d", m, s)
    }

    // MARK: - Main button area
    private var mainButtonArea: some View {
        VStack(spacing: 16) {
            // Daily Prompt Card (only in voice mode, not during onboarding)
            if vm.mode == .voice && !onboarding.shouldShowMicPrompt && !tutorialManager.isActive {
                dailyPromptCard
            }
            
            if vm.mode == .voice {
                voiceRecordButton
                if onboarding.shouldShowMicPrompt {
                    Text("Tap the mic to record your first thought.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.inkMuted)
                        .multilineTextAlignment(.center)
                }
            } else {
                typeButton
            }
        }
        .onAppear {
            if onboarding.shouldShowMicPrompt {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    micPulseScale = 1.05
                }
            }
            dailyPromptService.refreshTodaysPrompt()
        }
        .onChange(of: onboarding.shouldShowMicPrompt) { show in
            if !show { micPulseScale = 1.0 }
        }
    }
    
    // MARK: - Daily Prompt Card
    private var dailyPromptCard: some View {
        let prompt = dailyPromptService.todaysPrompt
        let answered = dailyPromptService.answeredToday
        let streak = dailyPromptService.currentStreak
        
        return VStack(spacing: 0) {
            // Header: Category + Streak
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: prompt.category.icon)
                        .font(.system(size: 12, weight: .semibold))
                    Text("Daily \(prompt.category.displayName)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(.accentGold)
                
                Spacer()
                
                if streak > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                        Text("\(streak)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(streak >= 7 ? .orange : .inkMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)
            
            // Prompt Text
            Text(prompt.text)
                .font(.system(size: 15, weight: .medium, design: .serif))
                .foregroundColor(.inkPrimary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            
            // Action row: View Answer (when answered) or Tap to answer (when not)
            HStack(spacing: 12) {
                if answered {
                    Button {
                        viewDailyPromptAnswer()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 14))
                            Text("View Answer")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.accentGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.accentGold.opacity(0.15))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    if !answered {
                        startDailyPromptRecording()
                    }
                } label: {
                    HStack(spacing: 8) {
                        if answered {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                            Text("Answered today")
                                .font(.system(size: 13, weight: .medium))
                        } else {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14))
                            Text("Tap to answer")
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundColor(answered ? .inkMuted : .white)
                    .frame(maxWidth: answered ? .infinity : nil)
                    .padding(.horizontal, answered ? 0 : 20)
                    .padding(.vertical, 10)
                    .background(answered ? Color.borderMuted.opacity(0.3) : Color.accentGold)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(answered)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color.cardSurface)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(answered ? Color.borderMuted.opacity(0.5) : Color.accentGold.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: .inkPrimary.opacity(0.06), radius: 8, x: 0, y: 3)
        .padding(.horizontal, 8)
        .opacity(answered ? 0.85 : 1)
    }
    
    private func startDailyPromptRecording() {
        let prompt = dailyPromptService.todaysPrompt
        vm.beginDailyPromptRecording(category: prompt.category, promptText: prompt.text)
    }
    
    private func viewDailyPromptAnswer() {
        guard let cardId = dailyPromptService.lastSavedCardId,
              let drawerKey = dailyPromptService.lastSavedDrawerKey else { return }
        NotificationCenter.default.post(
            name: .vaultedOpenCard,
            object: nil,
            userInfo: ["drawerKey": drawerKey, "cardId": cardId]
        )
    }
    
    // MARK: - Streak Celebration Overlay
    private var streakCelebrationOverlay: some View {
        let streak = dailyPromptService.currentStreak
        let message: String
        let icon: String
        
        if streak == 1 {
            message = "First day! Keep it going"
            icon = "sparkles"
        } else if streak == 7 {
            message = "1 week streak!"
            icon = "flame.fill"
        } else if streak == 30 {
            message = "30 day streak!"
            icon = "trophy.fill"
        } else if streak % 7 == 0 {
            message = "\(streak / 7) week streak!"
            icon = "flame.fill"
        } else {
            message = "\(streak) day streak!"
            icon = "flame.fill"
        }
        
        return VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36))
                .foregroundColor(.accentGold)
            Text(message)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.inkPrimary)
            Text("Daily prompt answered")
                .font(.system(size: 14))
                .foregroundColor(.inkMuted)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.cardSurface)
                .shadow(color: .inkPrimary.opacity(0.15), radius: 20, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.accentGold.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Tap to Record button
    private var voiceRecordButton: some View {
        let showPulse = onboarding.shouldShowMicPrompt && !vm.isRecording
        return ZStack {
            Circle()
                .stroke(Color.accentGold.opacity(vm.isRecording ? 0.5 : (showPulse ? 0.5 : 0.2)), lineWidth: 3)
                .frame(width: 340, height: 340)
                .scaleEffect(vm.isRecording ? 1.06 : (showPulse ? micPulseScale : 1.0))
                .animation(.easeInOut(duration: 0.3), value: vm.isRecording)

            Circle()
                .fill(vm.isRecording ? Color.accentGold.opacity(0.9) : Color.cardSurface)
                .overlay(Circle().stroke(Color.accentGold, lineWidth: 3))
                .shadow(color: .inkPrimary.opacity(0.15), radius: 14, x: 0, y: 7)
                .frame(width: 310, height: 310)
                .scaleEffect(recordButtonScale)

            VStack(spacing: 14) {
                Image(systemName: vm.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 64))
                    .foregroundColor(vm.isRecording ? .white : .inkPrimary)
                Text(vm.isRecording ? "Tap to stop" : "Tap to\nRecord")
                    .font(.system(.title2, design: .serif).weight(.medium))
                    .multilineTextAlignment(.center)
                    .foregroundColor(vm.isRecording ? .white : .inkMuted)
            }
        }
        .contentShape(Circle())
        .onTapGesture {
            if vm.isRecording {
                vm.endRecording()
            } else {
                withAnimation(.spring(response: 0.2)) { recordButtonScale = 0.96 }
                vm.beginRecording()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.spring(response: 0.3)) { recordButtonScale = 1.0 }
                }
            }
        }
    }

    // MARK: - Type button (large)
    private var typeButton: some View {
        Button {
            showTextComposer = true
        } label: {
            VStack(spacing: 18) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 72))
                    .foregroundColor(.inkMuted)
                Text("Tap to type\na note")
                    .font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.inkMuted)
            }
            .frame(width: 310, height: 310)
            .background(Color.cardSurface)
            .overlay(Circle().stroke(Color.borderMuted, lineWidth: 2))
            .clipShape(Circle())
            .shadow(color: .inkPrimary.opacity(0.08), radius: 12, x: 0, y: 5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voice/Type picker
    private var voiceTypePicker: some View {
        Picker("Mode", selection: $vm.mode) {
            Text("Voice").tag(CaptureMode.voice)
            Text("Type").tag(CaptureMode.text)
        }
        .pickerStyle(.segmented)
        .frame(width: 220)
        .tint(.accentGold)
        .padding(.vertical, 12)
    }
}

// MARK: - Recording waveform (live levels during record)
struct RecordingWaveformView: View {
    let levels: [Float]
    let currentLevel: Float

    private let barCount = 60
    private let minBarHeight: CGFloat = 4
    private let maxBarHeight: CGFloat = 48

    /// Quiet levels stay similar; loud levels get much higher bars (up to ~2x).
    private static func emphasizePeaks(_ raw: CGFloat) -> CGFloat {
        if raw <= 0.25 { return raw }
        let t = (raw - 0.25) / 0.75
        return 0.25 + t * 1.75
    }

    /// Last barCount levels (newest on the right); padded with 0 on the left when recording just started.
    private var displayLevels: [Float] {
        let suffix = Array(levels.suffix(barCount))
        let pad = barCount - suffix.count
        return (pad > 0 ? (0..<pad).map { _ in Float(0) } : []) + suffix
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let barWidth = max(2, (w - CGFloat(barCount - 1) * 3) / CGFloat(barCount))
            let spacing: CGFloat = 3

            ZStack {
                // Soft background
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.accentGold.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.accentGold.opacity(0.12), lineWidth: 1)
                    )

                // Main waveform bars (gold) — quiet stays similar, loud gets much higher peaks
                HStack(spacing: spacing) {
                    ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                        let raw = CGFloat(level)
                        let emphasized = Self.emphasizePeaks(raw)
                        let height = minBarHeight + emphasized * (maxBarHeight - minBarHeight)
                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentGold.opacity(0.9),
                                        Color.accentGold.opacity(0.5)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: barWidth, height: max(minBarHeight, height))
                            .frame(height: h, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Lighter secondary wave for depth
                HStack(spacing: spacing) {
                    ForEach(Array(displayLevels.enumerated()), id: \.offset) { _, level in
                        let raw = CGFloat(level)
                        let emphasized = Self.emphasizePeaks(raw)
                        let height = (minBarHeight + emphasized * (maxBarHeight - minBarHeight)) * 0.75
                        RoundedRectangle(cornerRadius: barWidth / 2)
                            .fill(Color.accentGold.opacity(0.22))
                            .frame(width: max(1, barWidth * 0.6), height: max(2, height))
                            .frame(height: h, alignment: .center)
                            .offset(x: 1, y: 1)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .blur(radius: 0.8)
            }
        }
    }
}

// MARK: - Save to Drawer Sheet (after voice recording or text note)
struct SaveToDrawerSheet: View {
    @ObservedObject var vm: HomeCaptureViewModel
    @ObservedObject var tutorialManager: VaultedTutorialManager
    @ObservedObject private var onboarding = OnboardingManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var editableTranscript: String = ""
    @FocusState private var isTranscriptFocused: Bool
    @State private var showDiscardConfirmation = false
    @State private var customTitle: String = ""
    @State private var previewStarred: Bool = false
    @State private var previewReminderDate: Date? = nil
    @State private var showReminderPicker: Bool = false

    private var isTutorialMode: Bool { tutorialManager.showSaveToDrawerForTutorial }
    private var isVoiceMode: Bool { vm.pendingVoiceFileName != nil }
    private var isTextMode: Bool { vm.pendingTextTitle != nil }
    private var isDailyPromptMode: Bool { vm.dailyPromptCategory != nil }

    private var voicePreviewURL: URL? {
        guard let fileName = vm.pendingVoiceFileName else { return nil }
        return AudioDirectoryHelper.audioDirectory.appendingPathComponent(fileName)
    }

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    // Cancel button (avoids toolbar ambiguity)
                    HStack {
                        Button("Cancel") {
                            if isTutorialMode {
                                tutorialManager.showSaveToDrawerForTutorial = false
                                tutorialManager.next()
                                dismiss()
                            } else {
                                showDiscardConfirmation = true
                            }
                        }
                        .foregroundColor(.inkMuted)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .alert(isVoiceMode ? "Discard recording?" : "Discard note?", isPresented: $showDiscardConfirmation) {
                        Button("Keep", role: .cancel) {}
                        Button("Discard", role: .destructive) {
                            if isVoiceMode {
                                vm.discardPendingVoice()
                            } else {
                                vm.cancelPendingText()
                            }
                            dismiss()
                        }
                    } message: {
                        Text(isVoiceMode
                            ? "Are you sure you want to discard this voice recording? It cannot be recovered."
                            : "Are you sure you want to discard this note? It cannot be recovered.")
                    }

                    // Voice preview: play and seek before choosing (skip in tutorial)
                    if !isTutorialMode, isVoiceMode, let url = voicePreviewURL {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Preview")
                                .font(.cardCaption)
                                .foregroundColor(.inkMuted)
                            AudioPlayerView(
                                audioService: vm.audioService,
                                audioURL: url,
                                totalDuration: vm.pendingVoiceDuration ?? 0
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Title, Star, Reminder — before save (voice mode only)
                    if !isTutorialMode, isVoiceMode {
                        HStack(spacing: 12) {
                            TextField("Title (optional)", text: $customTitle)
                                .font(.cardBody)
                                .foregroundColor(.inkPrimary)
                            Button {
                                previewStarred.toggle()
                            } label: {
                                Image(systemName: previewStarred ? "star.fill" : "star")
                                    .foregroundColor(previewStarred ? .accentGold : .inkMuted)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                            Button {
                                showReminderPicker = true
                            } label: {
                                Image(systemName: previewReminderDate != nil ? "bell.fill" : "bell")
                                    .foregroundColor(previewReminderDate != nil ? .accentGold : .inkMuted)
                                    .font(.system(size: 20))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showReminderPicker) {
                            ReminderPickerSheet(
                                currentReminder: previewReminderDate,
                                onSave: { previewReminderDate = $0; showReminderPicker = false },
                                onClear: { previewReminderDate = nil; showReminderPicker = false },
                                onCancel: { showReminderPicker = false }
                            )
                        }
                    }

                    if isDailyPromptMode, let category = vm.dailyPromptCategory {
                        Text("Saving to")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                        HStack(spacing: 8) {
                            Image(systemName: category.icon)
                                .font(.system(size: 18))
                                .foregroundColor(.accentGold)
                            Text(category.displayName)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.inkPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.cardSurface.opacity(0.8))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.accentGold.opacity(0.35), lineWidth: 1)
                        )
                        .padding(.horizontal)
                        Button {
                            vm.saveDailyPromptFromSheet(
                                transcriptOverride: editableTranscript.isEmpty ? nil : editableTranscript,
                                customTitle: customTitle.isEmpty ? nil : customTitle,
                                reminderDate: previewReminderDate,
                                starred: previewStarred
                            )
                            dismiss()
                        } label: {
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.accentGold)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    } else {
                        Text("Save to")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                        HStack(spacing: 12) {
                            drawerOption(key: "ideas", icon: "lightbulb", label: "Ideas")
                            drawerOption(key: "work", icon: "briefcase", label: "Work")
                            drawerOption(key: "journal", icon: "book", label: "Journal")
                        }
                        .padding(.horizontal)
                    }

                    // Transcribed notes (voice mode only) — set expectations, tap to edit
                    if !isTutorialMode, isVoiceMode {
                        transcribedNotesSection
                    }

                    Spacer(minLength: 24)
                }
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(Color.paperBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.accentGold)
                }
            }
        }
        .interactiveDismissDisabled(!isTutorialMode)
        .onAppear {
            if !isTutorialMode, isVoiceMode {
                vm.audioService.stopPlayback()
                vm.transcribePendingVoice()
                editableTranscript = vm.pendingVoiceTranscript ?? ""
            }
        }
    }

    private var transcribedNotesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Transcribed notes")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.inkMuted)
                .textCase(.uppercase)
                .tracking(1.2)

            // Short expectation line
            Text("May not be perfect — tap to edit before saving.")
                .font(.system(size: 12))
                .foregroundColor(.inkMuted)

            if vm.isTranscribingPendingVoice {
                HStack(spacing: 10) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.accentGold))
                        .scaleEffect(0.85)
                    Text("Transcribing…")
                        .font(Font.cardBody)
                        .foregroundColor(.inkMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
            } else if vm.pendingVoiceTranscript != nil {
                TextEditor(text: $editableTranscript)
                    .font(Font.cardBody)
                    .foregroundColor(.inkPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($isTranscriptFocused)
                    .frame(minHeight: 120, maxHeight: 280)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.cardSurface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(
                                        isTranscriptFocused
                                            ? Color.accentGold.opacity(0.45)
                                            : Color.borderMuted.opacity(0.5),
                                        lineWidth: isTranscriptFocused ? 1.2 : 0.8
                                    )
                            )
                    )
                Text("Tip: Speak clearly, less background noise = better results.")
                    .font(.system(size: 11))
                    .foregroundColor(.inkMuted.opacity(0.9))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.slash")
                        .font(.system(size: 20))
                        .foregroundColor(.inkMuted.opacity(0.4))
                    Text("Transcription unavailable")
                        .font(.system(size: 14))
                        .foregroundColor(.inkMuted)
                    Text("Save the recording and add or edit text later.")
                        .font(.system(size: 12))
                        .foregroundColor(.inkMuted.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
        }
        .padding(.horizontal)
        .onChange(of: vm.pendingVoiceTranscript) { newValue in
            if let t = newValue { editableTranscript = t }
        }
    }

    private func drawerOption(key: String, icon: String, label: String) -> some View {
        Button {
            if isTutorialMode {
                tutorialManager.showSaveToDrawerForTutorial = false
                tutorialManager.next()
            } else {
                onboarding.onFirstSave()
                if isVoiceMode {
                    vm.saveVoiceCardToDrawer(
                        key,
                        transcriptOverride: editableTranscript.isEmpty ? nil : editableTranscript,
                        customTitle: customTitle.isEmpty ? nil : customTitle,
                        reminderDate: previewReminderDate,
                        starred: previewStarred
                    )
                } else {
                    vm.saveTextCardToDrawer(key)
                }
            }
            dismiss()
        } label: {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(.accentGold)
                Text(label)
                    .font(.cardTitle)
                    .foregroundColor(.inkPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color.cardSurface.opacity(0.8))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.accentGold.opacity(0.4), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Card Fly Animation
/// A note card lifts from the record button, arcs through the air along a bezier
/// curve, and "slots into" the target tab icon (or flies up and off top-right when discarding).
struct CardSlideAnimationView: View {
    let targetTab: Int        // Tab indices: 0 Ideas, 1 Work, 2 Capture, 3 Journal, 4 Settings
    let targetIsBin: Bool     // true = thrown away: fly up and off top-right
    let drawerLabel: String

    @State private var phase: AnimPhase = .idle
    @State private var cardPos: CGPoint = .zero
    @State private var cardRot: Double  = 0
    @State private var cardScale: CGFloat = 1.0
    @State private var cardAlpha: Double  = 1.0
    @State private var shadowR: CGFloat   = 18
    @State private var shadowA: Double    = 0.35
    @State private var glowI: Double      = 0.0
    @State private var trailA: Double     = 0.0
    @State private var badgePop: Bool     = false
    @State private var badgeScale: CGFloat = 0.1

    private enum AnimPhase { case idle, liftOff, traveling, landing, done }

    private let sw = UIScreen.main.bounds.width
    private let sh = UIScreen.main.bounds.height

    private var startPos: CGPoint { CGPoint(x: sw / 2, y: sh * 0.43) }

    private var targetPos: CGPoint {
        if targetIsBin {
            // Discard: off top-right so the card looks thrown away
            return CGPoint(x: sw + 80, y: -60)
        }
        // 5 equal-width tabs: 0 Ideas, 1 Work, 2 Capture, 3 Journal, 4 Settings
        let tw = sw / 5
        let tx = CGFloat(targetTab) * tw + tw / 2
        let ty = sh - 52
        return CGPoint(x: tx, y: ty)
    }

    private var ctrlPt: CGPoint {
        if targetIsBin {
            // Arc up and to the right — control point above and right of start
            return CGPoint(x: startPos.x + sw * 0.35, y: startPos.y - 220)
        }
        let midX = (startPos.x + targetPos.x) / 2
        let topY = min(startPos.y, targetPos.y) - 150
        return CGPoint(x: midX, y: topY)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.0001).ignoresSafeArea()

            // ── Motion trail ──────────────────────────────────────
            if phase == .traveling {
                Circle()
                    .fill(RadialGradient(
                        colors: [Color.accentGold.opacity(trailA * 0.4),
                                 Color.accentGold.opacity(0)],
                        center: .center, startRadius: 4, endRadius: 44
                    ))
                    .frame(width: 88, height: 88)
                    .position(cardPos)
                    .blur(radius: 10)
                    .allowsHitTesting(false)
            }

            // ── Glow halo ─────────────────────────────────────────
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.accentGold.opacity(glowI * 0.45))
                .frame(width: 96, height: 114)
                .blur(radius: 9)
                .position(cardPos)
                .allowsHitTesting(false)

            // ── Card body ─────────────────────────────────────────
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        colors: [Color.cardSurface, Color(hex: "#F2EDD8")],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 84, height: 104)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(
                                colors: [Color.accentGold.opacity(0.88),
                                         Color.accentGold.opacity(0.45)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(shadowA),
                            radius: shadowR, x: 0, y: shadowR * 0.5)

                VStack(spacing: 9) {
                    // Lined paper hint
                    VStack(spacing: 5) {
                        ForEach(0..<3, id: \.self) { i in
                            Capsule()
                                .fill(Color.borderMuted.opacity(0.45 - Double(i) * 0.1))
                                .frame(width: 56 - CGFloat(i) * 10, height: 2)
                        }
                    }
                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.accentGold)
                    Text(drawerLabel.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundColor(.accentGold.opacity(0.85))
                        .tracking(1.2)
                }
            }
            .position(cardPos)
            .rotationEffect(.degrees(cardRot), anchor: .center)
            .scaleEffect(cardScale)
            .opacity(cardAlpha)
            .allowsHitTesting(false)

            // ── Landing badge pop (checkmark for drawer; discard has no badge) ──
            if badgePop, !targetIsBin {
                ZStack {
                    Circle()
                        .fill(Color.accentGold)
                        .frame(width: 24, height: 24)
                        .shadow(color: Color.accentGold.opacity(0.5), radius: 6)
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(badgeScale)
                .position(x: targetPos.x + 11, y: targetPos.y - 18)
                .allowsHitTesting(false)
            }
        }
        .onAppear { runAnimation() }
    }

    // ─────────────────────────────────────────────────────────────
    private func runAnimation() {
        cardPos   = startPos
        cardScale = 1.0
        cardAlpha = 1.0
        shadowR   = 18
        shadowA   = 0.35

        // 1 ▸ Lift off
        phase = .liftOff
        withAnimation(.spring(response: 0.22, dampingFraction: 0.56)) {
            cardPos.y -= 30
            cardScale = 1.14
            shadowR   = 28
            shadowA   = 0.45
            glowI     = 0.65
        }

        // 2 ▸ Fly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            phase = .traveling
            withAnimation(.easeIn(duration: 0.09)) { trailA = 0.6 }
            flyArc()
        }
    }

    private func flyArc() {
        let steps = 48
        let dur   = targetIsBin ? 0.88 : 0.70  // Discard: slightly longer so it feels like a float away
        let dt    = dur / Double(steps)
        var step  = 0

        func tick() {
            guard step <= steps else {
                phase = .landing
                withAnimation(.easeOut(duration: 0.1)) { trailA = 0 }
                land()
                return
            }
            let t  = Double(step) / Double(steps)
            let mt = 1.0 - t

            // Quadratic bezier
            let x = mt*mt*startPos.x + 2*mt*t*ctrlPt.x + t*t*targetPos.x
            let y = mt*mt*startPos.y + 2*mt*t*ctrlPt.y + t*t*targetPos.y

            // Tangent for card rotation (nose points in direction of travel)
            let tx = 2*(1-t)*(ctrlPt.x - startPos.x) + 2*t*(targetPos.x - ctrlPt.x)
            let ty = 2*(1-t)*(ctrlPt.y - startPos.y) + 2*t*(targetPos.y - ctrlPt.y)
            let angle = atan2(ty, tx) * 180 / .pi - 90

            // Smoothstep easing so it accelerates as it falls
            let s = t * t * (3 - 2*t)

            withAnimation(.linear(duration: dt)) {
                cardPos   = CGPoint(x: x, y: y)
                cardRot   = angle
                cardScale = 1.14 - CGFloat(s) * 0.74
                shadowR   = 28  - CGFloat(s) * 24
                shadowA   = 0.45 - s * 0.36
            }

            step += 1
            DispatchQueue.main.asyncAfter(deadline: .now() + dt) { tick() }
        }
        tick()
    }

    private func land() {
        if targetIsBin {
            // Thrown away: card has flown off top-right; just fade out and finish
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.25)) {
                cardAlpha = 0
                cardScale = 0.5
                shadowA   = 0
                glowI     = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                phase = .done
            }
        } else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.16, dampingFraction: 0.52)) {
                cardScale = 0.50
                shadowR   = 12
                shadowA   = 0.45
                glowI     = 1.25
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                withAnimation(.spring(response: 0.26, dampingFraction: 0.88)) {
                    cardScale = 0.18
                    cardRot  += 14
                    shadowR   = 3
                    glowI     = 0.3
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeIn(duration: 0.2)) {
                    cardAlpha = 0
                    cardScale = 0.04
                    shadowA   = 0
                    glowI     = 0
                }
                badgePop = true
                withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) {
                    badgeScale = 1.0
                }
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeOut(duration: 0.25)) {
                    badgeScale = 0.1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    badgePop = false
                    phase    = .done
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    HomeCaptureScreen()
        .environment(\.managedObjectContext, PersistenceController.preview.viewContext)
        .environmentObject(AudioService())
}