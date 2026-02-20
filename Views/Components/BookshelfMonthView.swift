import SwiftUI

// MARK: - ShelfBook model
private struct ShelfBook: Identifiable, Equatable {
    let id: String
    let label: String
    let shortLabel: String
    let subLabel: String
    let cards: [CardEntity]
    let spineWidth: CGFloat
    let spineHeight: CGFloat
    let spineColor: SpineColor
    let hasDecorativeCross: Bool
    let rulingCount: Int
    let tiltDeg: Double
    let isEmpty: Bool

    static func == (lhs: ShelfBook, rhs: ShelfBook) -> Bool { lhs.id == rhs.id }
}

// Rich vintage library color palette — each book looks genuinely distinct
private struct SpineColor {
    let base: Color          // main spine color
    let dark: Color          // shadow side / binding edge
    let light: Color         // highlight side
    let textColor: Color     // title text (light on dark, dark on light)
    let accentLine: Color    // decorative lines

    static let palette: [SpineColor] = [
        // Deep burgundy
        SpineColor(base:  Color(hex: "#7A1F2E"), dark:  Color(hex: "#4E1020"),
                   light: Color(hex: "#9C3040"), textColor: Color(hex: "#F0E0C8"),
                   accentLine: Color(hex: "#C49245")),
        // Aged navy
        SpineColor(base:  Color(hex: "#1E2D50"), dark:  Color(hex: "#111C36"),
                   light: Color(hex: "#2A3E6A"), textColor: Color(hex: "#E8D8B8"),
                   accentLine: Color(hex: "#B09060")),
        // Forest green
        SpineColor(base:  Color(hex: "#2A4A2C"), dark:  Color(hex: "#182E1A"),
                   light: Color(hex: "#3A5E3C"), textColor: Color(hex: "#E0EACC"),
                   accentLine: Color(hex: "#A08840")),
        // Warm parchment / vellum (light book)
        SpineColor(base:  Color(hex: "#E8DEC8"), dark:  Color(hex: "#C8B898"),
                   light: Color(hex: "#F4EEE0"), textColor: Color(hex: "#2A2010"),
                   accentLine: Color(hex: "#8B6A38")),
        // Deep plum
        SpineColor(base:  Color(hex: "#4A1E40"), dark:  Color(hex: "#2E1028"),
                   light: Color(hex: "#622A58"), textColor: Color(hex: "#EED8D8"),
                   accentLine: Color(hex: "#C49245")),
        // Terracotta / brick
        SpineColor(base:  Color(hex: "#924028"), dark:  Color(hex: "#5E2818"),
                   light: Color(hex: "#B45030"), textColor: Color(hex: "#F8E8D8"),
                   accentLine: Color(hex: "#D4A060")),
        // Deep teal
        SpineColor(base:  Color(hex: "#1A4444"), dark:  Color(hex: "#0E2C2C"),
                   light: Color(hex: "#245858"), textColor: Color(hex: "#D8F0E8"),
                   accentLine: Color(hex: "#98C070")),
        // Warm ochre / mustard
        SpineColor(base:  Color(hex: "#9A7020"), dark:  Color(hex: "#6A4C14"),
                   light: Color(hex: "#B88C28"), textColor: Color(hex: "#2A2010"),
                   accentLine: Color(hex: "#2A2010")),
        // Slate blue
        SpineColor(base:  Color(hex: "#354A68"), dark:  Color(hex: "#1E3050"),
                   light: Color(hex: "#465E80"), textColor: Color(hex: "#D8E4F0"),
                   accentLine: Color(hex: "#A8C0D8")),
        // Faded rose
        SpineColor(base:  Color(hex: "#8C3A48"), dark:  Color(hex: "#5C2030"),
                   light: Color(hex: "#A84C5A"), textColor: Color(hex: "#F8E8EC"),
                   accentLine: Color(hex: "#E0A880")),
        // Dark olive
        SpineColor(base:  Color(hex: "#4A4A1C"), dark:  Color(hex: "#2E2E10"),
                   light: Color(hex: "#606028"), textColor: Color(hex: "#E8EAD0"),
                   accentLine: Color(hex: "#C0A840")),
        // Warm ivory (light book)
        SpineColor(base:  Color(hex: "#D8CEB8"), dark:  Color(hex: "#B8A898"),
                   light: Color(hex: "#EAE4D4"), textColor: Color(hex: "#2A2010"),
                   accentLine: Color(hex: "#8B6A38")),
    ]
}

// MARK: - Animation phase
private enum OpenPhase { case idle, lifting, opening, presented }

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: BookshelfMonthView ★
// MARK: ─────────────────────────────────────────────────────────────────────
struct BookshelfMonthView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var selectedCard: CardEntity?
    var showLockIndicator: Bool = false

    @State private var liftedId: String?       = nil
    @State private var coverFlip: Double       = 0
    @State private var openBook: ShelfBook?    = nil
    @State private var openPhase: OpenPhase    = .idle

    // Navigation offsets — 0 = current period, negative = past
    @State private var dailyWeekOffset: Int  = 0   // how many weeks back for daily view
    @State private var weeklyPageOffset: Int = 0   // how many batches of 12 weeks back
    @State private var yearOffset: Int       = 0   // how many years back for monthly view

    // Slimmer books at 6 per row to fill the shelf naturally
    private let spineWidths:  [CGFloat] = [46, 52, 44, 50, 48, 46, 52, 44, 50, 48, 46, 52]
    private let spineHeights: [CGFloat] = [180, 168, 192, 162, 196, 174, 184, 166, 188, 170, 182, 164]
    private let tilts:        [Double]  = [0.0, 0.3, -0.2, 0.4, 0.0, -0.3, 0.2, -0.4, 0.1, 0.5, -0.1, 0.3]

    // MARK: Book data per period
    private var books: [ShelfBook] {
        switch vm.bookshelfPeriod {
        case .monthly: return monthlyBooks
        case .weekly:  return weeklyBooks
        case .daily:   return dailyBooks
        }
    }

    private var monthlyBooks: [ShelfBook] {
        let cal  = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let year = currentYear + yearOffset
        let mFmt = DateFormatter(); mFmt.dateFormat = "MMMM yyyy"
        let existing = Dictionary(uniqueKeysWithValues: vm.groupedByMonth.map { ($0.label, $0.cards) })
        return (1...12).map { month in
            var c = DateComponents(); c.year = year; c.month = month; c.day = 1
            let date  = cal.date(from: c) ?? Date()
            let label = mFmt.string(from: date)
            let cards = existing[label] ?? []
            let nFmt  = DateFormatter(); nFmt.dateFormat = "MMMM"
            let name  = nFmt.string(from: date)
            let idx   = month - 1
            return makeBook(id: label, label: name,
                            short: String(name.prefix(3)).uppercased(),
                            sub: "\(year)", cards: cards, idx: idx)
        }
    }

    private var weeklyBooks: [ShelfBook] {
        let cal  = Calendar.current
        let fmt  = DateFormatter(); fmt.dateFormat = "MMM d"
        let existing = Dictionary(uniqueKeysWithValues: vm.groupedForBookshelf.map { ($0.label, $0.cards) })
        var starts: [Date] = []
        // Each "page" is 12 weeks; weeklyPageOffset shifts back by 12-week batches
        let baseWeek = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        var cur = cal.date(byAdding: .weekOfYear, value: weeklyPageOffset * 12, to: baseWeek) ?? baseWeek
        for _ in 0..<12 {
            starts.append(cur)
            cur = cal.date(byAdding: .weekOfYear, value: -1, to: cur) ?? cur
        }
        return starts.enumerated().map { idx, start in
            let end   = cal.date(byAdding: .day, value: 6, to: start) ?? start
            let label = "\(fmt.string(from: start))–\(fmt.string(from: end))"
            let short = fmt.string(from: start).uppercased()
            let cards = existing[label] ?? []
            return makeBook(id: label, label: label, short: short,
                            sub: fmt.string(from: end), cards: cards, idx: idx)
        }
    }

    private var dailyBooks: [ShelfBook] {
        let cal      = Calendar.current
        let fmt      = DateFormatter(); fmt.dateFormat = "MMM d"
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let shorts   = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
        let existing = Dictionary(uniqueKeysWithValues: vm.groupedForBookshelf.map { ($0.label, $0.cards) })
        var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        c.weekday = 2
        let thisMonday = cal.date(from: c) ?? Date()
        // Shift by dailyWeekOffset weeks (0 = this week, -1 = last week, etc.)
        let monday = cal.date(byAdding: .weekOfYear, value: dailyWeekOffset, to: thisMonday) ?? thisMonday
        return (0..<7).map { offset in
            let day   = cal.date(byAdding: .day, value: offset, to: monday) ?? monday
            let sub   = fmt.string(from: day)
            let cards = existing[sub] ?? []
            return makeBook(id: "day-\(dailyWeekOffset)-\(offset)", label: dayNames[offset],
                            short: shorts[offset], sub: sub, cards: cards, idx: offset)
        }
    }

    private func makeBook(id: String, label: String, short: String,
                          sub: String, cards: [CardEntity], idx: Int) -> ShelfBook {
        let h = min(spineHeights[idx % spineHeights.count],
                    max(112, CGFloat(cards.count) * 5 + 112))
        return ShelfBook(
            id: id, label: label, shortLabel: short, subLabel: sub,
            cards: cards,
            spineWidth:  spineWidths[idx % spineWidths.count],
            spineHeight: h,
            spineColor:  SpineColor.palette[idx % SpineColor.palette.count],
            hasDecorativeCross: idx % 3 != 0,
            rulingCount: [3, 5, 4, 6, 3, 4, 5, 3][idx % 8],
            tiltDeg: tilts[idx % tilts.count],
            isEmpty: cards.isEmpty
        )
    }

    private var bookRows: [[ShelfBook]] {
        let all = books
        switch vm.bookshelfPeriod {
        case .daily:
            // 7 books → row of 4, row of 3
            var rows: [[ShelfBook]] = []
            if all.count > 0 { rows.append(Array(all.prefix(4))) }
            if all.count > 4 { rows.append(Array(all.dropFirst(4))) }
            return rows
        case .weekly:
            // 12 books → row of 6, row of 6
            return stride(from: 0, to: all.count, by: 6).map { Array(all[$0..<min($0 + 6, all.count)]) }
        case .monthly:
            // 12 books → row of 6, row of 6
            return stride(from: 0, to: all.count, by: 6).map { Array(all[$0..<min($0 + 6, all.count)]) }
        }
    }

    // MARK: Body
    var body: some View {
        ZStack(alignment: .top) {
            Color.paperBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                periodPicker
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        bookcaseUnit
                        hintStrip
                        Spacer(minLength: 50)
                    }
                }
            }
        }
        // fullScreenCover so the open book fills the ENTIRE screen correctly
        .fullScreenCover(item: $openBook, onDismiss: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                liftedId  = nil
                coverFlip = 0
                openPhase = .idle
            }
        }) { book in
            OpenBookModal(
                book:               book,
                showLockIndicator:  showLockIndicator,
                isPrivateUnlocked:  vm.isPrivateUnlocked,
                onCardSelect: { card in selectedCard = card; openBook = nil },
                onClose:      { openBook = nil }
            )
        }
    }

    // MARK: Period picker + time navigation
    private var periodPicker: some View {
        VStack(spacing: 0) {
            // Row 1: mode tabs
            HStack(spacing: 0) {
                let orderedPeriods: [BookshelfPeriod] = [.daily, .weekly, .monthly]
                ForEach(orderedPeriods, id: \.self) { period in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { vm.bookshelfPeriod = period }
                    } label: {
                        Text(period.rawValue)
                            .font(.cardCaption)
                            .fontWeight(vm.bookshelfPeriod == period ? .semibold : .regular)
                            .foregroundColor(vm.bookshelfPeriod == period ? .accentGold : .inkMuted)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(vm.bookshelfPeriod == period ? Color.accentGold.opacity(0.12) : Color.clear)
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 4)

            // Row 2: time navigation (back / label / forward)
            HStack(spacing: 12) {
                // ← Back
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

                // Period label
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

                // → Forward (disabled at current/future)
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
            .padding(.horizontal, 16).padding(.bottom, 10)

            Divider()
        }
        .background(Color.paperBackground)
    }

    /// Human-readable title for the current time window
    private var periodNavigationTitle: String {
        let cal = Calendar.current
        let fmt = DateFormatter()
        switch vm.bookshelfPeriod {
        case .daily:
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            c.weekday = 2
            let monday = cal.date(from: c).flatMap { cal.date(byAdding: .weekOfYear, value: dailyWeekOffset, to: $0) } ?? Date()
            let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
            fmt.dateFormat = "MMM d"
            if dailyWeekOffset == 0 { return "This Week" }
            if dailyWeekOffset == -1 { return "Last Week" }
            return "\(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
        case .weekly:
            if weeklyPageOffset == 0 { return "Recent 12 Weeks" }
            let weeksBack = abs(weeklyPageOffset) * 12
            return "\(weeksBack)–\(weeksBack + 11) Weeks Ago"
        case .monthly:
            let year = cal.component(.year, from: Date()) + yearOffset
            if yearOffset == 0 { return "This Year" }
            if yearOffset == -1 { return "Last Year" }
            return "\(year)"
        }
    }

    private var periodNavigationSubtitle: String {
        let cal = Calendar.current
        switch vm.bookshelfPeriod {
        case .daily:
            var c = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            c.weekday = 2
            let monday = cal.date(from: c).flatMap { cal.date(byAdding: .weekOfYear, value: dailyWeekOffset, to: $0) } ?? Date()
            let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
            let fmt = DateFormatter(); fmt.dateFormat = "MMM d"
            if dailyWeekOffset == 0 {
                fmt.dateFormat = "MMM d"
                return "\(fmt.string(from: monday)) – \(fmt.string(from: sunday))"
            }
            return "Mon – Sun"
        case .weekly:
            let base = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
            let newest = cal.date(byAdding: .weekOfYear, value: weeklyPageOffset * 12, to: base) ?? base
            let oldest = cal.date(byAdding: .weekOfYear, value: weeklyPageOffset * 12 - 11, to: base) ?? base
            let fmt = DateFormatter(); fmt.dateFormat = "MMM d, yyyy"
            return "\(fmt.string(from: oldest)) – \(fmt.string(from: newest))"
        case .monthly:
            let year = cal.component(.year, from: Date()) + yearOffset
            return "Jan – Dec \(year)"
        }
    }

    // MARK: Bookcase
    private var bookcaseUnit: some View {
        ZStack(alignment: .top) {
            bookcaseBackWall
            VStack(spacing: 0) {
                ForEach(Array(bookRows.enumerated()), id: \.offset) { rowIdx, row in
                    shelfRow(books: row)
                }
            }
            .padding(.leading, 2)
            .padding(.trailing, 10)
            .padding(.vertical, 16)
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(Color(hex: "#2C2416"), lineWidth: 3)
        )
        .shadow(color: Color(hex: "#1C1812").opacity(0.55), radius: 14, x: 0, y: 8)
    }

    private func shelfRow(books: [ShelfBook]) -> some View {
        let rowH = books.map { $0.spineHeight }.max().map { $0 + 40 } ?? 210
        return GeometryReader { geo in
            let totalW    = geo.size.width
            let wallW: CGFloat = 10
            let gap: CGFloat   = 3
            let gapCount  = max(1, books.count - 1)
            let availableW = totalW - wallW * 2 - CGFloat(gapCount) * gap - 4
            let computedW  = max(36, availableW / CGFloat(max(1, books.count)))

            ZStack(alignment: .bottom) {
                Color.clear.frame(height: rowH + 20)
                HStack(alignment: .bottom, spacing: gap) {
                    sideWall(h: rowH)
                    ForEach(books) { book in
                        BookSpineView(
                            book:          book,
                            isLifted:      liftedId == book.id,
                            flipAngle:     liftedId == book.id ? coverFlip : 0,
                            overrideWidth: computedW
                        )
                        .onTapGesture {
                            guard !book.isEmpty else { return }
                            animateOpen(book)
                        }
                    }
                    sideWall(h: rowH)
                }
                .padding(.leading, 0)   // flush left — wall sits at edge
                .padding(.trailing, 0)
                .padding(.top, 18)
                .frame(maxWidth: .infinity, minHeight: rowH, alignment: .bottom)
                shelfPlank
            }
        }
        .frame(height: rowH + 38)
    }

    private var bookcaseBackWall: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#1C150D"), location: 0),
                    .init(color: Color(hex: "#221A10"), location: 0.5),
                    .init(color: Color(hex: "#1A1208"), location: 1),
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            VStack(spacing: 0) {
                ForEach(0..<30, id: \.self) { i in
                    Spacer()
                    Rectangle().fill(Color.white.opacity(i % 4 == 0 ? 0.012 : 0.005)).frame(height: 0.6)
                }
                Spacer()
            }
            VStack { Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1.5); Spacer() }
            Rectangle().stroke(Color(hex: "#0E0A06"), lineWidth: 2)
        }
    }

    private var shelfPlank: some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#A07848"), location: 0),
                        .init(color: Color(hex: "#8B6438"), location: 0.3),
                        .init(color: Color(hex: "#7A5830"), location: 0.7),
                        .init(color: Color(hex: "#5C4020"), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                ))
            HStack(spacing: 22) {
                ForEach(0..<20, id: \.self) { i in
                    Rectangle().fill(Color.black.opacity(i % 3 == 0 ? 0.055 : 0.02)).frame(width: 1)
                }
            }
            VStack {
                Rectangle().fill(Color.white.opacity(0.22)).frame(height: 2)
                Spacer()
                Rectangle().fill(Color.black.opacity(0.40)).frame(height: 3)
            }
        }
        .frame(height: 20)
    }

    private func sideWall(h: CGFloat) -> some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "#8B6A3A"), Color(hex: "#6B4E28"), Color(hex: "#5A4020")],
                startPoint: .leading, endPoint: .trailing
            )
            HStack { Rectangle().fill(Color.white.opacity(0.12)).frame(width: 1.5); Spacer() }
        }
        .frame(width: 12, height: h)
    }

    private var hintStrip: some View {
        HStack(spacing: 7) {
            Image(systemName: "hand.point.up.left.fill").font(.system(size: 11))
                .foregroundColor(Color.accentGold.opacity(0.6))
            Text("Tap a volume to open its entries")
                .font(.system(size: 12, design: .serif)).italic()
                .foregroundColor(Color.inkMuted.opacity(0.75))
        }
        .padding(.top, 18).frame(maxWidth: .infinity)
    }

    // MARK: Lift + open animation
    private func animateOpen(_ book: ShelfBook) {
        guard openPhase == .idle else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        openPhase = .lifting

        withAnimation(.spring(response: 0.24, dampingFraction: 0.52)) { liftedId = book.id }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            openPhase = .opening
            withAnimation(.easeIn(duration: 0.16)) { coverFlip = 80 }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
            openPhase = .presented
            openBook = book
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: BookSpineView
// MARK: ─────────────────────────────────────────────────────────────────────
private struct BookSpineView: View {
    let book: ShelfBook
    let isLifted: Bool
    let flipAngle: Double
    var overrideWidth: CGFloat? = nil

    private var c: SpineColor { book.spineColor }
    private var effectiveWidth: CGFloat { overrideWidth ?? book.spineWidth }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page-edge depth layers (show paper pages from the side)
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: "#C8C0A8").opacity(book.isEmpty ? 0.25 : (0.80 - Double(i) * 0.12)))
                    .frame(width: effectiveWidth,
                           height: book.spineHeight - CGFloat(i) * 2.2)
                    .offset(x: CGFloat(i + 1) * 1.1, y: CGFloat(i + 1) * 0.8)
            }
            // Main spine face
            spineBody
                .frame(width: effectiveWidth, height: book.spineHeight)
                .opacity(book.isEmpty ? 0.30 : 1.0)
                .rotation3DEffect(
                    .degrees(flipAngle),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: .leading,
                    perspective: 0.5
                )
        }
        .offset(y: isLifted ? -34 : 0)
        .rotation3DEffect(
            .degrees(isLifted ? -3 : book.tiltDeg),
            axis: (x: 0, y: 0, z: 1),
            anchor: .bottom,
            perspective: 0.3
        )
        .shadow(
            color: Color.black.opacity(book.isEmpty ? 0.08 : (isLifted ? 0.68 : 0.30)),
            radius: isLifted ? 20 : 5,
            x: isLifted ? -7 : -1.5,
            y: isLifted ? -10 : 2
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.60), value: isLifted)
    }

    private var spineBody: some View {
        ZStack {
            // Base color gradient (slightly lighter on right edge)
            RoundedRectangle(cornerRadius: 2)
                .fill(LinearGradient(
                    stops: [
                        .init(color: c.dark.opacity(book.isEmpty ? 0.55 : 0.9), location: 0),
                        .init(color: c.base.opacity(book.isEmpty ? 0.50 : 1.0), location: 0.15),
                        .init(color: c.base.opacity(book.isEmpty ? 0.48 : 0.96), location: 0.85),
                        .init(color: c.light.opacity(book.isEmpty ? 0.45 : 0.85), location: 1.0),
                    ],
                    startPoint: .leading, endPoint: .trailing
                ))

            // Left binding shadow (deep edge where spine meets covers)
            HStack {
                LinearGradient(
                    colors: [c.dark.opacity(0.60), c.dark.opacity(0.20), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                ).frame(width: 9)
                Spacer()
            }.cornerRadius(2)

            // Cloth/linen texture horizontal lines
            VStack(spacing: 0) {
                ForEach(0..<book.rulingCount, id: \.self) { _ in
                    Spacer()
                    Rectangle()
                        .fill(c.textColor.opacity(book.isEmpty ? 0.04 : 0.08))
                        .frame(height: 0.5)
                }
                Spacer()
            }.padding(.horizontal, 3).cornerRadius(2)

            // Right edge specular highlight
            HStack {
                Spacer()
                LinearGradient(
                    colors: [Color.white.opacity(0.12), Color.white.opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing
                ).frame(width: 3)
            }.cornerRadius(2)

            // Border
            RoundedRectangle(cornerRadius: 2).stroke(c.dark.opacity(0.35), lineWidth: 0.5)

            // Typography
            spineLabels.opacity(book.isEmpty ? 0.40 : 1.0)
        }
    }

    private var spineLabels: some View {
        VStack(spacing: 0) {
            // Top cap decorative band
            VStack(spacing: 1.5) {
                Rectangle().fill(c.accentLine.opacity(0.70)).frame(height: 1.5)
                Rectangle().fill(c.accentLine.opacity(0.30)).frame(height: 0.7)
            }.padding(.top, 5).padding(.horizontal, 4)

            Spacer(minLength: 4)

            // Short label (e.g. "JAN", "MON")
            Text(book.shortLabel)
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundColor(c.textColor.opacity(0.85))

            Spacer(minLength: 3)

            // Count badge — near top, always visible above the shelf plank
            Group {
                if book.isEmpty {
                    Text("0")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundColor(c.textColor.opacity(0.22))
                        .padding(.horizontal, 4).padding(.vertical, 1.5)
                        .background(c.dark.opacity(0.15))
                        .cornerRadius(3)
                } else {
                    Text("\(book.cards.count)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(c.textColor)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(c.accentLine.opacity(0.55))
                        .cornerRadius(3)
                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(c.accentLine.opacity(0.7), lineWidth: 0.5))
                }
            }

            Spacer(minLength: 4)

            // Accent rule
            Rectangle()
                .fill(c.accentLine.opacity(0.50))
                .frame(width: effectiveWidth * 0.55, height: 0.8)

            Spacer(minLength: 10)

            // Main rotated title
            Text(book.label)
                .font(.system(
                    size: max(11, min(14, effectiveWidth / 3.0)),
                    weight: .semibold,
                    design: .serif
                ))
                .foregroundColor(c.textColor.opacity(0.95))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: book.spineHeight * 0.52, height: effectiveWidth - 8)
                .rotationEffect(.degrees(-90))

            Spacer(minLength: 8)

            // Decorative cross ornament
            if book.hasDecorativeCross {
                ZStack {
                    Rectangle().fill(c.accentLine.opacity(0.50)).frame(width: effectiveWidth * 0.50, height: 0.8)
                    Rectangle().fill(c.accentLine.opacity(0.50)).frame(width: 0.8, height: 10)
                }.padding(.bottom, 4)
            }

            Text(book.subLabel)
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(c.textColor.opacity(0.65))

            Spacer(minLength: 36)

            // Bottom cap band — sits well above the shelf plank
            VStack(spacing: 1.5) {
                Rectangle().fill(c.accentLine.opacity(0.30)).frame(height: 0.7)
                Rectangle().fill(c.accentLine.opacity(0.70)).frame(height: 1.5)
            }.padding(.bottom, 8).padding(.horizontal, 4)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: OpenBookModal — fullScreenCover so both pages are fully visible
// MARK: ─────────────────────────────────────────────────────────────────────
private struct OpenBookModal: View {
    let book: ShelfBook
    let showLockIndicator: Bool
    let isPrivateUnlocked: Bool
    let onCardSelect: (CardEntity) -> Void
    let onClose: () -> Void

    @State private var appeared    = false
    @State private var currentPage = 0
    @State private var pageTurning = false
    @State private var turnForward = true

    private let cardsPerPage = 6
    private var totalPages: Int { max(1, Int(ceil(Double(book.cards.count) / Double(cardsPerPage)))) }
    private func pageCards(_ p: Int) -> [CardEntity] {
        let s = p * cardsPerPage
        let e = min(s + cardsPerPage, book.cards.count)
        guard s < book.cards.count else { return [] }
        return Array(book.cards[s..<e])
    }

    var body: some View {
        GeometryReader { proxy in
            let sw = proxy.size.width
            let sh = proxy.size.height
            // Single book page — takes 88% of width with safe margins
            let bookW = min(sw * 0.92, sw - 24)
            let bookH = min(sh * 0.84, 680.0)

            ZStack {
                ambientBG.ignoresSafeArea()

                // Drop shadow
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.70))
                    .frame(width: bookW + 20, height: bookH + 20)
                    .blur(radius: 28)

                // Single page with left leather binding accent
                singlePage(w: bookW, h: bookH)
                    .rotation3DEffect(
                        .degrees(pageTurning ? (turnForward ? -90 : 90) : 0),
                        axis: (x: 0, y: 1, z: 0),
                        anchor: .leading,
                        perspective: 0.45
                    )
                    .animation(
                        pageTurning ? .easeIn(duration: 0.22) : .easeOut(duration: 0.22),
                        value: pageTurning
                    )
            }
            .frame(width: bookW, height: bookH)
            .scaleEffect(appeared ? 1.0 : 0.80)
            .opacity(appeared ? 1.0 : 0.0)
            .offset(y: appeared ? 0 : 50)
            .animation(.spring(response: 0.42, dampingFraction: 0.75), value: appeared)
            .position(x: sw / 2, y: sh / 2)
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { appeared = true } }
        .gesture(DragGesture(minimumDistance: 44)
            .onEnded { v in
                if v.translation.width < -50      { turnPage(forward: true)  }
                else if v.translation.width > 50  { turnPage(forward: false) }
                else if v.translation.height > 80 { dismissWithAnimation()   }
            }
        )
    }

    private func dismissWithAnimation() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.18)) { appeared = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onClose() }
    }

    // MARK: Ambient background
    private var ambientBG: some View {
        ZStack {
            LinearGradient(
                stops: [
                    .init(color: Color(hex: "#0E0B07"), location: 0),
                    .init(color: Color(hex: "#1A1510"), location: 0.55),
                    .init(color: Color(hex: "#241C12"), location: 1),
                ],
                startPoint: .top, endPoint: .bottom
            )
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color.accentGold.opacity(0.10), Color.clear],
                    center: .center, startRadius: 0, endRadius: 340
                ))
                .frame(width: 640, height: 340)
                .offset(y: 60)
        }
    }

    // MARK: Single page
    private func singlePage(w: CGFloat, h: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // Page background — warm aged paper with slight texture
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#F7F1E3"), location: 0),
                            .init(color: Color(hex: "#F2EAD8"), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // Subtle horizontal ruling lines (like a journal page)
            VStack(spacing: 0) {
                ForEach(0..<30, id: \.self) { i in
                    Spacer()
                    Rectangle()
                        .fill(Color(hex: "#2A2010").opacity(i % 5 == 0 ? 0.07 : 0.035))
                        .frame(height: i % 5 == 0 ? 0.7 : 0.4)
                }
                Spacer()
            }
            .padding(.horizontal, 0)
            .padding(.top, 68) // start lines below header area

            // Left binding shadow stripe
            HStack(spacing: 0) {
                LinearGradient(
                    colors: [Color(hex: "#5C3A1A").opacity(0.60),
                             Color(hex: "#8B6438").opacity(0.20),
                             Color.clear],
                    startPoint: .leading, endPoint: .trailing
                )
                .frame(width: 20)
                Spacer()
            }.cornerRadius(8)

            // Right page curl shadow
            HStack(spacing: 0) {
                Spacer()
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.05)],
                    startPoint: .leading, endPoint: .trailing
                ).frame(width: 8)
            }.cornerRadius(8)

            VStack(spacing: 0) {
                // ── Header ────────────────────────────────────────
                ZStack {
                    // Decorative header background
                    LinearGradient(
                        colors: [Color(hex: "#2A1A08").opacity(0.06), Color.clear],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(height: 64)
                    .cornerRadius(8)

                    HStack(alignment: .center, spacing: 0) {
                        // Close button
                        Button { dismissWithAnimation() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 10, weight: .bold))
                                Text("Close")
                                    .font(.system(size: 11, weight: .semibold, design: .serif))
                            }
                            .foregroundColor(Color(hex: "#7A5528"))
                            .padding(.horizontal, 11).padding(.vertical, 6)
                            .background(Color(hex: "#8B6A38").opacity(0.13))
                            .cornerRadius(14)
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(hex: "#8B6A38").opacity(0.28), lineWidth: 0.8))
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // Centred title block
                        VStack(spacing: 2) {
                            Text(book.shortLabel)
                                .font(.system(size: 8, weight: .black, design: .serif))
                                .tracking(3)
                                .foregroundColor(Color(hex: "#C49245"))
                            Text(book.label)
                                .font(.system(size: 15, weight: .bold, design: .serif))
                                .foregroundColor(Color(hex: "#1C1812"))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Text(book.subLabel)
                                .font(.system(size: 9, design: .serif))
                                .foregroundColor(Color(hex: "#70675E"))
                        }
                        .multilineTextAlignment(.center)

                        Spacer()

                        // Entry count + page dots
                        VStack(alignment: .trailing, spacing: 4) {
                            HStack(spacing: 3) {
                                ForEach(0..<min(totalPages, 6), id: \.self) { i in
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(i == currentPage ? Color(hex: "#C49245") : Color(hex: "#2A2010").opacity(0.15))
                                        .frame(width: i == currentPage ? 14 : 5, height: 4)
                                        .animation(.spring(response: 0.3), value: currentPage)
                                }
                            }
                            Text("\(book.cards.count) \(book.cards.count == 1 ? "entry" : "entries")")
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(Color(hex: "#70675E").opacity(0.70))
                        }
                        .frame(width: 62, alignment: .trailing)
                    }
                    .padding(.horizontal, 20)
                }
                .frame(height: 64)

                // Header divider — double rule
                VStack(spacing: 2) {
                    Rectangle().fill(Color(hex: "#C49245").opacity(0.50)).frame(height: 0.8)
                    Rectangle().fill(Color(hex: "#2A2010").opacity(0.08)).frame(height: 0.4)
                }
                .padding(.horizontal, 16)

                // ── Entries ───────────────────────────────────────
                if book.isEmpty || pageCards(currentPage).isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "text.page.slash")
                            .font(.system(size: 36))
                            .foregroundColor(Color(hex: "#2A2010").opacity(0.10))
                        Text("No entries for this period")
                            .font(.system(size: 13, design: .serif)).italic()
                            .foregroundColor(Color(hex: "#70675E").opacity(0.40))
                    }.frame(maxWidth: .infinity)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(
                                Array(pageCards(currentPage).enumerated()),
                                id: \.element.objectID
                            ) { idx, card in
                                entryRow(card: card, lineNum: currentPage * cardsPerPage + idx + 1)
                                if idx < pageCards(currentPage).count - 1 {
                                    Rectangle()
                                        .fill(Color(hex: "#2A2010").opacity(0.07))
                                        .frame(height: 0.7)
                                        .padding(.horizontal, 20)
                                }
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                    }
                }

                // ── Footer ────────────────────────────────────────
                VStack(spacing: 0) {
                    Rectangle().fill(Color(hex: "#C49245").opacity(0.30)).frame(height: 0.6).padding(.horizontal, 16)
                    HStack {
                        // Prev
                        Button {
                            guard currentPage > 0 else { return }
                            turnPage(forward: false)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "chevron.left").font(.system(size: 9, weight: .semibold))
                                Text("Prev")
                            }
                            .font(.system(size: 10, design: .serif))
                            .foregroundColor(currentPage > 0 ? Color(hex: "#8B6A38") : Color(hex: "#8B6A38").opacity(0.25))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentPage == 0)

                        Spacer()

                        // Page number ornament
                        HStack(spacing: 6) {
                            Rectangle().fill(Color(hex: "#C49245").opacity(0.35)).frame(width: 16, height: 0.7)
                            Text("\(currentPage + 1)")
                                .font(.system(size: 10, weight: .medium, design: .serif))
                                .foregroundColor(Color(hex: "#2A2010").opacity(0.32))
                            Rectangle().fill(Color(hex: "#C49245").opacity(0.35)).frame(width: 16, height: 0.7)
                        }

                        Spacer()

                        // Next
                        Button {
                            guard currentPage < totalPages - 1 else { return }
                            turnPage(forward: true)
                        } label: {
                            HStack(spacing: 3) {
                                Text("Next")
                                Image(systemName: "chevron.right").font(.system(size: 9, weight: .semibold))
                            }
                            .font(.system(size: 10, design: .serif))
                            .foregroundColor(currentPage < totalPages - 1 ? Color(hex: "#8B6A38") : Color(hex: "#8B6A38").opacity(0.25))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentPage >= totalPages - 1)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                }
            }

            // Page border
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(hex: "#2A1A08").opacity(0.12), lineWidth: 0.8)
        }
        .frame(width: w, height: h)
        .shadow(color: Color.black.opacity(0.35), radius: 20, x: 4, y: 8)
    }

    // MARK: Entry row — classic style, tall and spacious
    private func entryRow(card: CardEntity, lineNum: Int) -> some View {
        let locked = showLockIndicator && !isPrivateUnlocked
        return Button {
            guard !locked else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onCardSelect(card)
        } label: {
            HStack(spacing: 14) {
                // Line number
                Text(String(format: "%02d", lineNum))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(Color(hex: "#2A2010").opacity(0.28))
                    .frame(width: 24, alignment: .trailing)

                // Icon
                Image(systemName: locked ? "lock.fill" : (card.isVoice ? "waveform" : "doc.text.fill"))
                    .font(.system(size: 14))
                    .foregroundColor(locked ? Color(hex: "#C49245") : Color(hex: "#8B6A38").opacity(0.72))
                    .frame(width: 20)

                // Title + snippet (asterisks when locked)
                VStack(alignment: .leading, spacing: 5) {
                    Text(locked ? "••••••••••" : (card.title ?? "Untitled"))
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundColor(Color(hex: "#1C1812"))
                        .lineLimit(1)
                    Text(locked ? "•••••••••••••" : (card.snippet ?? "Voice note"))
                        .font(.system(size: 12, design: .serif)).italic()
                        .foregroundColor(Color(hex: "#70675E"))
                        .lineLimit(1)
                }

                Spacer()

                // Date + duration
                VStack(alignment: .trailing, spacing: 4) {
                    if let d = card.createdAt {
                        Text(locked ? "••••" : fmtShort(d))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(Color(hex: "#70675E").opacity(0.65))
                    }
                    if card.isVoice && !locked {
                        Text(fmtDur(card.durationSec))
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#C49245").opacity(0.85))
                    } else if card.isVoice && locked {
                        Text("••:••")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(hex: "#70675E").opacity(0.65))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(hex: "#2A2010").opacity(0.18))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func turnPage(forward: Bool) {
        let canTurn = forward ? currentPage < totalPages - 1 : currentPage > 0
        guard canTurn && !pageTurning else { return }
        turnForward = forward
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeIn(duration: 0.20)) { pageTurning = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            currentPage += forward ? 1 : -1
            withAnimation(.easeOut(duration: 0.22)) { pageTurning = false }
        }
    }

    private func fmtShort(_ d: Date) -> String { let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d) }
    private func fmtDur(_ s: Double) -> String { let i = Int(s); return String(format: "%d:%02d", i / 60, i % 60) }
}