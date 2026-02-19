import SwiftUI

// MARK: - BookOpenView
/// Opens when user taps a book spine. Swipe through note pages like reading a book.
struct BookOpenView: View {
    let bookLabel: String
    let cards: [CardEntity]
    let onDismiss: () -> Void
    let onCardSelected: (CardEntity) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paperBackground.ignoresSafeArea()

                if cards.isEmpty {
                    Text("No notes in this period")
                        .font(.cardSnippet)
                        .foregroundColor(.inkMuted)
                } else {
                    TabView {
                        ForEach(cards, id: \.objectID) { card in
                            bookPage(card: card)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .automatic))
                    .indexViewStyle(.page(backgroundDisplayMode: .automatic))
                }
            }
            .navigationTitle(bookLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { onDismiss() }
                        .foregroundColor(.accentGold)
                }
            }
        }
    }

    private func bookPage(card: CardEntity) -> some View {
        Button {
            onCardSelected(card)
            onDismiss()
        } label: {
            VStack(alignment: .leading, spacing: 16) {
                CardRowView(card: card, isRedacted: false)
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.cardSurface)
                    .vaultCard()
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
        }
        .buttonStyle(.plain)
    }
}
