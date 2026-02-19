import SwiftUI

// MARK: - Theme Definition
struct VaultedTheme {
    let name: String
    let icon: String
    let paperBackground: Color
    let cardSurface: Color
    let borderMuted: Color
    let inkPrimary: Color
    let inkMuted: Color
    let accentGold: Color
    let lockedBrown: Color
    let drawerHandle: Color
    let isDark: Bool
}

// MARK: - App Themes
enum AppThemeStyle: String, CaseIterable, Identifiable {
    case parchment = "Parchment"
    case midnight  = "Midnight"
    case forest    = "Forest"
    case rose      = "Rose"
    case slate     = "Slate"

    var id: String { rawValue }

    var theme: VaultedTheme {
        switch self {
        case .parchment:
            return VaultedTheme(
                name: "Parchment",
                icon: "scroll",
                paperBackground: Color(hex: "#F6F1E7"),
                cardSurface:     Color(hex: "#FCF9F3"),
                borderMuted:     Color(hex: "#D6CAB7"),
                inkPrimary:      Color(hex: "#211E1C"),
                inkMuted:        Color(hex: "#70675E"),
                accentGold:      Color(hex: "#C49245"),
                lockedBrown:     Color(hex: "#7B5C3A"),
                drawerHandle:    Color(hex: "#A8946F"),
                isDark: false
            )
        case .midnight:
            return VaultedTheme(
                name: "Midnight",
                icon: "moon.stars.fill",
                paperBackground: Color(hex: "#0A0E14"),
                cardSurface:     Color(hex: "#131920"),
                borderMuted:     Color(hex: "#2B333D"),
                inkPrimary:      Color(hex: "#E8EDF4"),
                inkMuted:        Color(hex: "#7D8A9A"),
                accentGold:      Color(hex: "#5C9EFF"),
                lockedBrown:     Color(hex: "#364559"),
                drawerHandle:    Color(hex: "#4A9EFF"),
                isDark: true
            )
        case .forest:
            return VaultedTheme(
                name: "Forest",
                icon: "leaf.fill",
                paperBackground: Color(hex: "#0B1612"),
                cardSurface:     Color(hex: "#132118"),
                borderMuted:     Color(hex: "#2A4538"),
                inkPrimary:      Color(hex: "#D8ECD4"),
                inkMuted:        Color(hex: "#6B9B7A"),
                accentGold:      Color(hex: "#4DD68C"),
                lockedBrown:     Color(hex: "#2E5240"),
                drawerHandle:    Color(hex: "#52C78A"),
                isDark: true
            )
        case .rose:
            return VaultedTheme(
                name: "Rose",
                icon: "heart.fill",
                paperBackground: Color(hex: "#FCE8EC"),
                cardSurface:     Color(hex: "#FFF5F7"),
                borderMuted:     Color(hex: "#E4BCC6"),
                inkPrimary:      Color(hex: "#2A1820"),
                inkMuted:        Color(hex: "#7D5A66"),
                accentGold:      Color(hex: "#B84D6A"),
                lockedBrown:     Color(hex: "#6E3348"),
                drawerHandle:    Color(hex: "#C96A82"),
                isDark: false
            )
        case .slate:
            return VaultedTheme(
                name: "Slate",
                icon: "cloud.fill",
                paperBackground: Color(hex: "#161A20"),
                cardSurface:     Color(hex: "#1E232B"),
                borderMuted:     Color(hex: "#363D48"),
                inkPrimary:      Color(hex: "#E8EAEF"),
                inkMuted:        Color(hex: "#7A8498"),
                accentGold:      Color(hex: "#9B7DF5"),
                lockedBrown:     Color(hex: "#453A65"),
                drawerHandle:    Color(hex: "#8B73E8"),
                isDark: true
            )
        }
    }
}

// MARK: - ThemeManager
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @Published var current: AppThemeStyle {
        didSet { UserDefaults.standard.set(current.rawValue, forKey: "Vaulted.theme") }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "Vaulted.theme") ?? ""
        current = AppThemeStyle(rawValue: saved) ?? .parchment
    }

    var theme: VaultedTheme { current.theme }
}

// MARK: - Color Palette (theme-aware)
extension Color {
    static var paperBackground: Color { ThemeManager.shared.theme.paperBackground }
    static var cardSurface:     Color { ThemeManager.shared.theme.cardSurface }
    static var borderMuted:     Color { ThemeManager.shared.theme.borderMuted }
    static var inkPrimary:      Color { ThemeManager.shared.theme.inkPrimary }
    static var inkMuted:        Color { ThemeManager.shared.theme.inkMuted }
    static var accentGold:      Color { ThemeManager.shared.theme.accentGold }
    static var lockedBrown:     Color { ThemeManager.shared.theme.lockedBrown }
    static var drawerHandle:    Color { ThemeManager.shared.theme.drawerHandle }

    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 3: (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:(a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:     Double(r) / 255,
                  green:   Double(g) / 255,
                  blue:    Double(b) / 255,
                  opacity: Double(a) / 255)
    }

    static func hex(_ string: String) -> Color { Color(hex: string) }
}

// MARK: - Typography
extension Font {
    static let catalogTitle = Font.system(.title2,     design: .serif).weight(.bold)
    static let drawerLabel  = Font.system(.title3,     design: .serif).weight(.semibold)
    static let cardTitle    = Font.system(.headline,   design: .serif)
    static let cardBody     = Font.system(.body,       design: .serif)
    static let cardSnippet  = Font.system(.subheadline,design: .serif)
    static let cardCaption  = Font.system(.caption,    design: .monospaced)
    static let tagChip      = Font.system(size: 11, weight: .medium, design: .rounded)
}

// MARK: - Grain overlay
struct GrainOverlay: View {
    var body: some View {
        Rectangle()
            .fill(ImagePaint(image: Image(systemName: "circle.fill"), scale: 0.003))
            .opacity(0.03)
            .blendMode(.multiply)
            .allowsHitTesting(false)
    }
}

// MARK: - Card container
struct VaultCardBackground: ViewModifier {
    @ObservedObject var themeManager = ThemeManager.shared
    func body(content: Content) -> some View {
        content
            .background(themeManager.theme.cardSurface)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(themeManager.theme.borderMuted, lineWidth: 1))
            .cornerRadius(6)
            .shadow(color: themeManager.theme.inkPrimary.opacity(0.08), radius: 4, x: 0, y: 2)
    }
}

extension View {
    func vaultCard() -> some View { modifier(VaultCardBackground()) }
}

// MARK: - Tag chip
struct TagChip: View {
    let label: String
    @ObservedObject var themeManager = ThemeManager.shared
    var body: some View {
        Text(label)
            .font(.tagChip)
            .foregroundColor(themeManager.theme.accentGold)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(themeManager.theme.accentGold.opacity(0.12))
            .overlay(Capsule().stroke(themeManager.theme.accentGold.opacity(0.4), lineWidth: 1))
            .clipShape(Capsule())
    }
}
