import SwiftUI

// MARK: - TranscriptViewMode
enum TranscriptViewMode: String, CaseIterable {
    case full    = "Full"
    case bullets = "Bullets"
}

// MARK: - BulletizerState
@MainActor
final class BulletizerState: ObservableObject {
    @Published var isConverting  = false
    @Published var conversionError: String?
    @Published private(set) var hasOriginal = false
    @Published private(set) var result: BulletizedResult?
    private var originalText: String?

    var plainBullets: String { result?.plainText ?? "" }

    func convert(text: String, onResult: @escaping (BulletizedResult) -> Void) {
        guard !text.isEmpty, !isConverting else { return }
        originalText = text
        hasOriginal  = true
        isConverting = true
        conversionError = nil
        result = nil

        Task {
            do {
                let structured = try await TranscriptBulletizer.bulletizeStructuredAsync(text)
                await MainActor.run {
                    self.result      = structured
                    self.isConverting = false
                    onResult(structured)
                }
            } catch {
                await MainActor.run {
                    self.isConverting   = false
                    self.conversionError = "Couldn't convert — try again."
                    self.hasOriginal    = false
                    self.originalText   = nil
                    self.result         = nil
                }
            }
        }
    }

    func revert(onRevert: (String) -> Void) {
        guard let original = originalText else { return }
        hasOriginal  = false
        originalText = nil
        result       = nil
        conversionError = nil
        onRevert(original)
    }

    func clearError() { conversionError = nil }
}

// MARK: - BulletizeButton
struct BulletizeButton: View {
    let isEnabled: Bool
    let isConverting: Bool
    let action: () -> Void

    var body: AnyView {
        let btn = Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            bulletizeLabelContent
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || isConverting)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isConverting)
        .animation(.spring(response: 0.2, dampingFraction: 0.8), value: isEnabled)
        return AnyView(btn)
    }

    private var bulletizeLabelContent: some View {
        HStack(spacing: 6) {
            if isConverting {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.78)
                Text("Creating…")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            } else {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("Smart bullets")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
            }
        }
        .foregroundColor(isEnabled ? .white : .inkMuted.opacity(0.5))
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(bulletizeBackgroundView)
    }

    private var bulletizeBackgroundView: some View {
        let rect = RoundedRectangle(cornerRadius: 10)
        if isEnabled {
            return AnyView(
                rect.fill(LinearGradient(
                    colors: [Color.accentGold, Color.accentGold.opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .shadow(
                    color: Color.accentGold.opacity(isConverting ? 0.2 : 0.45),
                    radius: isConverting ? 4 : 8, x: 0, y: 3
                )
            )
        } else {
            return AnyView(rect.fill(Color.inkMuted.opacity(0.15)))
        }
    }
}

// MARK: - TranscriptModePicker
struct TranscriptModePicker: View {
    @Binding var mode: TranscriptViewMode
    @Namespace private var pickerNS

    var body: AnyView {
        let content = HStack(spacing: 2) {
            ForEach(TranscriptViewMode.allCases, id: \.self) { m in
                pickerButton(for: m)
            }
        }
        .padding(3)
        .background(pickerBackgroundView)
        return AnyView(content)
    }

    private func pickerButton(for m: TranscriptViewMode) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { mode = m }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Text(m.rawValue)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(mode == m ? .accentGold : .inkMuted)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(pickerButtonBG(for: m))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func pickerButtonBG(for m: TranscriptViewMode) -> some View {
        if mode == m {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.accentGold.opacity(0.14))
                .matchedGeometryEffect(id: "picker_bg", in: pickerNS)
        }
    }

    private var pickerBackgroundView: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.cardSurface)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(Color.borderMuted.opacity(0.6), lineWidth: 0.8)
            )
    }
}

// MARK: - GroupedBulletsView
struct GroupedBulletsView: View {
    let result: BulletizedResult
    @State private var visibleBullets: Set<String> = []

    var body: AnyView {
        return AnyView(groupContent)
    }

    private var groupContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(Array(result.groups.enumerated()), id: \.offset) { groupIdx, item in
                groupSection(groupIdx: groupIdx, item: item)
            }
        }
    }

    private func groupSection(groupIdx: Int, item: BulletizedResult.GroupedBullets) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            GroupHeaderView(group: item.group)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(item.bullets.enumerated()), id: \.offset) { bulletIdx, bullet in
                    bulletRow(groupIdx: groupIdx, bulletIdx: bulletIdx, bullet: bullet, accent: accentColor(for: item.group))
                }
            }
        }
    }

    private func bulletRow(groupIdx: Int, bulletIdx: Int, bullet: String, accent: Color) -> some View {
        let key = "\(groupIdx)-\(bulletIdx)"
        return BulletRowView(
            bullet: bullet,
            accentColor: accent,
            isVisible: visibleBullets.contains(key)
        )
        .onAppear {
            let delay = Double(groupIdx) * 0.08 + Double(bulletIdx) * 0.06
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.72)) {
                    _ = visibleBullets.insert(key)
                }
            }
        }
    }

    private func accentColor(for group: BulletizedResult.Group) -> Color {
        switch group {
        case .actions:   return Color.accentGold
        case .ideas:     return Color(hex: "#5DA6D8")
        case .keyPoints: return Color(hex: "#7B7FBE")
        case .notes:     return Color.inkMuted
        }
    }
}

// MARK: - GroupHeaderView
private struct GroupHeaderView: View {
    let group: BulletizedResult.Group

    var body: some View {
        let name = groupIconName
        let col = groupIconColor
        return HStack(spacing: 6) {
            Image(systemName: name)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(col)
            Text(group.rawValue.uppercased())
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(col)
                .tracking(1.4)
            Rectangle()
                .fill(col.opacity(0.25))
                .frame(height: 0.75)
        }
    }

    private var groupIconName: String {
        switch group {
        case .actions:   return "checkmark.circle.fill"
        case .ideas:     return "lightbulb.fill"
        case .keyPoints: return "star.fill"
        case .notes:     return "text.badge.plus"
        }
    }

    private var groupIconColor: Color {
        switch group {
        case .actions:   return Color.accentGold
        case .ideas:     return Color(hex: "#5DA6D8")
        case .keyPoints: return Color(hex: "#7B7FBE")
        case .notes:     return Color.inkMuted
        }
    }
}

// MARK: - BulletRowView
private struct BulletRowView: View {
    let bullet: String
    let accentColor: Color
    let isVisible: Bool
    @State private var copyFlash = false

    var body: AnyView {
        let row = HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(accentColor.opacity(0.85))
                .frame(width: 6, height: 6)
                .padding(.top, 6)
                .padding(.leading, 2)
            Text(bullet)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(.inkPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                UIPasteboard.general.string = "• \(bullet)"
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.18)) { copyFlash = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    withAnimation(.easeInOut(duration: 0.25)) { copyFlash = false }
                }
            } label: {
                Image(systemName: copyFlash ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(copyFlash ? accentColor : Color.inkMuted.opacity(0.4))
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
            .opacity(isVisible ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(bulletRowBackground)
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -12)
        return AnyView(row)
    }

    private var bulletRowBackground: some View {
        RoundedRectangle(cornerRadius: 9)
            .fill(accentColor.opacity(0.05))
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(accentColor.opacity(isVisible ? 0.18 : 0), lineWidth: 0.75)
            )
    }
}

// MARK: - BulletsToolbar
struct BulletsToolbarView: View {
    let result: BulletizedResult
    let onRevert: () -> Void
    @State private var copied = false

    var body: AnyView {
        let bar = HStack(spacing: 10) {
            bulletCountPillView
            Spacer()
            copyAllButtonView
            RevertToOriginalButton(action: onRevert)
        }
        return AnyView(bar)
    }

    private var bulletCountPillView: some View {
        HStack(spacing: 4) {
            Image(systemName: "list.bullet")
                .font(.system(size: 11, weight: .semibold))
            Text("\(result.allBullets.count) bullets")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.accentGold)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.accentGold.opacity(0.12))
                .overlay(Capsule().strokeBorder(Color.accentGold.opacity(0.3), lineWidth: 0.8))
        )
    }

    private var copyAllButtonView: some View {
        Button {
            UIPasteboard.general.string = result.plainText
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) { copied = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeInOut(duration: 0.3)) { copied = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11, weight: .medium))
                    .contentTransition(.opacity)
                Text(copied ? "Copied!" : "Copy all")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(copied ? .accentGold : .inkMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.inkMuted.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - RevertToOriginalButton
struct RevertToOriginalButton: View {
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .semibold))
                Text("Original")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
            }
            .foregroundColor(.inkMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.inkMuted.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ConversionShimmerView
struct ConversionShimmerView: View {
    @State private var shimmerPhase: CGFloat = 0.0
    private let rowWidths: [CGFloat] = [0.82, 0.65, 0.88, 0.70, 0.55, 0.78, 0.60]

    var body: AnyView {
        let v = VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(rowWidths.enumerated()), id: \.offset) { idx, widthRatio in
                ShimmerRowView(
                    widthRatio: widthRatio,
                    shimmerPhase: shimmerPhase,
                    opacity: 1.0 - Double(idx) * 0.08
                )
            }
        }
        .padding(.vertical, 6)
        .onAppear {
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                shimmerPhase = 1.0
            }
        }
        return AnyView(v)
    }
}

private struct ShimmerRowView: View {
    let widthRatio: CGFloat
    let shimmerPhase: CGFloat
    let opacity: Double

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.accentGold.opacity(0.15))
                .frame(width: 7, height: 7)
                .padding(.top, 1)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(shimmerGradient)
                    .frame(width: geo.size.width * widthRatio, height: 13)
            }
            .frame(height: 13)
        }
        .opacity(opacity)
    }

    private var shimmerGradient: LinearGradient {
        let lo = max(0.0, min(1.0, shimmerPhase - 0.35))
        let mid = max(lo, min(1.0, shimmerPhase))
        let hi = max(mid, min(1.0, shimmerPhase + 0.35))
        return LinearGradient(
            stops: [
                .init(color: Color.borderMuted.opacity(0.5), location: lo),
                .init(color: Color.accentGold.opacity(0.28), location: mid),
                .init(color: Color.borderMuted.opacity(0.5), location: hi)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
