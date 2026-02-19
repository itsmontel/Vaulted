import SwiftUI

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: TimelineStackView — Physical card-pile inbox with fan-deal animations
// MARK: ─────────────────────────────────────────────────────────────────────
struct TimelineStackView: View {
    @ObservedObject var vm: LibraryViewModel
    @Binding var selectedCard: CardEntity?

    @State private var expandedLabel: String? = nil
    @State private var pileLifted: String?    = nil     // which pile is mid-lift animation
    @State private var privateExpanded        = false
    @State private var lockShake: CGFloat     = 0
    @State private var appearedCards: Set<String> = []  // for stagger entrance

    private var privateCards: [CardEntity] {
        vm.cards.filter { $0.drawer?.isPrivate == true }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Top plate
                stackHeader

                // Pile groups inside the wooden tray
                trayContainer
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 60)
        }
    }

    // MARK: - Header label plate
    private var stackHeader: some View {
        HStack(alignment: .center) {
            HStack(spacing: 8) {
                // Brass "IN" badge
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#D4A848"), Color(hex: "#B8893C"), Color(hex: "#D4A848")],
                                startPoint: .topLeading, endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 2)
                    Text("IN")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .tracking(3.5)
                        .foregroundColor(Color(hex: "#3A2410").opacity(0.8))
                }
                .frame(width: 48, height: 22)

                Text("Stack")
                    .font(.system(size: 13, weight: .semibold, design: .serif))
                    .foregroundColor(.inkMuted)
            }

            Spacer()

            // Total count
            Text("\(vm.cards.count) \(vm.cards.count == 1 ? "note" : "notes")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.inkMuted.opacity(0.7))
        }
        .padding(.horizontal, 6)
        .padding(.bottom, 10)
    }

    // MARK: - Wooden tray container
    private var trayContainer: some View {
        ZStack(alignment: .bottom) {
            // Wood frame
            woodFrame

            // Content column
            VStack(spacing: 0) {
                if vm.groupedByTime.isEmpty && privateCards.isEmpty {
                    emptyState
                } else {
                    // Card pile groups
                    VStack(spacing: 24) {
                        ForEach(Array(vm.groupedByTime.enumerated()), id: \.element.label) { idx, group in
                            CardPileGroup(
                                label: group.label,
                                cards: group.cards,
                                isExpanded: expandedLabel == group.label,
                                isLifted: pileLifted == group.label,
                                selectedCard: $selectedCard,
                                onTap: { tapPile(label: group.label, cards: group.cards) },
                                onDelete: { vm.deleteCard($0); vm.reloadCards() },
                                onStar:   { vm.toggleStar($0); vm.reloadCards() }
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal:   .opacity
                            ))
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 28)
                    .padding(.bottom, 16)

                    // Private drawer at bottom
                    privateDrawerSlot
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#3D3020"), location: 0),
                            .init(color: Color(hex: "#2C2416"), location: 0.35),
                            .init(color: Color(hex: "#201A0E"), location: 1),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .shadow(color: .black.opacity(0.55), radius: 18, x: 0, y: 9)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Wood frame overlay
    private var woodFrame: some View {
        ZStack {
            // Outer border
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color(hex: "#1A1208"), lineWidth: 2.5)

            // Inner bevel
            RoundedRectangle(cornerRadius: 11)
                .stroke(Color(hex: "#4A3C28").opacity(0.5), lineWidth: 1)
                .padding(5)

            // Top highlight
            VStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 2)
                Spacer()
            }

            // Horizontal grain lines
            VStack(spacing: 0) {
                ForEach(0..<40, id: \.self) { i in
                    Spacer()
            Rectangle()
                        .fill(Color.white.opacity(i % 6 == 0 ? 0.012 : 0.004))
                        .frame(height: 0.5)
                }
                Spacer()
            }
            .cornerRadius(14)
        }
    }

    // MARK: - Empty state
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 42))
                .foregroundColor(Color(hex: "#70675E").opacity(0.45))
            Text("The tray is empty")
                .font(.system(.headline, design: .serif).weight(.semibold))
                .foregroundColor(Color(hex: "#70675E"))
            Text("Tap Record to drop your first note in.")
                .font(.system(.callout, design: .serif))
                .foregroundColor(Color(hex: "#70675E").opacity(0.55))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 56)
        .padding(.horizontal, 32)
    }

    // MARK: - Private drawer slot
    private var privateDrawerSlot: some View {
        let isUnlocked = vm.isPrivateUnlocked
        return VStack(spacing: 0) {
            // Separator groove
            ZStack {
                Rectangle().fill(Color.black.opacity(0.45)).frame(height: 10)
                Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1).offset(y: -4)
            }

            // Drawer face
            ZStack {
                LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#4A3020"), location: 0),
                        .init(color: Color(hex: "#382210"), location: 0.5),
                        .init(color: Color(hex: "#2A1808"), location: 1),
                    ],
                    startPoint: .top, endPoint: .bottom
                )

                // Vertical grain
                HStack(spacing: 16) {
                    ForEach(0..<16, id: \.self) { i in
                        Rectangle()
                            .fill(Color.white.opacity(i % 4 == 0 ? 0.016 : 0.006))
                            .frame(width: 1)
                    }
                }

                VStack {
                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                    Spacer()
                }

                Button { drawerTapped(isUnlocked: isUnlocked) } label: {
                    HStack(spacing: 14) {
                        brassPlate
                        Spacer()
                        if isUnlocked && !privateCards.isEmpty {
                            Text("\(privateCards.count) \(privateCards.count == 1 ? "entry" : "entries")")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "#D4A860").opacity(0.65))
                        }
                        lockIconView(isUnlocked: isUnlocked)
                            .offset(x: lockShake)
                        if isUnlocked {
                            Image(systemName: privateExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: "#D4A860").opacity(0.55))
                                .animation(.spring(response: 0.3), value: privateExpanded)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(minHeight: 58)

            if isUnlocked && privateExpanded {
                privateCardList
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .push(from: .bottom).combined(with: .opacity)
                    ))
            }
        }
    }

    private var brassPlate: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(LinearGradient(
                    stops: [
                        .init(color: Color(hex: "#D4A848"), location: 0),
                        .init(color: Color(hex: "#C49030"), location: 0.45),
                        .init(color: Color(hex: "#B88020"), location: 0.7),
                        .init(color: Color(hex: "#D4A848"), location: 1),
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
            Text("PRIVATE")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(2.8)
                .foregroundColor(Color(hex: "#3A2810").opacity(0.82))
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        }
        .frame(width: 104, height: 30)
    }

    private func lockIconView(isUnlocked: Bool) -> some View {
        ZStack {
            Circle()
                .fill(Color(hex: "#C49245").opacity(isUnlocked ? 0.15 : 0.1))
                .frame(width: 36, height: 36)
            Image(systemName: isUnlocked ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 16))
                .foregroundColor(isUnlocked ? Color(hex: "#C49245") : Color(hex: "#D4A848"))
        }
    }

    private var privateCardList: some View {
        VStack(spacing: 0) {
            ForEach(Array(privateCards.enumerated()), id: \.element.objectID) { idx, card in
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    selectedCard = card
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: "#C49245").opacity(0.14)).frame(width: 28, height: 28)
                            Image(systemName: card.isVoice ? "waveform" : "doc.text.fill")
                                .font(.system(size: 11)).foregroundColor(Color(hex: "#C49245").opacity(0.85))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(card.title ?? "Untitled")
                                .font(.system(size: 13, weight: .medium, design: .serif))
                                .foregroundColor(Color(hex: "#EDE5D4")).lineLimit(1)
                            Text(card.snippet ?? "")
                                .font(.system(size: 11, design: .serif))
                                .foregroundColor(Color(hex: "#A89070").opacity(0.85)).lineLimit(1)
                        }
                        Spacer()
                        if let d = card.createdAt {
                            Text(fmtDate(d)).font(.system(size: 9, design: .monospaced))
                                .foregroundColor(Color(hex: "#A89070").opacity(0.55))
                        }
                    }
                    .padding(.horizontal, 20).padding(.vertical, 12).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if idx < privateCards.count - 1 {
                    Rectangle().fill(Color(hex: "#C49245").opacity(0.07)).frame(height: 0.5).padding(.horizontal, 20)
                }
            }
        }
        .background(Color(hex: "#1A1208").opacity(0.9))
    }

    // MARK: - Interactions
    private func tapPile(label: String, cards: [CardEntity]) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) { pileLifted = label }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
                pileLifted = nil
                expandedLabel = expandedLabel == label ? nil : label
            }
        }
    }

    private func drawerTapped(isUnlocked: Bool) {
        if isUnlocked {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.75)) { privateExpanded.toggle() }
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { lockShake = 5 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { lockShake = -5 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.interpolatingSpring(stiffness: 700, damping: 9)) { lockShake = 3 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        withAnimation(.spring()) { lockShake = 0 }
                    }
                }
            }
            Task { _ = await vm.unlockPrivate() }
        }
    }

    private func fmtDate(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: CardPileGroup — One time bucket (Today / Yesterday / This Week / Earlier)
//       Shows a physical stack of cards; tapping fans them out one by one.
// MARK: ─────────────────────────────────────────────────────────────────────
private struct CardPileGroup: View {
    let label: String
    let cards: [CardEntity]
    let isExpanded: Bool
    let isLifted: Bool
    @Binding var selectedCard: CardEntity?
    let onTap: () -> Void
    let onDelete: (CardEntity) -> Void
    let onStar:   (CardEntity) -> Void

    // deterministic "random" rotation per card in the pile (seed = hash of label)
    private func wobble(depth: Int) -> Double {
        let seed = (label.hashValue &+ depth &* 31) % 100
        return Double(seed % 7 - 3) * 0.65   // -1.95° to +1.95°
    }
    private func hShift(depth: Int) -> CGFloat {
        let seed = (label.hashValue &+ depth &* 17) % 100
        return CGFloat(seed % 11 - 5) * 0.4   // ±2pt
    }

    private var visibleDepth: Int { min(cards.count - 1, 3) }
    private var topDate: String {
        guard let d = cards.first?.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d"; return f.string(from: d)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section label (floating above the stack)
            HStack(alignment: .center, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(hex: "#D4A848").opacity(0.75))
                    .tracking(1.8)
                Rectangle()
                    .fill(Color(hex: "#D4A848").opacity(0.2))
                    .frame(height: 0.5)
            }
            .padding(.bottom, 10)
            .padding(.horizontal, 2)

            // The card pile itself
            ZStack(alignment: .bottom) {
                // Ghost cards beneath (depth layers, drawn back-to-front)
                ForEach((1...max(1, visibleDepth)).reversed(), id: \.self) { depth in
                    ghostCardView(depth: depth)
                }

                // TOP CARD (always visible, tappable)
                topCardView
                    .offset(y: isLifted ? -24 : 0)
                    .shadow(
                        color: .black.opacity(isLifted ? 0.55 : 0.22),
                        radius: isLifted ? 22 : 6,
                        x: 0,
                        y: isLifted ? -8 : 3
                    )
                    .animation(.spring(response: 0.24, dampingFraction: 0.52), value: isLifted)
                    .onTapGesture(perform: onTap)
                    .zIndex(10)
            }
            // Extra bottom padding so ghost cards below don't clip
            .padding(.bottom, CGFloat(visibleDepth) * 4 + 4)

            // Fanned-out individual cards (dealt downward when expanded)
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(Array(cards.enumerated()), id: \.element.objectID) { idx, card in
                        DealtCardRow(
                            card: card,
                            index: idx,
                            isLocked: card.drawer?.isPrivate == true && !(selectedCard?.drawer?.isPrivate == false),
                            onSelect: { selectedCard = card },
                            onDelete: { onDelete(card) },
                            onStar:   { onStar(card) }
                        )
                    }
                }
                .padding(.top, 8)
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal:   .push(from: .bottom).combined(with: .opacity)
                ))
            }
        }
    }

    // MARK: Ghost (depth) card
    private func ghostCardView(depth: Int) -> some View {
        let paperShades: [Color] = [
            Color(hex: "#E4DBc6"),
            Color(hex: "#D9D0BB"),
            Color(hex: "#CFC6B1"),
            Color(hex: "#C5BCA7"),
        ]
        let shade = paperShades[min(depth - 1, paperShades.count - 1)]
        let alphaStep = 0.82 - Double(depth) * 0.17
        let shrink = CGFloat(depth) * 5.0

        return RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [shade, shade.opacity(0.92)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                // Faint top ruling line on each ghost card
                VStack {
                    Rectangle().fill(Color(hex: "#2A2010").opacity(0.06)).frame(height: 0.6)
                    Spacer()
                }
                .cornerRadius(6)
            )
            .frame(maxWidth: .infinity)
            .padding(.horizontal, shrink / 2)
            .frame(height: 60)
            .rotationEffect(.degrees(wobble(depth: depth)), anchor: .bottom)
            .offset(x: hShift(depth: depth), y: CGFloat(depth) * 4.5)
            .opacity(alphaStep)
            .shadow(color: .black.opacity(0.10 + Double(depth) * 0.04), radius: 2, x: 0, y: 1)
    }

    // MARK: Top card face
    private var topCardView: some View {
        ZStack {
            // Paper body
            RoundedRectangle(cornerRadius: 7)
                .fill(
                    LinearGradient(
                        stops: [
                            .init(color: Color(hex: "#F5EDD8"), location: 0),
                            .init(color: Color(hex: "#EEE6CE"), location: 0.55),
                            .init(color: Color(hex: "#E8DFC8"), location: 1),
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // Card border
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(hex: "#C8B898").opacity(0.6), lineWidth: 0.8)

            // Ruling lines (index card style)
            VStack(spacing: 0) {
                Spacer()
                ForEach(0..<4, id: \.self) { i in
                    Rectangle()
                        .fill(Color(hex: "#2A2010").opacity(i == 0 ? 0.09 : 0.04))
                        .frame(height: i == 0 ? 0.7 : 0.4)
                    if i < 3 { Spacer() }
                }
                Spacer().frame(height: 8)
            }
            .padding(.horizontal, 14)
            .cornerRadius(7)

            // Gold accent strip at top
            VStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#C49245").opacity(0.28), Color(hex: "#C49245").opacity(0.0)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(height: 24)
                Spacer()
            }

            // Content
            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundColor(Color(hex: "#1C1812"))
                    HStack(spacing: 6) {
                        // Card count pill
                        HStack(spacing: 4) {
                            Image(systemName: "square.stack.fill")
                                .font(.system(size: 8))
                            Text("\(cards.count)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                        }
                        .foregroundColor(Color(hex: "#8B6A38"))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#C49245").opacity(0.14))
                        .clipShape(Capsule())

                        if !topDate.isEmpty {
                            Text(topDate)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(Color(hex: "#70675E").opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Expand/collapse indicator
                VStack(spacing: 3) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#70675E").opacity(0.5))
                        .animation(.spring(response: 0.28), value: isExpanded)

                    // Stack depth dots
                    if !isExpanded && visibleDepth > 0 {
                        HStack(spacing: 3) {
                            ForEach(0..<min(visibleDepth, 3), id: \.self) { _ in
                                Circle()
                                    .fill(Color(hex: "#70675E").opacity(0.3))
                                    .frame(width: 4, height: 4)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.trailing, 2)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(height: 74)
    }
}

// MARK: ─────────────────────────────────────────────────────────────────────
// MARK: DealtCardRow — A single card "dealt" from the pile with stagger appear
// MARK: ─────────────────────────────────────────────────────────────────────
private struct DealtCardRow: View {
    let card: CardEntity
    let index: Int
    let isLocked: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onStar:   () -> Void

    @State private var appeared = false

    private var dateStr: String {
        guard let d = card.createdAt else { return "" }
        let f = DateFormatter(); f.dateFormat = "MMM d · h:mm a"; return f.string(from: d)
    }
    private var durStr: String {
        let s = Int(card.durationSec); return String(format: "%d:%02d", s/60, s%60)
    }

    // Deterministic slight tilt per card so they look "tossed"
    private var tilt: Double {
        let seed = (card.objectID.hashValue &+ index &* 13) % 100
        return Double(seed % 5 - 2) * 0.3  // -0.6° to +0.6°
    }

    var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onSelect()
        }) {
            ZStack {
                // Card surface
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#F8F2E4"), Color(hex: "#F2EAD6")],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .black.opacity(0.16), radius: 5, x: 0, y: 3)

                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(hex: "#D4C4A4").opacity(0.7), lineWidth: 0.8)

                // Left type accent strip
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            card.isVoice
                                ? Color(hex: "#C49245").opacity(0.85)
                                : Color(hex: "#70675E").opacity(0.45)
                        )
                        .frame(width: 4)
                    Spacer()
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))

                // Subtle ruling lines
                VStack(spacing: 0) {
                    Spacer()
                    ForEach(0..<3, id: \.self) { i in
                        Rectangle()
                            .fill(Color(hex: "#2A2010").opacity(0.04))
                            .frame(height: 0.4)
                        if i < 2 { Spacer() }
                    }
                    Spacer().frame(height: 6)
                }
                .padding(.horizontal, 16)
                .cornerRadius(8)

                // Content
                HStack(spacing: 12) {
                    // Type icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                card.isVoice
                                    ? Color(hex: "#C49245").opacity(0.13)
                                    : Color(hex: "#2A2010").opacity(0.07)
                            )
                            .frame(width: 34, height: 34)
                        Image(systemName: card.isVoice ? "waveform" : "doc.text.fill")
                            .font(.system(size: 13))
                            .foregroundColor(
                                card.isVoice
                                    ? Color(hex: "#C49245")
                                    : Color(hex: "#70675E")
                            )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.title ?? "Untitled")
                            .font(.system(size: 14, weight: .semibold, design: .serif))
                            .foregroundColor(Color(hex: "#1C1812"))
                            .lineLimit(1)

                        if card.isVoice {
                            HStack(spacing: 5) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9))
                                Text(durStr)
                                    .font(.system(size: 10, design: .monospaced))
                            }
                            .foregroundColor(Color(hex: "#8B6A38").opacity(0.75))
                        } else if let snippet = card.snippet, !snippet.isEmpty {
                            Text(snippet)
                                .font(.system(size: 11, design: .serif))
                                .foregroundColor(Color(hex: "#70675E").opacity(0.8))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        if card.starred {
                            Image(systemName: "star.fill")
                                .font(.system(size: 9))
                                .foregroundColor(Color(hex: "#C49245"))
                        }
                        Text(dateStr)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(Color(hex: "#70675E").opacity(0.5))
                            .multilineTextAlignment(.trailing)

                        // Tags
                        if !card.tagList.isEmpty {
                            HStack(spacing: 3) {
                                ForEach(card.tagList.prefix(2), id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 8, weight: .medium, design: .rounded))
                                        .foregroundColor(Color(hex: "#8B6A38"))
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color(hex: "#C49245").opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(Color(hex: "#2A2010").opacity(0.2))
                }
                .padding(.leading, 18)
                .padding(.trailing, 14)
                .padding(.vertical, 14)
            }
            .rotationEffect(.degrees(appeared ? 0 : tilt + (index % 2 == 0 ? 1.5 : -1.5)))
            .offset(y: appeared ? 0 : -12)
            .opacity(appeared ? 1 : 0)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
            Button(action: onStar) {
                Label(card.starred ? "Unstar" : "Star",
                      systemImage: card.starred ? "star.slash" : "star")
            }
            .tint(Color(hex: "#C49245"))
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 2)
        .onAppear {
            withAnimation(
                .spring(response: 0.38, dampingFraction: 0.72)
                .delay(Double(index) * 0.055)
            ) {
                appeared = true
            }
        }
        .onDisappear { appeared = false }
    }
}
