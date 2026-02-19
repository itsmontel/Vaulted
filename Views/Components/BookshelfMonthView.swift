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

    @State private var liftedId: String?       = nil
    @State private var coverFlip: Double       = 0
    @State private var openBook: ShelfBook?    = nil
    @State private var openPhase: OpenPhase    = .idle

    // Wider books to fill screen better (6 per row)
    private let spineWidths:  [CGFloat] = [58, 64, 56, 62, 60, 58, 64, 56, 62, 60, 58, 64]
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
        let year = cal.component(.year, from: Date())
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
        var cur = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        for _ in 0..<8 {
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
        let monday = cal.date(from: c) ?? Date()
        return (0..<7).map { offset in
            let day   = cal.date(byAdding: .day, value: offset, to: monday) ?? monday
            let sub   = fmt.string(from: day)
            let cards = existing[sub] ?? []
            return makeBook(id: "day-\(offset)", label: dayNames[offset],
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
        stride(from: 0, to: books.count, by: 6).map { Array(books[$0..<min($0 + 6, books.count)]) }
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
                book:              book,
                isPrivateUnlocked: vm.isPrivateUnlocked,
                onCardSelect: { card in selectedCard = card; openBook = nil },
                onClose:      { openBook = nil }
            )
        }
    }

    // MARK: Period picker
    private var periodPicker: some View {
        HStack(spacing: 0) {
            ForEach(BookshelfPeriod.allCases, id: \.self) { period in
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
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Color.paperBackground)
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
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 24)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(hex: "#2C2416"), lineWidth: 4)
        )
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#1A1208").opacity(0.3))
        )
        .cornerRadius(12)
        .shadow(color: Color(hex: "#1C1812").opacity(0.65), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 12)
        .padding(.vertical, 16)
    }

    private func shelfRow(books: [ShelfBook]) -> some View {
        let rowH = books.map { $0.spineHeight }.max().map { $0 + 36 } ?? 210
        return ZStack(alignment: .bottom) {
            Color.clear.frame(height: rowH + 20)
            HStack(alignment: .bottom, spacing: 4) {
                sideWall(h: rowH)
                ForEach(books) { book in
                    BookSpineView(
                        book:      book,
                        isLifted:  liftedId == book.id,
                        flipAngle: liftedId == book.id ? coverFlip : 0
                    )
                    .onTapGesture { animateOpen(book) }
                }
                sideWall(h: rowH)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .frame(maxWidth: .infinity, minHeight: rowH, alignment: .bottom)
            shelfPlank
        }
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

    private var c: SpineColor { book.spineColor }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Page-edge depth layers (show paper pages from the side)
            ForEach(0..<4, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color(hex: "#C8C0A8").opacity(0.80 - Double(i) * 0.12))
                    .frame(width: book.spineWidth,
                           height: book.spineHeight - CGFloat(i) * 2.2)
                    .offset(x: CGFloat(i + 1) * 1.1, y: CGFloat(i + 1) * 0.8)
            }
            // Main spine face
            spineBody
                .frame(width: book.spineWidth, height: book.spineHeight)
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
            color: Color.black.opacity(isLifted ? 0.68 : 0.30),
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
            // Top cap decorative band (gold/accent line)
            VStack(spacing: 1.5) {
                Rectangle().fill(c.accentLine.opacity(0.70)).frame(height: 1.5)
                Rectangle().fill(c.accentLine.opacity(0.30)).frame(height: 0.7)
            }.padding(.top, 5).padding(.horizontal, 4)

            Spacer(minLength: 5)

            // Short label (e.g. "JAN", "MON")
            Text(book.shortLabel)
                .font(.system(size: 10, weight: .bold, design: .serif))
                .tracking(1.2)
                .foregroundColor(c.textColor.opacity(0.85))

            Spacer(minLength: 4)

            // Accent rule
            Rectangle()
                .fill(c.accentLine.opacity(0.50))
                .frame(width: book.spineWidth * 0.55, height: 0.8)

            Spacer(minLength: 10)

            // Main rotated title
            Text(book.label)
                .font(.system(
                    size: max(11, min(14, book.spineWidth / 3.0)),
                    weight: .semibold,
                    design: .serif
                ))
                .foregroundColor(c.textColor.opacity(0.95))
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.6)
                .frame(width: book.spineHeight * 0.52, height: book.spineWidth - 8)
                .rotationEffect(.degrees(-90))

            Spacer(minLength: 10)

            // Decorative cross ornament
            if book.hasDecorativeCross {
                ZStack {
                    Rectangle().fill(c.accentLine.opacity(0.50)).frame(width: book.spineWidth * 0.50, height: 0.8)
                    Rectangle().fill(c.accentLine.opacity(0.50)).frame(width: 0.8, height: 10)
                }.padding(.bottom, 5)
            }

            Text(book.subLabel)
                .font(.system(size: 9, weight: .medium, design: .serif))
                .foregroundColor(c.textColor.opacity(0.65))

            Spacer(minLength: 4)

            Text(book.isEmpty ? "—" : "\(book.cards.count)")
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(c.textColor.opacity(0.35))

            Spacer(minLength: 5)

            // Bottom cap band
            VStack(spacing: 1.5) {
                Rectangle().fill(c.accentLine.opacity(0.30)).frame(height: 0.7)
                Rectangle().fill(c.accentLine.opacity(0.70)).frame(height: 1.5)
            }.padding(.bottom, 5).padding(.horizontal, 4)
        }
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: OpenBookModal — fullScreenCover so both pages are fully visible
// MARK: ─────────────────────────────────────────────────────────────────────
private struct OpenBookModal: View {
    let book: ShelfBook
    let isPrivateUnlocked: Bool
    let onCardSelect: (CardEntity) -> Void
    let onClose: () -> Void

    @State private var appeared    = false
    @State private var currentPage = 0
    @State private var pageTurning = false
    @State private var turnForward = true

    private let cardsPerPage = 5
    private var totalPages: Int { max(1, Int(ceil(Double(book.cards.count) / Double(cardsPerPage)))) }
    private func pageCards(_ p: Int) -> [CardEntity] {
        let s = p * cardsPerPage
        let e = min(s + cardsPerPage, book.cards.count)
        guard s < book.cards.count else { return [] }
        return Array(book.cards[s..<e])
    }

    var body: some View {
        ZStack {
            // Dark library atmosphere — fills full screen
            ambientBG.ignoresSafeArea()

            // Book spread in center
            GeometryReader { geo in
                let sw = geo.size.width
                let sh = geo.size.height

                // Book takes 92% of screen width, split evenly into two pages
                let bookW = sw * 0.92
                let bookH = min(sh * 0.68, 520.0)
                let pageW = (bookW - 12) / 2   // 12pt for binding

                ZStack {
                    // Drop shadow
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.black.opacity(0.72))
                        .frame(width: bookW + 18, height: bookH + 18)
                        .blur(radius: 26)

                    // Left page
                    leftPage(w: pageW, h: bookH)
                        .offset(x: -(pageW / 2 + 6))

                    // Leather binding spine
                    leatherBinding(h: bookH)

                    // Right page (with page-turn 3D effect)
                    rightPage(w: pageW, h: bookH)
                        .offset(x: pageW / 2 + 6)
                        .rotation3DEffect(
                            .degrees(pageTurning ? (turnForward ? -90 : 90) : 0),
                            axis: (x: 0, y: 1, z: 0),
                            anchor: .leading,
                            perspective: 0.55
                        )
                        .animation(
                            pageTurning ? .easeIn(duration: 0.22) : .easeOut(duration: 0.22),
                            value: pageTurning
                        )
                }
                .frame(width: bookW, height: bookH)
                .scaleEffect(appeared ? 1.0 : 0.78)
                .opacity(appeared ? 1.0 : 0.0)
                .offset(y: appeared ? 0 : 55)
                .animation(.spring(response: 0.44, dampingFraction: 0.74), value: appeared)
                // Centre in the available space (between header and footer)
                .position(x: sw / 2, y: sh / 2)
            }

            // Chrome (close + nav arrows) — sits above everything
            chrome
        }
        .onAppear { DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { appeared = true } }
        .gesture(DragGesture(minimumDistance: 44)
            .onEnded { v in
                if v.translation.width < -50 { turnPage(forward: true) }
                else if v.translation.width > 50 { turnPage(forward: false) }
            }
        )
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
            // Warm candlelight glow
            Ellipse()
                .fill(RadialGradient(
                    colors: [Color.accentGold.opacity(0.10), Color.clear],
                    center: .center, startRadius: 0, endRadius: 340
                ))
                .frame(width: 640, height: 340)
                .offset(y: 60)
        }
    }

    // MARK: Left page (title / chapter page)
    private func leftPage(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(hex: "#F4EEE0"))
            // Spine-side shadow
            HStack {
                Spacer()
                LinearGradient(
                    colors: [Color.black.opacity(0.08), Color.clear],
                    startPoint: .trailing, endPoint: .leading
                ).frame(width: 36)
            }.cornerRadius(4)

            VStack(alignment: .leading, spacing: 0) {
                // Top rule
                Rectangle().fill(Color(hex: "#2A2010").opacity(0.20)).frame(height: 0.8)
                    .padding(.horizontal, 22).padding(.top, 26)

                VStack(alignment: .leading, spacing: 7) {
                    Text(book.shortLabel)
                        .font(.system(size: 9, weight: .bold, design: .serif)).tracking(3.5)
                        .foregroundColor(Color(hex: "#8B6A38")).padding(.top, 20)
                    Text(book.label)
                        .font(.system(size: min(30, max(20, 180 / max(1, CGFloat(book.label.count)))),
                                      weight: .bold, design: .serif))
                        .foregroundColor(Color(hex: "#1C1812"))
                        .lineLimit(3).minimumScaleFactor(0.55)
                    Text(book.subLabel)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(Color(hex: "#70675E"))
                }
                .padding(.horizontal, 22).padding(.top, 8)

                // Ledger lines (vintage look)
                VStack(spacing: 0) {
                    ForEach(0..<12, id: \.self) { i in
                        Spacer()
                        Rectangle().fill(Color(hex: "#2A2010").opacity(i % 5 == 0 ? 0.13 : 0.05))
                            .frame(height: i % 5 == 0 ? 0.8 : 0.4)
                    }
                    Spacer()
                }
                .frame(height: h * 0.26).padding(.horizontal, 22).padding(.top, 20)

                Spacer()

                VStack(alignment: .leading, spacing: 5) {
                    Text("CONTENTS")
                        .font(.system(size: 8, weight: .semibold, design: .serif)).tracking(2.5)
                        .foregroundColor(Color(hex: "#70675E").opacity(0.60))
                    Text(book.isEmpty ? "No entries yet"
                         : "\(book.cards.count) recorded \(book.cards.count == 1 ? "entry" : "entries")")
                        .font(.system(size: 13, design: .serif)).foregroundColor(Color(hex: "#1C1812"))
                    if totalPages > 1 {
                        Text("\(totalPages) pages — swipe to turn")
                            .font(.system(size: 10, design: .serif)).italic()
                            .foregroundColor(Color(hex: "#70675E").opacity(0.55))
                    }
                }.padding(.horizontal, 22).padding(.bottom, 22)

                Text("—")
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(Color(hex: "#2A2010").opacity(0.20))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 18)
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: Right page (entries list)
    private func rightPage(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4).fill(Color(hex: "#F8F3E8"))
            // Spine-side shadow
            HStack {
                LinearGradient(
                    colors: [Color.black.opacity(0.07), Color.clear],
                    startPoint: .leading, endPoint: .trailing
                ).frame(width: 28)
                Spacer()
            }.cornerRadius(4)

            VStack(spacing: 0) {
                // Running header
                HStack {
                    Text(book.subLabel.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .serif)).tracking(2)
                        .foregroundColor(Color(hex: "#8B6A38"))
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(0..<totalPages, id: \.self) { i in
                            Circle()
                                .fill(i == currentPage ? Color.accentGold : Color(hex: "#2A2010").opacity(0.18))
                                .frame(width: 6, height: 6)
                        }
                    }
                }.padding(.horizontal, 20).padding(.vertical, 14)

                Rectangle().fill(Color(hex: "#2A2010").opacity(0.12)).frame(height: 0.5).padding(.horizontal, 20)

                if book.isEmpty || pageCards(currentPage).isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "square.dashed").font(.system(size: 30))
                            .foregroundColor(Color(hex: "#2A2010").opacity(0.13))
                        Text("No entries for this period")
                            .font(.system(size: 12.5, design: .serif)).italic()
                            .foregroundColor(Color(hex: "#70675E").opacity(0.42))
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
                                Rectangle().fill(Color(hex: "#2A2010").opacity(0.055))
                                    .frame(height: 0.5).padding(.horizontal, 18)
                            }
                        }.padding(.top, 10).padding(.bottom, 12)
                    }
                }

                Spacer(minLength: 0)
                Rectangle().fill(Color(hex: "#2A2010").opacity(0.10)).frame(height: 0.5).padding(.horizontal, 20)
                Text("\(currentPage + 1)")
                    .font(.system(size: 10, design: .serif))
                    .foregroundColor(Color(hex: "#2A2010").opacity(0.28))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
            }
        }
        .frame(width: w, height: h)
    }

    // MARK: Entry row
    private func entryRow(card: CardEntity, lineNum: Int) -> some View {
        let locked = card.drawer?.isPrivate == true && !isPrivateUnlocked
        return Button {
            guard !locked else { return }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onCardSelect(card)
        } label: {
            HStack(spacing: 10) {
                Text(String(format: "%02d", lineNum))
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundColor(Color(hex: "#2A2010").opacity(0.24)).frame(width: 20, alignment: .trailing)
                Image(systemName: locked ? "lock.fill" : (card.isVoice ? "waveform" : "doc.text.fill"))
                    .font(.system(size: 11))
                    .foregroundColor(locked ? Color.accentGold : Color(hex: "#8B6A38").opacity(0.65))
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 3) {
                    Text(locked ? "Private entry" : (card.title ?? "Untitled"))
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundColor(Color(hex: "#1C1812")).lineLimit(1)
                    Text(locked ? "•••••••••••" : (card.snippet ?? ""))
                        .font(.system(size: 10.5, design: .serif)).italic()
                        .foregroundColor(Color(hex: "#70675E")).lineLimit(1)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    if let d = card.createdAt {
                        Text(fmtShort(d)).font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#70675E").opacity(0.6))
                    }
                    if card.isVoice && !locked {
                        Text(fmtDur(card.durationSec)).font(.system(size: 8.5, design: .monospaced))
                            .foregroundColor(Color(hex: "#8B6A38").opacity(0.5))
                    }
                }
                Image(systemName: "chevron.right").font(.system(size: 8))
                    .foregroundColor(Color(hex: "#2A2010").opacity(0.18))
            }
            .padding(.horizontal, 18).padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Leather binding
    private func leatherBinding(h: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(LinearGradient(
                    colors: [Color(hex: "#5C4022"), Color(hex: "#3C2810"), Color(hex: "#5C4022")],
                    startPoint: .leading, endPoint: .trailing
                ))
                .frame(width: 12, height: h)
            VStack(spacing: 13) {
                ForEach(0..<10, id: \.self) { _ in
                    Rectangle().fill(Color.black.opacity(0.28)).frame(width: 5, height: 1).cornerRadius(0.5)
                }
            }
        }
    }

    // MARK: Chrome overlay (close + page nav)
    private var chrome: some View {
        VStack {
            // Top bar
            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.easeOut(duration: 0.20)) { appeared = false }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) { onClose() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                        Text("Close").font(.system(size: 13, design: .serif))
                    }
                    .foregroundColor(.white.opacity(0.72))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Color.white.opacity(0.09))
                    .cornerRadius(22)
                    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.10), lineWidth: 0.5))
                }
                Spacer()
                VStack(spacing: 2) {
                    Text(book.label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .serif)).tracking(2)
                        .foregroundColor(.white.opacity(0.68)).lineLimit(1)
                    Text(book.subLabel)
                        .font(.system(size: 9, design: .serif)).foregroundColor(.white.opacity(0.30))
                }
                Spacer()
                Text("pg \(currentPage + 1)/\(totalPages)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.white.opacity(0.30)).frame(minWidth: 64, alignment: .trailing)
            }
            .padding(.horizontal, 22).padding(.top, 60)

            Spacer()

            // Bottom page navigation
            if totalPages > 1 {
                HStack(spacing: 50) {
                    navArrow(forward: false, enabled: currentPage > 0)
                    navArrow(forward: true,  enabled: currentPage < totalPages - 1)
                }
                .padding(.bottom, 52)
            }
        }
    }

    private func navArrow(forward: Bool, enabled: Bool) -> some View {
        Button { turnPage(forward: forward) } label: {
            Image(systemName: forward ? "chevron.right" : "chevron.left")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white.opacity(enabled ? 0.65 : 0.14))
                .frame(width: 52, height: 52)
                .background(Color.white.opacity(enabled ? 0.09 : 0.02))
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.white.opacity(enabled ? 0.10 : 0.02), lineWidth: 0.5))
        }.disabled(!enabled)
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