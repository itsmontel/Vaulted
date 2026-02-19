import SwiftUI

// MARK: - TextComposerSheet
struct TextComposerSheet: View {
    var onSave: (String, String) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var bodyFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paperBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Title field
                    TextField("Title (optional)", text: $title)
                        .font(.drawerLabel)
                        .foregroundColor(.inkPrimary)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)

                    Divider().padding(.horizontal, 16)

                    // Body field
                    TextEditor(text: $bodyText)
                        .font(.cardSnippet)
                        .foregroundColor(.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($bodyFocused)
                        .padding(.horizontal, 12)

                    Spacer()
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.inkMuted)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let t = title.isEmpty ? "New card" : title
                        onSave(t, bodyText)
                    }
                    .disabled(bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .fontWeight(.semibold)
                    .foregroundColor(.accentGold)
                }
            }
            .onAppear { bodyFocused = true }
        }
    }
}
