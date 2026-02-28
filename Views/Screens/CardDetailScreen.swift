import SwiftUI

// MARK: - CardDetailScreen
struct CardDetailScreen: View {
    let card: CardEntity
    let onDismiss: () -> Void
    @StateObject private var vm: CardDetailViewModel
    @State private var showDrawerPicker = false
    @State private var showTagEditor = false
    @State private var showReminderPicker = false
    @State private var showDeleteConfirm = false
    @State private var regenerateTitleToast: String?
    @Environment(\.dismiss) private var dismiss

    init(card: CardEntity, audioService: AudioService, securityService: SecurityService, onDismiss: @escaping () -> Void) {
        self.card = card
        self.onDismiss = onDismiss
        _vm = StateObject(wrappedValue: CardDetailViewModel(card: card, audioService: audioService, securityService: securityService))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paperBackground.ignoresSafeArea()

                if vm.requiresAuth && !vm.isUnlocked {
                    lockedView
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        vm.audioService.stopPlayback()
                        onDismiss()
                        dismiss()
                    }
                    .foregroundColor(.inkMuted)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(.red.opacity(0.7))
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.accentGold)
                }
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        if hasTranscriptForRegenerate {
                            Button {
                                if vm.regenerateTitle() != nil {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    regenerateTitleToast = "Title updated"
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        regenerateTitleToast = nil
                                    }
                                }
                            } label: {
                                Label("Regenerate Title", systemImage: "text.cursor")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.inkMuted)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if let toast = regenerateTitleToast {
                    Text(toast)
                        .font(.cardCaption)
                        .foregroundColor(.inkPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.cardSurface)
                        .vaultCard()
                        .padding(.bottom, 24)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .animation(.easeOut(duration: 0.2), value: regenerateTitleToast != nil)
            .confirmationDialog("Delete this card?",
                                isPresented: $showDeleteConfirm,
                                titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    CardRepository().delete(card)
                    onDismiss()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showDrawerPicker) {
                DrawerPickerSheet(drawers: vm.drawers,
                                  current: card.drawer) { drawer in
                    vm.moveTo(drawer: drawer)
                    showDrawerPicker = false
                }
            }
            .sheet(isPresented: $showTagEditor) {
                TagEditorSheet(tagsInput: $vm.tagsInput) {
                    vm.saveTags()
                    showTagEditor = false
                }
            }
            .sheet(isPresented: $showReminderPicker) {
                ReminderPickerSheet(
                    currentReminder: card.reminderDate,
                    onSave: { date in
                        vm.setReminder(date)
                        showReminderPicker = false
                    },
                    onClear: {
                        vm.setReminder(nil)
                        showReminderPicker = false
                    },
                    onCancel: { showReminderPicker = false }
                )
            }
        }
    }

    private var hasTranscriptForRegenerate: Bool {
        let t = card.typedCopy ?? card.bodyText ?? card.snippet ?? ""
        return !t.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Locked state
    private var lockedView: some View {
        VStack(spacing: 24) {
            Image(systemName: "lock.fill")
                .font(.system(size: 52))
                .foregroundColor(.accentGold)
            Text("Private Card")
                .font(.drawerLabel)
                .foregroundColor(.inkPrimary)
            Text("This card is in your locked Private drawer.")
                .font(.cardSnippet)
                .foregroundColor(.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                Task { await vm.unlockCard() }
            } label: {
                Label("Unlock with Face ID", systemImage: "faceid")
                    .font(.system(.body, design: .serif))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.accentGold)
                    .cornerRadius(8)
            }
        }
        .padding(32)
    }

    // MARK: - Main content
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Card header
                cardHeaderView

                // Actions row (star, file, tag, private)
                actionsRow

                // Voice: audio player then transcribed note below
                if card.isVoice {
                    AudioPlayerView(audioService: vm.audioService,
                                    audioURL: card.audioURL,
                                    totalDuration: card.durationSec)
                    transcribedNoteSection
                }

                // Body text (text cards only)
                if card.type == "text" {
                    textBodyEditor
                }

                Divider()

                // Drawer + metadata
                metaSection

                Spacer(minLength: 40)
            }
            .padding(20)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    // MARK: - Transcribed note (voice cards; below audio player)
    private var transcribedNoteSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transcribed note")
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
                    .textCase(.uppercase)
                    .tracking(1)
                Spacer()
            }
            Text("Auto-generated from your recording. Tap to edit anytime.")
                .font(.system(size: 12))
                .foregroundColor(.inkMuted.opacity(0.9))

            TextEditor(text: $vm.editingTypedCopy)
                .font(.cardSnippet)
                .foregroundColor(.inkPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 240, maxHeight: 500)
                .onChange(of: vm.editingTypedCopy) { _ in vm.saveTypedCopy() }
        }
        .padding(16)
        .background(Color.cardSurface)
        .vaultCard()
    }

    // MARK: - Card header
    private var cardHeaderView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Editable title
            TextField("Title", text: $vm.editingTitle,
                      onCommit: { vm.saveTitle() })
                .font(.drawerLabel)
                .foregroundColor(.inkPrimary)
                .textFieldStyle(.plain)

            // Date + drawer
            HStack(spacing: 8) {
                Text(formattedDate)
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
                if let drawer = card.drawer {
                    Text("·")
                        .foregroundColor(.borderMuted)
                    Text(drawer.displayName)
                        .font(.cardCaption)
                        .foregroundColor(.accentGold)
                }
                Spacer()
            }

            // Tags
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(card.tagList, id: \.self) { tag in
                        TagChip(label: tag)
                    }
                    Button {
                        vm.tagsInput = card.tags ?? ""
                        showTagEditor = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.tagChip)
                            .foregroundColor(.accentGold)
                            .padding(6)
                            .background(Color.accentGold.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .background(Color.cardSurface)
        .vaultCard()
    }

    // MARK: - Text body
    private var textBodyEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Note")
                .font(.cardCaption)
                .foregroundColor(.inkMuted)
                .textCase(.uppercase)
                .tracking(1)

            TextEditor(text: $vm.editingBody)
                .font(.cardSnippet)
                .foregroundColor(.inkPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 140)
                .onChange(of: vm.editingBody) { _ in vm.saveBody() }
        }
        .padding(16)
        .background(Color.cardSurface)
        .vaultCard()
    }

    // MARK: - Actions row
    private var actionsRow: some View {
        HStack(spacing: 0) {
            actionButton(icon: card.starred ? "star.fill" : "star",
                         label: "Star",
                         color: card.starred ? .accentGold : .inkMuted) {
                vm.toggleStar()
            }
            Divider().frame(height: 36)
            actionButton(icon: "folder", label: "File", color: .inkMuted) {
                showDrawerPicker = true
            }
            Divider().frame(height: 36)
            actionButton(icon: "tag", label: "Tag", color: .inkMuted) {
                vm.tagsInput = card.tags ?? ""
                showTagEditor = true
            }
            Divider().frame(height: 36)
            actionButton(icon: card.reminderDate != nil ? "bell.fill" : "bell",
                         label: "Remind",
                         color: card.reminderDate != nil ? .accentGold : .inkMuted) {
                showReminderPicker = true
            }
            Divider().frame(height: 36)
            actionButton(icon: "lock", label: "Private", color: .inkMuted) {
                Task { await vm.moveToPrivate() }
            }
        }
        .padding(.vertical, 4)
        .background(Color.cardSurface)
        .vaultCard()
    }

    private func actionButton(icon: String, label: String,
                              color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                Text(label)
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Meta section
    private var metaSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Details")
                .font(.cardCaption)
                .foregroundColor(.inkMuted)
                .textCase(.uppercase)
                .tracking(1)

            HStack {
                Label("Created", systemImage: "calendar")
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
                Spacer()
                Text(formattedDate)
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
            }

            if card.isVoice {
                HStack {
                    Label("Duration", systemImage: "clock")
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                    Spacer()
                    Text(formatDuration(card.durationSec))
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                }
            }

            if let reminder = card.reminderDate {
                HStack {
                    Label("Reminder", systemImage: "bell.fill")
                        .font(.cardCaption)
                        .foregroundColor(.accentGold)
                    Spacer()
                    Text(formatReminderDate(reminder))
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)
                }
            }
        }
        .padding(16)
        .background(Color.cardSurface)
        .vaultCard()
    }

    private var formattedDate: String {
        guard let d = card.createdAt else { return "" }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy · h:mm a"
        return fmt.string(from: d)
    }

    private func formatDuration(_ secs: Double) -> String {
        let s = Int(secs)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    private func formatReminderDate(_ d: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(d) {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "Today at \(fmt.string(from: d))"
        }
        if cal.isDateInTomorrow(d) {
            let fmt = DateFormatter()
            fmt.dateFormat = "h:mm a"
            return "Tomorrow at \(fmt.string(from: d))"
        }
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d, yyyy · h:mm a"
        return fmt.string(from: d)
    }
}

// MARK: - ReminderPickerSheet
struct ReminderPickerSheet: View {
    let currentReminder: Date?
    var onSave: (Date) -> Void
    var onClear: () -> Void
    var onCancel: () -> Void

    @State private var selectedDate: Date
    @Environment(\.dismiss) private var dismiss

    init(currentReminder: Date?, onSave: @escaping (Date) -> Void, onClear: @escaping () -> Void, onCancel: @escaping () -> Void) {
        self.currentReminder = currentReminder
        self.onSave = onSave
        self.onClear = onClear
        self.onCancel = onCancel
        _selectedDate = State(initialValue: currentReminder ?? Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker("Remind me", selection: $selectedDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
                    .padding()
                    .background(Color.cardSurface)
                    .cornerRadius(12)

                if currentReminder != nil {
                    Button {
                        onClear()
                        dismiss()
                    } label: {
                        Label("Clear Reminder", systemImage: "bell.slash")
                            .font(.cardBody)
                            .foregroundColor(.red)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer()
            }
            .padding(20)
            .background(Color.paperBackground)
            .navigationTitle("Set Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                        dismiss()
                    }
                    .foregroundColor(.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(selectedDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.accentGold)
                }
            }
        }
    }
}

// MARK: - DrawerPickerSheet
struct DrawerPickerSheet: View {
    let drawers: [DrawerEntity]
    let current: DrawerEntity?
    var onSelect: (DrawerEntity) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(drawers, id: \.objectID) { drawer in
                Button {
                    onSelect(drawer)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: drawer.isPrivate ? "lock.fill" : "folder")
                            .foregroundColor(drawer.isPrivate ? .accentGold : .inkMuted)
                        Text(drawer.displayName)
                            .foregroundColor(.inkPrimary)
                        Spacer()
                        if drawer.objectID == current?.objectID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentGold)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Move to Drawer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - TagEditorSheet
struct TagEditorSheet: View {
    @Binding var tagsInput: String
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Enter tags separated by commas")
                    .font(.cardCaption)
                    .foregroundColor(.inkMuted)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                TextField("ideas, work, morning…", text: $tagsInput)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal, 20)

                // Preview chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tagsInput.split(separator: ",").map {
                            String($0).trimmingCharacters(in: .whitespaces)
                        }.filter { !$0.isEmpty }, id: \.self) { tag in
                            TagChip(label: tag)
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Spacer()
            }
            .background(Color.paperBackground)
            .navigationTitle("Edit Tags")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.accentGold)
                }
            }
        }
    }
}
