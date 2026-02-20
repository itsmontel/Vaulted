import SwiftUI

// MARK: - Drawer colour palette (one per weekday slot, deterministic)
private struct DrawerTint {
    let front: Color       // main face panel
    let shadow: Color      // bottom edge / shadow
    let highlight: Color   // top edge catch-light
    let label: Color       // inset label background
    let text: Color        // label text
    let tab: Color         // pull-tab colour
    let paperEdge: Color   // stacked paper edges visible on right side

    static let palette: [DrawerTint] = [
        // Sunday — warm ivory
        DrawerTint(front:      Color(hex: "#D4C9A8"),
                   shadow:     Color(hex: "#A89C7C"),
                   highlight:  Color(hex: "#EDE4CC"),
                   label:      Color(hex: "#C4B898"),
                   text:       Color(hex: "#2A2010"),
                   tab:        Color(hex: "#B8A882"),
                   paperEdge:  Color(hex: "#F4F0E4")),
        // Monday — deep navy
        DrawerTint(front:      Color(hex: "#2A3E60"),
                   shadow:     Color(hex: "#162438"),
                   highlight:  Color(hex: "#3A5278"),
                   label:      Color(hex: "#1E3050"),
                   text:       Color(hex: "#D8E4F2"),
                   tab:        Color(hex: "#4A6484"),
                   paperEdge:  Color(hex: "#B8C8DC")),
        // Tuesday — forest green
        DrawerTint(front:      Color(hex: "#34583A"),
                   shadow:     Color(hex: "#1C3220"),
                   highlight:  Color(hex: "#446A4C"),
                   label:      Color(hex: "#264230"),
                   text:       Color(hex: "#CCE4CC"),
                   tab:        Color(hex: "#4C7254"),
                   paperEdge:  Color(hex: "#A8CCA8")),
        // Wednesday — warm terracotta
        DrawerTint(front:      Color(hex: "#924030"),
                   shadow:     Color(hex: "#5E2418"),
                   highlight:  Color(hex: "#B05440"),
                   label:      Color(hex: "#742C20"),
                   text:       Color(hex: "#F8E4D8"),
                   tab:        Color(hex: "#B05840"),
                   paperEdge:  Color(hex: "#F0C8B4")),
        // Thursday — plum
        DrawerTint(front:      Color(hex: "#503060"),
                   shadow:     Color(hex: "#2E1840"),
                   highlight:  Color(hex: "#684078"),
                   label:      Color(hex: "#3C2050"),
                   text:       Color(hex: "#EED8F4"),
                   tab:        Color(hex: "#6A4880"),
                   paperEdge:  Color(hex: "#D4B8E8")),
        // Friday — dark teal
        DrawerTint(front:      Color(hex: "#1A4848"),
                   shadow:     Color(hex: "#0C2C2C"),
                   highlight:  Color(hex: "#285C5C"),
                   label:      Color(hex: "#123434"),
                   text:       Color(hex: "#C8E8E8"),
                   tab:        Color(hex: "#2C6464"),
                   paperEdge:  Color(hex: "#98D0D0")),
        // Saturday — warm ochre
        DrawerTint(front:      Color(hex: "#8A6818"),
                   shadow:     Color(hex: "#5A420A"),
                   highlight:  Color(hex: "#A88024"),
                   label:      Color(hex: "#6C500E"),
                   text:       Color(hex: "#F8ECC8"),
                   tab:        Color(hex: "#A87E20"),
                   paperEdge:  Color(hex: "#F0D888")),
    ]

    static func forWeekday(_ weekday: Int) -> DrawerTint {
        palette[(weekday - 1) % palette.count]
    }
}

// MARK: - DrawerCabinetView
struct DrawerCabinetView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var selectedCard: CardEntity?
    var showLockIndicator: Bool = false

    @State private var openGroup: String? = nil
    @State private var animatingOpen: String? = nil   // drawer currently mid-animation
    @State private var drawerOffsets: [String: CGFloat] = [:]  // pull-out offset per drawer

    // Time navigation — 0 = current; negative = past (matches Bookshelf)
    @State private var dailyWeekOffset: Int  = 0
    @State private var weeklyPageOffset: Int = 0
    @State private var yearOffset: Int       = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 6) {

                periodPicker
                    .padding(.bottom, 8)

                // Cabinet top rail
                cabinetTopRail

                // Drawers (windowed by selected period: daily 7 days, weekly 12 weeks, monthly 12 months)
                ForEach(Array(windowedGroups.enumerated()), id: \.element.label) { idx, group in
                    let tint = DrawerTint.palette[idx % DrawerTint.palette.count]
                    drawerUnit(group: group, tint: tint)
                }

                // Cabinet floor rail
                cabinetFloorRail
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Cabinet chrome rails
    private let topRailHeight: CGFloat = 26

    private var cabinetTopRail: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#A89878"),
                            Color(hex: "#C4B08C"),
                            Color(hex: "#8C7860"),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: topRailHeight)
                .cornerRadius(4, corners: [.topLeft, .topRight])
            // Rivet marks
            HStack(spacing: 0) {
                Spacer()
                rivet; Spacer(); rivet; Spacer()
            }
            // Lock/unlock indicator — centered vertically in the thicker rail
            if showLockIndicator {
                HStack {
                    Spacer()
                    Button {
                        Task {
                            if vm.isPrivateUnlocked {
                                vm.lockPrivate()
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            } else {
                                let success = await vm.unlockPrivate()
                                if success { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
                                else { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
                            }
                        }
                    } label: {
                        Image(systemName: vm.isPrivateUnlocked ? "lock.open.fill" : "lock.fill")
                            .font(.system(size: 14))
                            .foregroundColor(vm.isPrivateUnlocked ? Color(hex: "#6B8E23") : Color(hex: "#C49245"))
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 14)
                }
            }
        }
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
    }

    private var cabinetFloorRail: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#8C7860"),
                            Color(hex: "#C4B08C"),
                            Color(hex: "#A89878"),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 14)
                .cornerRadius(3, corners: [.bottomLeft, .bottomRight])
            HStack(spacing: 0) {
                Spacer()
                rivet; Spacer(); rivet; Spacer()
            }
        }
        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: -1)
    }

    private var rivet: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [Color(hex: "#E8D8B8"), Color(hex: "#8C7048")],
                    center: .topLeading,
                    startRadius: 0, endRadius: 6
                )
            )
            .frame(width: 8, height: 8)
            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
    }

    // MARK: - Windowed groups (Daily: 7 days, Weekly: 12 weeks, Monthly: 12 months) — matches Bookshelf
    private var windowedGroups: [(label: String, cards: [CardEntity])] {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        switch vm.bookshelfPeriod {
        case .daily:
            let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
            let existing = Dictionary(uniqueKeysWithValues: vm.groupedForBookshelf.map { ($0.label, $0.cards) })
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            c.weekday = 2
            let monday = cal.date(byAdding: .weekOfYear, value: dailyWeekOffset, to: cal.date(from: c) ?? Date()) ?? Date()
            return (0..<7).map { offset in
                let day = cal.date(byAdding: .day, value: offset, to: monday) ?? monday
                let label = dayNames[offset]
                let key = fmt.string(from: day)
                let cards = existing[key] ?? []
                return (label, cards)
            }
        case .weekly:
            let existing = Dictionary(uniqueKeysWithValues: vm.groupedForBookshelf.map { ($0.label, $0.cards) })
            let baseWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            var cur = cal.date(byAdding: .weekOfYear, value: weeklyPageOffset * 4, to: baseWeek) ?? baseWeek
            var result: [(label: String, cards: [CardEntity])] = []
            for _ in 0..<4 {
                let end = cal.date(byAdding: .day, value: 6, to: cur) ?? cur
                let label = "\(fmt.string(from: cur))–\(fmt.string(from: end))"
                let cards = existing[label] ?? []
                result.append((label, cards))
                cur = cal.date(byAdding: .weekOfYear, value: -1, to: cur) ?? cur
            }
            return result
        case .monthly:
            let mFmt = DateFormatter(); mFmt.dateFormat = "MMMM yyyy"
            let existing = Dictionary(uniqueKeysWithValues: vm.groupedByMonth.map { ($0.label, $0.cards) })
            let currentYear = cal.component(.year, from: Date())
            let year = currentYear + yearOffset
            return (1...12).map { month in
                var c = DateComponents(); c.year = year; c.month = month; c.day = 1
                let date = cal.date(from: c) ?? Date()
                let label = mFmt.string(from: date)
                let cards = existing[label] ?? []
                return (label, cards)
            }
        }
    }

    // MARK: - Period picker + time navigation (matches Bookshelf)
    private var periodPicker: some View {
        VStack(spacing: 0) {
            // Row 1: mode tabs
            HStack(spacing: 0) {
                ForEach([BookshelfPeriod.daily, .weekly, .monthly], id: \.self) { period in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.bookshelfPeriod = period }
                    } label: {
                        Text(period.rawValue)
                            .font(.cardCaption)
                            .fontWeight(vm.bookshelfPeriod == period ? .semibold : .regular)
                            .foregroundColor(vm.bookshelfPeriod == period ? .accentGold : .inkMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .background(vm.bookshelfPeriod == period ? Color.accentGold.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)

            // Row 2: time navigation (back / label / forward)
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        switch vm.bookshelfPeriod {
                        case .daily:   dailyWeekOffset  -= 1
                        case .weekly:  weeklyPageOffset -= 1
                        case .monthly: yearOffset       -= 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.accentGold)
                        .frame(width: 32, height: 32)
                        .background(Color.accentGold.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 1) {
                    Text(periodNavigationTitle)
                        .font(.system(.subheadline, design: .serif).weight(.semibold))
                        .foregroundColor(.inkPrimary)
                    Text(periodNavigationSubtitle)
                        .font(.system(.caption, design: .serif))
                        .foregroundColor(.inkMuted)
                }
                .multilineTextAlignment(.center)

                Spacer()

                let isAtPresent: Bool = {
                    switch vm.bookshelfPeriod {
                    case .daily:   return dailyWeekOffset  >= 0
                    case .weekly:  return weeklyPageOffset >= 0
                    case .monthly: return yearOffset       >= 0
                    }
                }()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        switch vm.bookshelfPeriod {
                        case .daily:   dailyWeekOffset  += 1
                        case .weekly:  weeklyPageOffset += 1
                        case .monthly: yearOffset       += 1
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isAtPresent ? .inkMuted.opacity(0.3) : .accentGold)
                        .frame(width: 32, height: 32)
                        .background(isAtPresent ? Color.clear : Color.accentGold.opacity(0.10))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isAtPresent)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
    }

    private var periodNavigationTitle: String {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        switch vm.bookshelfPeriod {
        case .daily:
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            c.weekday = 2
            let monday = cal.date(from: c).flatMap { cal.date(byAdding: .weekOfYear, value: dailyWeekOffset, to: $0) } ?? Date()
            let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
            if dailyWeekOffset == 0 { return "This Week" }
            if dailyWeekOffset == -1 { return "Last Week" }
            return "\(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
        case .weekly:
            if weeklyPageOffset == 0 { return "Recent 4 Weeks" }
            let weeksBack = abs(weeklyPageOffset) * 4
            return "\(weeksBack)–\(weeksBack + 3) Weeks Ago"
        case .monthly:
            let year = cal.component(.year, from: Date()) + yearOffset
            if yearOffset == 0 { return "This Year" }
            if yearOffset == -1 { return "Last Year" }
            return "\(year)"
        }
    }

    private var periodNavigationSubtitle: String {
        let cal = Calendar.current
        let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
        switch vm.bookshelfPeriod {
        case .daily:
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            c.weekday = 2
            let monday = cal.date(from: c).flatMap { cal.date(byAdding: .weekOfYear, value: dailyWeekOffset, to: $0) } ?? Date()
            let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
            if dailyWeekOffset == 0 {
                return "\(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
            }
            return "Mon – Sun"
        case .weekly:
            let base = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let newest = cal.date(byAdding: .weekOfYear, value: weeklyPageOffset * 4, to: base) ?? base
            let oldest = cal.date(byAdding: .weekOfYear, value: weeklyPageOffset * 4 - 3, to: base) ?? base
            let df = DateFormatter(); df.dateFormat = "MMM d, yyyy"
            return "\(df.string(from: oldest)) – \(df.string(from: newest))"
        case .monthly:
            let year = cal.component(.year, from: Date()) + yearOffset
            return "Jan – Dec \(year)"
        }
    }

    // MARK: - Single drawer unit
    private func drawerUnit(group: (label: String, cards: [CardEntity]), tint: DrawerTint) -> some View {
        let isOpen = openGroup == group.label
        let stackDepth = min(CGFloat(group.cards.count) * 1.4, 18)

        return VStack(spacing: 0) {
            // ── Drawer face ──────────────────────────────────────────
            drawerFace(label: group.label, count: group.cards.count,
                       tint: tint, isOpen: isOpen, stackDepth: stackDepth) {
                toggleDrawer(group.label)
            }

            // ── Slide-out tray ────────────────────────────────────────
            if isOpen {
                drawerTray(cards: group.cards, tint: tint)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .top).combined(with: .opacity),
                            removal: .move(edge: .top).combined(with: .opacity)
                        )
                    )
            }
        }
        .background(tint.shadow.opacity(0.5))
        .cornerRadius(4)
        .shadow(color: .black.opacity(isOpen ? 0.22 : 0.14), radius: isOpen ? 8 : 4, x: 0, y: isOpen ? 5 : 2)
        .animation(.spring(response: 0.38, dampingFraction: 0.72), value: isOpen)
    }

    // MARK: - Drawer face panel
    private func drawerFace(
        label: String,
        count: Int,
        tint: DrawerTint,
        isOpen: Bool,
        stackDepth: CGFloat,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            ZStack(alignment: .trailing) {
                // Paper-edge stack indicator on right side
                if count > 0 {
                    VStack(spacing: 1.4) {
                        ForEach(0..<min(count, 9), id: \.self) { i in
                            Rectangle()
                                .fill(tint.paperEdge.opacity(0.7 - Double(i) * 0.06))
                                .frame(width: 4, height: 1.8)
                        }
                    }
                    .padding(.trailing, 2)
                    .padding(.top, 8)
                    .frame(maxHeight: .infinity, alignment: .top)
                }

                // Main face
                HStack(spacing: 0) {
                    // Left edge shadow strip (gives 3D depth)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.shadow, tint.front.opacity(0)],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: 6)

                    // Face content
                    HStack(alignment: .center, spacing: 12) {
                        // Label card (inset recess)
                        ZStack {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(tint.label)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(tint.shadow.opacity(0.5), lineWidth: 0.8)
                                )
                                .shadow(color: .black.opacity(0.18), radius: 2, x: 0, y: 1)
                                .frame(width: 110, height: 28)

                            Text(label.uppercased())
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .tracking(2.5)
                                .foregroundColor(tint.text)
                        }

                        Spacer()

                        // Card count badge
                        if count > 0 {
                            ZStack {
                                Capsule()
                                    .fill(tint.shadow.opacity(0.5))
                                    .overlay(Capsule().stroke(tint.highlight.opacity(0.3), lineWidth: 0.6))
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundColor(tint.text.opacity(0.9))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                            }
                            .fixedSize()
                        }

                        // Pull tab
                        pullTab(tint: tint, isOpen: isOpen)
                            .padding(.trailing, 8)
                    }
                    .padding(.leading, 10)
                    .padding(.vertical, 14)
                }
                .background(
                    LinearGradient(
                        colors: [
                            tint.highlight,
                            tint.front,
                            tint.front,
                            tint.shadow.opacity(0.6),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                // Top lip (thicker band so drawers feel more substantial; padlock area reads better)
                .overlay(
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [tint.highlight.opacity(0.6), tint.front.opacity(0.3)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: 6),
                    alignment: .top
                )
                // Bottom shadow line
                .overlay(
                    Rectangle()
                        .fill(tint.shadow.opacity(0.8))
                        .frame(height: 1.5),
                    alignment: .bottom
                )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Pull tab
    private func pullTab(tint: DrawerTint, isOpen: Bool) -> some View {
        ZStack {
            // Tab body
            RoundedRectangle(cornerRadius: 3)
                .fill(
                    LinearGradient(
                        colors: [tint.tab.opacity(0.9), tint.shadow],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .stroke(tint.shadow.opacity(0.6), lineWidth: 0.8)
                )
                .frame(width: 32, height: 22)
                .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 2)

            // Grip lines
            VStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle()
                        .fill(tint.text.opacity(0.25))
                        .frame(width: 18, height: 1)
                        .cornerRadius(0.5)
                }
            }

            // Open indicator chevron
            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                .font(.system(size: 7, weight: .bold))
                .foregroundColor(tint.text.opacity(0.6))
                .offset(y: 9)
        }
        .rotationEffect(isOpen ? .degrees(2) : .degrees(0))
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isOpen)
    }

    // MARK: - Drawer tray (open content)
    private func drawerTray(cards: [CardEntity], tint: DrawerTint) -> some View {
        VStack(spacing: 0) {
            // Tray top ledge
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.shadow, tint.front.opacity(0.3)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 4)

            // Inner tray surface
            ZStack {
                // Tray floor texture
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.paperBackground.opacity(0.92),
                                Color.cardSurface.opacity(0.85),
                            ],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                // Side walls hint
                HStack {
                    Rectangle()
                        .fill(tint.shadow.opacity(0.15))
                        .frame(width: 3)
                    Spacer()
                    Rectangle()
                        .fill(tint.shadow.opacity(0.12))
                        .frame(width: 3)
                }

                VStack(spacing: 0) {
                    if cards.isEmpty {
                        emptyTrayPlaceholder(tint: tint)
                    } else {
                        List {
                            ForEach(cards, id: \.objectID) { card in
                                cardTrayRow(card: card, tint: tint)
                                    .listRowInsets(EdgeInsets(top: 5, leading: 10, bottom: 5, trailing: 10))
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                        Button(role: .destructive) {
                                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                            vm.deleteCard(card)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        Button {
                                            vm.toggleStar(card)
                                            vm.reloadCards()
                                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                        } label: {
                                            Label(card.starred ? "Unstar" : "Star",
                                                  systemImage: card.starred ? "star.slash" : "star")
                                        }
                                        .tint(Color.accentGold)
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: CGFloat(min(cards.count, 6)) * 82)
                    }
                }
            }

            // Tray bottom ledge
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [tint.front.opacity(0.2), tint.shadow],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .frame(height: 4)
        }
    }

    // MARK: - Card inside tray
    private func cardTrayRow(card: CardEntity, tint: DrawerTint) -> some View {
        let locked = showLockIndicator && !vm.isPrivateUnlocked
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            selectedCard = card
        } label: {
            HStack(spacing: 12) {
                // Colored tab strip on left (like a folder tab)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tint.tab)
                    .frame(width: 3)
                    .padding(.vertical, 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .top) {
                        Image(systemName: card.isVoice ? "waveform" : "doc.text")
                            .font(.system(size: 11))
                            .foregroundColor(tint.tab)

                        Text(locked ? "••••••••••" : (card.title ?? "Untitled"))
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(.inkPrimary)
                            .lineLimit(1)

                        Spacer()

                        if card.starred && !locked {
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.accentGold)
                        }

                        Text(shortDate(card.createdAt))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.inkMuted)
                    }

                    if locked {
                        Text("••••••••••••••")
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundColor(.inkMuted)
                            .lineLimit(1)
                    } else if !card.isVoice, let snippet = card.snippet, !snippet.isEmpty {
                        Text(snippet)
                            .font(.system(size: 12, design: .serif))
                            .italic()
                            .foregroundColor(.inkMuted)
                            .lineLimit(1)
                    } else if card.isVoice {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill").font(.system(size: 8))
                            Text(formatDur(card.durationSec))
                        }
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.inkMuted)
                    }

                    // Tags (hidden when locked)
                    if !locked && !card.tagList.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(card.tagList.prefix(3), id: \.self) { tag in
                                TagChip(label: tag)
                            }
                        }
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.inkMuted.opacity(0.4))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.cardSurface)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.borderMuted.opacity(0.5), lineWidth: 0.6)
            )
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty tray
    private func emptyTrayPlaceholder(tint: DrawerTint) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "tray")
                .font(.system(size: 26))
                .foregroundColor(tint.tab.opacity(0.35))
            Text("Empty")
                .font(.system(size: 12, design: .serif))
                .italic()
                .foregroundColor(.inkMuted.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Helpers
    private func toggleDrawer(_ label: String) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.72)) {
            openGroup = (openGroup == label) ? nil : label
        }
    }

    private func shortDate(_ date: Date?) -> String {
        guard let d = date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: d)
    }

    private func formatDur(_ secs: Double) -> String {
        let i = Int(secs)
        return String(format: "%d:%02d", i / 60, i % 60)
    }
}