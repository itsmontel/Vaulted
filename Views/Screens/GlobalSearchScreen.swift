import SwiftUI

// MARK: - GlobalSearchScreen
/// Search across all notes from any drawer
struct GlobalSearchScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var moc
    @StateObject private var vm = GlobalSearchViewModel()
    @State private var selectedCard: CardEntity?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paperBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 8)

                    Divider()

                    // Results
                    if vm.searchQuery.isEmpty {
                        emptySearchState
                    } else if vm.searchResults.isEmpty {
                        noResultsState
                    } else {
                        resultsList
                    }
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.accentGold)
                }
            }
            .sheet(item: $selectedCard) { card in
                CardDetailScreen(
                    card: card,
                    audioService: AudioService(),
                    securityService: SecurityService.shared,
                    onDismiss: { vm.refresh() }
                )
                .environment(\.managedObjectContext, moc)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.inkMuted)
                .font(.system(size: 18))
            TextField("Search all notes...", text: $vm.searchQuery)
                .font(.cardSnippet)
                .foregroundColor(.inkPrimary)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: vm.searchQuery) { _ in
                    vm.performSearch()
                }
            if !vm.searchQuery.isEmpty {
                Button {
                    vm.searchQuery = ""
                    vm.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.inkMuted)
                        .font(.system(size: 18))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.cardSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.borderMuted, lineWidth: 1.5)
        )
        .cornerRadius(10)
    }

    private var emptySearchState: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.inkMuted.opacity(0.4))
            Text("Search your notes")
                .font(.drawerLabel)
                .foregroundColor(.inkMuted)
            Text("Search by title, content, tags, or transcribed text")
                .font(.cardSnippet)
                .foregroundColor(.inkMuted.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var noResultsState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundColor(.inkMuted.opacity(0.4))
            Text("No results found")
                .font(.drawerLabel)
                .foregroundColor(.inkMuted)
            Text("Try different keywords")
                .font(.cardSnippet)
                .foregroundColor(.inkMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(vm.searchResults, id: \.objectID) { card in
                    let locked = card.drawer?.isPrivate == true && !SecurityService.shared.privateDrawerIsUnlocked
                    Button {
                        if locked {
                            Task {
                                let success = await SecurityService.shared.authenticateAndUnlock()
                                if success {
                                    selectedCard = card
                                }
                            }
                        } else {
                            selectedCard = card
                        }
                    } label: {
                        CardRowView(card: card, isRedacted: locked)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    Divider()
                        .padding(.leading, 16)
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - GlobalSearchViewModel
@MainActor
final class GlobalSearchViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [CardEntity] = []

    private let cardRepo = CardRepository()

    func performSearch() {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        searchResults = cardRepo.fetchAllCards(searchQuery: searchQuery)
    }

    func refresh() {
        performSearch()
    }
}
