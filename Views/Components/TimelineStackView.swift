import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: TimelineStackView  —  Filing-cabinet dividers with physical card stacks
// MARK: ─────────────────────────────────────────────────────────────────────
struct TimelineStackView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var selectedCard: CardEntity?
    var showLockIndicator: Bool = false

    @State private var expandedLabel: String? = nil
    @State private var pileLifted: String?    = nil

    // Time navigation — 0 = current; negative = past (matches Bookshelf)
    @State private var dailyWeekOffset: Int  = 0
    @State private var weeklyPageOffset: Int = 0
    @State private var yearOffset: Int       = 0

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                periodPicker
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)

                inboxPlate
                    .padding(.horizontal, 16)
                    .padding(.top, 0)
                    .padding(.bottom, 28)

                if windowedGroups.allSatisfy({ $0.cards.isEmpty }) {
                    emptyState
                } else {
                    VStack(spacing: 20) {
                        ForEach(Array(windowedGroups.enumerated()), id: \.element.label) { idx, group in
                            CardPileGroup(
                                label:         group.label,
                                cards:         group.cards,
                                groupIndex:    idx,
                                isExpanded:    expandedLabel == group.label,
                                isLifted:      pileLifted == group.label,
                                contentLocked: showLockIndicator && !vm.isPrivateUnlocked,
                                selectedCard:  $selectedCard,
                                onTap:    { tapPile(label: group.label) },
                                onDelete: { vm.deleteCard($0); vm.reloadCards() },
                                onStar:   { vm.toggleStar($0);  vm.reloadCards() }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .opacity
                            ))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 80)
                }
            }
        }
    }

    // MARK: - Inbox brass plate
    private var inboxPlate: some View {
        HStack(alignment: .center, spacing: 14) {
            // Brass "IN" badge
            ZStack {
                RoundedRectangle(cornerRadius: 5)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#E8C060"), location: 0),
                            .init(color: Color(hex: "#C49030"), location: 0.45),
                            .init(color: Color(hex: "#B07820"), location: 0.7),
                            .init(color: Color(hex: "#D4A848"), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.28), radius: 4, x: 0, y: 2)
                // Specular highlight
                VStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white.opacity(0.20)).frame(height: 1)
                    Spacer()
                }
                Text("IN")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .tracking(4)
                    .foregroundColor(Color(hex: "#3A2008").opacity(0.75))
            }
            .frame(width: 52, height: 26)

            VStack(alignment: .leading, spacing: 1) {
                Text("Stack")
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundColor(.inkPrimary)
                Text("\(vm.cards.count) \(vm.cards.count == 1 ? "note" : "notes")")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.inkMuted)
            }

            Spacer()

            // Voice / text split
            let voiceCount = vm.cards.filter { $0.isVoice }.count
            let textCount  = vm.cards.count - voiceCount
            HStack(spacing: 6) {
                if voiceCount > 0 { typePill("waveform",      "\(voiceCount)", Color(hex: "#C49245")) }
                if textCount  > 0 { typePill("doc.text.fill", "\(textCount)",  Color(hex: "#70675E")) }

                // Lock/unlock indicator
                if showLockIndicator {
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
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#F5EDD8"))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#D4BC90").opacity(0.7), lineWidth: 0.9))
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        )
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

    private func typePill(_ icon: String, _ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 10))
            Text(label).font(.system(size: 11, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.22), lineWidth: 0.6))
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 24) {
            ZStack {
                // Tray illustration
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "#D4BC90").opacity(0.18))
                    .frame(width: 90, height: 70)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#C4A870").opacity(0.35), lineWidth: 1))
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(hex: "#D4BC90").opacity(0.12))
                    .frame(width: 80, height: 60)
                    .offset(y: -5)
                Image(systemName: "tray")
                    .font(.system(size: 30, weight: .thin))
                    .foregroundColor(Color(hex: "#C49245").opacity(0.5))
                    .offset(y: -3)
            }
            VStack(spacing: 8) {
                Text("The tray is empty")
                    .font(.system(.headline, design: .serif).weight(.semibold))
                    .foregroundColor(.inkPrimary)
                Text("Tap Record to drop your first note in.")
                    .font(.system(.callout, design: .serif))
                    .foregroundColor(.inkMuted)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 72).padding(.horizontal, 40)
    }

    // MARK: - Interactions
    private func tapPile(label: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) { pileLifted = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                pileLifted = nil
                expandedLabel = expandedLabel == label ? nil : label
            }
        }
    }

    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: CardPileGroup — File divider tab + physical card stack
// MARK: ─────────────────────────────────────────────────────────────────────
private struct CardPileGroup: View {
    let label:         String
    let cards:         [CardEntity]
    let groupIndex:    Int
    let isExpanded:    Bool
    let isLifted:      Bool
    let contentLocked: Bool
    @Binding var selectedCard: CardEntity?
    let onTap:    () -> Void
    let onDelete: (CardEntity) -> Void
    let onStar:   (CardEntity) -> Void

    // Divider tab accent colours per group
    private var tabColor: Color {
        let palette: [Color] = [
            Color(hex: "#6B2020"),  // Today     – deep crimson
            Color(hex: "#2C4A30"),  // Yesterday – forest
            Color(hex: "#1E3050"),  // This Week – navy
            Color(hex: "#5C3A10"),  // Earlier   – walnut
        ]
        return palette[groupIndex % palette.count]
    }

    private var visibleDepth: Int { min(cards.count - 1, 3) }

    private var topDate: String {
        guard let d = cards.first?.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }

    private func wobble(_ depth: Int) -> Double {
        let s = (label.hashValue &+ depth &* 31) % 100
        return Double(s % 9 - 4) * 0.45
    }
    private func hShift(_ depth: Int) -> CGFloat {
        let s = (label.hashValue &+ depth &* 17) % 100
        return CGFloat(s % 11 - 5) * 0.5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // ── File divider tab + card pile ──────────────────────────────
            ZStack(alignment: .topLeading) {

                // Ghost depth cards (sit behind the top card)
                if !isExpanded {
                    ForEach((1...max(1, visibleDepth)).reversed(), id: \.self) { depth in
                        ghostCard(depth: depth)
                            .padding(.top, 36) // sit below the tab
                    }
                }

                VStack(spacing: 0) {
                    // File divider tab bar
                    dividerTab

                    // Top card face
                    topCardFace
                        .offset(y: isLifted ? -18 : 0)
                        .shadow(
                            color: .black.opacity(isLifted ? 0.42 : 0.12),
                            radius: isLifted ? 18 : 7,
                            x: 0, y: isLifted ? -4 : 4
                        )
                        .animation(.spring(response: 0.26, dampingFraction: 0.56), value: isLifted)
                        .onTapGesture(perform: onTap)
                        .zIndex(10)
                }
            }
            // Extra bottom space for ghost cards to peek out
            .padding(.bottom, isExpanded ? 0 : CGFloat(visibleDepth) * 5 + 4)

            // ── Dealt individual cards ────────────────────────────────────
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.objectID) { idx, card in
                        DealtCardRow(
                            card:     card,
                            index:    idx,
                            accentColor: tabColor,
                            isLocked: contentLocked,
                            onSelect: { selectedCard = card },
                            onDelete: { onDelete(card) },
                            onStar:   { onStar(card) }
                        )
                    }
                }
                .padding(.top, 6)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal:   .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
    }

    // MARK: File divider tab bar
    private var dividerTab: some View {
        HStack(spacing: 0) {
            // Raised label tab on the left
            ZStack {
                tabColor
                    .cornerRadius(5, corners: [.topLeft, .topRight])
                // Specular edge
                HStack {
                    Spacer()
                    Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1)
                }
                .cornerRadius(5, corners: [.topLeft, .topRight])

                Text(label.uppercased())
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundColor(.white.opacity(0.90))
                    .padding(.horizontal, 12)
            }
            .frame(width: 110, height: 30)

            // Flat divider line continuing right
            Rectangle()
                .fill(tabColor.opacity(0.65))
                .frame(height: 30)
                .overlay(
                    VStack {
                        Spacer()
                        Rectangle().fill(Color.black.opacity(0.10)).frame(height: 1)
                    }
                )

            // Count badge on far right
            HStack(spacing: 4) {
                Text("\(cards.count)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                Image(systemName: "square.stack.fill")
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.60))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(tabColor.opacity(0.80))
        }
        .clipShape(
            RoundedRectangle(cornerRadius: 0)
        )
    }

    // MARK: Top card face
    private var topCardFace: some View {
        ZStack(alignment: .leading) {
            // Paper surface
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#FAF4E4"), location: 0),
                        .init(color: Color(hex: "#F2E9D2"), location: 0.55),
                        .init(color: Color(hex: "#EBE0C8"), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))

            // Border
            Rectangle()
                .stroke(Color(hex: "#D0BA90").opacity(0.45), lineWidth: 0.8)

            // Faint ruling lines
            VStack(spacing: 0) {
                Spacer()
                ForEach(0..<5, id: \.self) { i in
                    Rectangle()
                        .fill(Color(hex: "#2A2010").opacity(i == 0 ? 0.07 : 0.03))
                        .frame(height: i == 0 ? 0.7 : 0.4)
                    if i < 4 { Spacer() }
                }
                Spacer().frame(height: 10)
            }
            .padding(.horizontal, 18).cornerRadius(0)

            // Content
            HStack(alignment: .center, spacing: 14) {
                // Bold period label
                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: "#1C1812"))

                    HStack(spacing: 10) {
                        if !topDate.isEmpty {
                            Text(topDate)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Color(hex: "#70675E").opacity(0.7))
                        }
                        // Voice / text split within pile
                        let vCount = cards.filter { $0.isVoice }.count
                        if vCount > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "waveform").font(.system(size: 8))
                                Text("\(vCount)").font(.system(size: 9, design: .monospaced))
                            }
                            .foregroundColor(Color(hex: "#C49245").opacity(0.8))
                        }
                    }
                }

                Spacer()

                // Expand chevron + depth dots
                VStack(spacing: 5) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(tabColor.opacity(0.55))
                        .animation(.spring(response: 0.28), value: isExpanded)

                    if !isExpanded && visibleDepth > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(visibleDepth, 3), id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(tabColor.opacity(0.35))
                                    .frame(width: 10, height: 3)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
        }
        .frame(height: 82)
    }

    // MARK: Ghost card
    private func ghostCard(depth: Int) -> some View {
        let lightness = 1.0 - Double(depth) * 0.06
        return ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 0)
                .fill(Color(hex: "#EDE4CC").opacity(lightness * 0.95))
            Rectangle()
                .stroke(Color(hex: "#C4B090").opacity(0.35), lineWidth: 0.7)
            VStack {
                Spacer().frame(height: 10)
                Rectangle()
                    .fill(tabColor.opacity(0.12))
                    .frame(height: 0.7)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, CGFloat(depth) * 4)
        .frame(height: 82)
        .rotationEffect(.degrees(wobble(depth)), anchor: .bottom)
        .offset(x: hShift(depth), y: CGFloat(depth) * 5)
        .opacity(0.90 - Double(depth) * 0.22)
        .shadow(color: .black.opacity(0.07 + Double(depth) * 0.04), radius: 3, x: 0, y: 2)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: DealtCardRow — Physical index card dealt from the pile
// MARK: ─────────────────────────────────────────────────────────────────────
private struct DealtCardRow: View {
    let card:        CardEntity
    let index:       Int
    let accentColor: Color
    let isLocked:    Bool
    let onSelect:    () -> Void
    let onDelete:    () -> Void
    let onStar:      () -> Void

    @State private var appeared = false

    private var dateStr: String {
        guard let d = card.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return f.string(from: d)
    }
    private var timeStr: String {
        guard let d = card.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "h:mm a"
        return f.string(from: d)
    }
    private var durStr: String {
        let s = Int(card.durationSec)
        return String(format: "%d:%02d", s / 60, s % 60)
    }

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect()
        } label: {
            ZStack(alignment: .leading) {
                // Card — warm index card paper
                Rectangle()
                    .fill(LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#FAF4E6"), location: 0),
                            .init(color: Color(hex: "#F3EBD4"), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .shadow(color: .black.opacity(0.07), radius: 5, x: 0, y: 2)

                // Card border
                Rectangle()
                    .stroke(Color(hex: "#D8C4A0").opacity(0.55), lineWidth: 0.7)

                // Ruling lines
                VStack(spacing: 0) {
                    // Red header line (classic index card style)
                    Rectangle()
                        .fill(accentColor.opacity(0.55))
                        .frame(height: 1.2)
                    Spacer()
                    // Bottom blue ruling lines
                    ForEach(0..<3, id: \.self) { _ in
                        Rectangle()
                            .fill(Color(hex: "#2A50A8").opacity(0.06))
                            .frame(height: 0.5)
                        Spacer()
                    }
                    Spacer().frame(height: 8)
                }
                .padding(.horizontal, 0).cornerRadius(0)

                // Content
                HStack(spacing: 14) {
                    // Type icon — square badge
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(card.isVoice
                                  ? accentColor.opacity(0.12)
                                  : Color(hex: "#2A2010").opacity(0.07))
                            .frame(width: 44, height: 44)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(card.isVoice ? accentColor.opacity(0.20) : Color.clear, lineWidth: 0.7))
                        Image(systemName: card.isVoice ? "waveform" : "doc.text.fill")
                            .font(.system(size: 16))
                            .foregroundColor(card.isVoice ? accentColor : Color(hex: "#70675E"))
                    }

                    // Text area
                    VStack(alignment: .leading, spacing: 5) {
                        Text(isLocked ? "••••••••••" : (card.title ?? "Untitled"))
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundColor(Color(hex: "#1C1812"))
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            if card.isVoice {
                                HStack(spacing: 4) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 11))
                                    Text(isLocked ? "••:••" : durStr)
                                        .font(.system(size: 11, design: .monospaced))
                                }
                                .foregroundColor(accentColor.opacity(0.85))
                            } else if isLocked {
                                Text("••••••••••••••")
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundColor(Color(hex: "#70675E").opacity(0.85))
                                    .lineLimit(1)
                            } else if let snippet = card.snippet, !snippet.isEmpty {
                                Text(snippet)
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundColor(Color(hex: "#70675E").opacity(0.85))
                                    .lineLimit(1)
                            }

                            if !card.tagList.isEmpty {
                                ForEach(card.tagList.prefix(1), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundColor(accentColor.opacity(0.7))
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(accentColor.opacity(0.08))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Spacer()

                    // Right: date/time + star
                    VStack(alignment: .trailing, spacing: 4) {
                        if card.starred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "#C49245"))
                        }
                        Text(dateStr)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#70675E").opacity(0.7))
                        Text(timeStr)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#70675E").opacity(0.45))
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(accentColor.opacity(0.25))
                }
                .padding(.leading, 16).padding(.trailing, 14).padding(.vertical, 17)
            }
            .offset(y: appeared ? 0 : -8)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) { Label("Delete", systemImage: "trash") }
            Button(action: onStar) {
                Label(card.starred ? "Unstar" : "Star",
                      systemImage: card.starred ? "star.slash" : "star")
            }.tint(Color(hex: "#C49245"))
        }
        .padding(.bottom, 8)
        .onAppear {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.72)
                .delay(Double(index) * 0.05)) { appeared = true }
        }
        .onDisappear { appeared = false }
    }
}

// MARK: - RoundedCorner helper
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

private struct RoundedCornerShape: Shape {
    var radius: CGFloat
    var corners: UIRectCorner
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect, byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}