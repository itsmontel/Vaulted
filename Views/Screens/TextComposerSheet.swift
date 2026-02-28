import SwiftUI

// MARK: - TextComposerSheet
struct TextComposerSheet: View {
    var onSave: (String, String) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var bodyFocused: Bool
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paperBackground.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    // Title field with theme-aware placeholder
                    ZStack(alignment: .leading) {
                        if title.isEmpty {
                            Text("Title (optional)")
                                .font(.drawerLabel)
                                .foregroundColor(.placeholderColor)
                                .padding(.horizontal, 16)
                                .padding(.top, 12)
                        }
                        TextField("", text: $title)
                            .font(.drawerLabel)
                            .foregroundColor(.inkPrimary)
                            .padding(.horizontal, 16)
                            .padding(.top, 12)
                    }
                    .frame(minHeight: 44)

                    Divider()
                        .background(Color.borderMuted)
                        .padding(.horizontal, 16)

                    // Body field
                    TextEditor(text: $bodyText)
                        .font(.cardSnippet)
                        .foregroundColor(.inkPrimary)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                        .focused($bodyFocused)
                        .padding(.horizontal, 12)
                }
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(themeManager.theme.paperBackground, for: .navigationBar)
            .toolbarColorScheme(themeManager.theme.isDark ? .dark : .light, for: .navigationBar)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .foregroundColor(.accentGold)
                }
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
            .tint(.accentGold)
            .onAppear { bodyFocused = true }
        }
    }
}
