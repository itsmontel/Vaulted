import SwiftUI

// MARK: - DrawerCabinetView
struct DrawerCabinetView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var selectedCard: CardEntity?
    @State private var openGroup: String?
    @State private var showAuthSheet = false

    // Special "Private" tray item
    private let privateLabel = "Private"

    var body: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(weekdayGroups, id: \.label) { group in
                    drawerRow(group: group)
                }
                // Always show the Private drawer at bottom
                privateDrawerRow
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Weekday groups
    private var weekdayGroups: [(label: String, cards: [CardEntity])] {
        // Build from weekday grouping but exclude private cards when locked
        let publicCards = vm.cards.filter { $0.drawer?.isPrivate != true }
        let cal = Calendar.current
        let weekdays = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        var dict: [Int: [CardEntity]] = [:]
        for card in publicCards {
            let wd = cal.component(.weekday, from: card.createdAt ?? Date())
            dict[wd, default: []].append(card)
        }
        return dict.keys.sorted().map { wd in (weekdays[wd - 1], dict[wd]!) }
    }

    // MARK: - Drawer row
    private func drawerRow(group: (label: String, cards: [CardEntity])) -> some View {
        let isOpen = openGroup == group.label

        return VStack(spacing: 0) {
            // Drawer header
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    openGroup = isOpen ? nil : group.label
                }
            } label: {
                HStack {
                    // Handle notch
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.drawerHandle)
                        .frame(width: 40, height: 10)
                        .padding(.leading, 8)

                    Text(group.label)
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundColor(.inkPrimary)

                    Spacer()

                    Text("\(group.cards.count)")
                        .font(.cardCaption)
                        .foregroundColor(.inkMuted)

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.inkMuted)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .background(
                    LinearGradient(colors: [Color.hex("#EDE5D4"), Color.hex("#DDD0B8")],
                                   startPoint: .top, endPoint: .bottom)
                )
                .overlay(
                    Rectangle()
                        .fill(Color.borderMuted)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }
            .buttonStyle(.plain)

            // Slide-out tray (List for swipe-to-delete)
            if isOpen {
                List {
                    ForEach(group.cards, id: \.objectID) { card in
                        Button { selectedCard = card } label: {
                            CardRowView(card: card)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                vm.deleteCard(card)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                vm.toggleStar(card)
                                vm.reloadCards()
                            } label: {
                                Label(card.starred ? "Unstar" : "Star",
                                      systemImage: card.starred ? "star.slash" : "star")
                            }
                            .tint(.accentGold)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(group.cards.count) * 80)
                .padding(12)
                .background(Color.cardSurface.opacity(0.6))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(Color.hex("#DDD0B8"))
        .cornerRadius(6)
        .shadow(color: .inkPrimary.opacity(0.1), radius: 3, x: 0, y: 2)
        .padding(.bottom, 4)
    }

    // MARK: - Private drawer row
    private var privateDrawerRow: some View {
        let isOpen = openGroup == privateLabel
        let isUnlocked = vm.isPrivateUnlocked
        let privateCards = vm.cards.filter { $0.drawer?.isPrivate == true }

        return VStack(spacing: 0) {
            Button {
                if isUnlocked {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        openGroup = isOpen ? nil : privateLabel
                    }
                } else {
                    Task {
                        let success = await vm.unlockPrivate()
                        if success {
                            withAnimation { openGroup = privateLabel }
                        }
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    // Lock ornament
                    Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                        .foregroundColor(isUnlocked ? .accentGold : .white)
                        .font(.system(size: 14))

                    Text("PRIVATE")
                        .font(.system(.subheadline, design: .serif).weight(.bold))
                        .tracking(2)
                        .foregroundColor(.white)

                    Spacer()

                    if isUnlocked {
                        Text("\(privateCards.count)")
                            .font(.cardCaption)
                            .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("Face ID")
                            .font(.cardCaption)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 16)
                .background(
                    LinearGradient(colors: [Color.lockedBrown, Color.hex("#5C3D1E")],
                                   startPoint: .top, endPoint: .bottom)
                )
            }
            .buttonStyle(.plain)

            if isOpen && isUnlocked {
                Group {
                    if privateCards.isEmpty {
                        Text("No private cards yet.")
                            .font(.cardCaption)
                            .foregroundColor(.inkMuted)
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        List {
                            ForEach(privateCards, id: \.objectID) { card in
                                Button { selectedCard = card } label: {
                                    CardRowView(card: card, isRedacted: false)
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        vm.deleteCard(card)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        vm.toggleStar(card)
                                        vm.reloadCards()
                                    } label: {
                                        Label(card.starred ? "Unstar" : "Star",
                                              systemImage: card.starred ? "star.slash" : "star")
                                    }
                                    .tint(.accentGold)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: CGFloat(privateCards.count) * 80)
                    }
                }
                .padding(12)
                .background(Color.cardSurface.opacity(0.6))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .cornerRadius(6)
        .shadow(color: .inkPrimary.opacity(0.2), radius: 4, x: 0, y: 3)
        .padding(.bottom, 4)
    }
}
