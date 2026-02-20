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
                paperBackground: Color(hex: "#0D1117"),
                cardSurface:     Color(hex: "#161B22"),
                borderMuted:     Color(hex: "#30363D"),
                inkPrimary:      Color(hex: "#F0F3F6"),
                inkMuted:        Color(hex: "#8B949E"),
                accentGold:      Color(hex: "#58A6FF"),
                lockedBrown:     Color(hex: "#21262D"),
                drawerHandle:    Color(hex: "#6CB6FF"),
                isDark: true
            )
        case .forest:
            return VaultedTheme(
                name: "Forest",
                icon: "leaf.fill",
                paperBackground: Color(hex: "#0F1A14"),
                cardSurface:     Color(hex: "#16231C"),
                borderMuted:     Color(hex: "#2D4A3A"),
                inkPrimary:      Color(hex: "#E0F2E4"),
                inkMuted:        Color(hex: "#7FA68A"),
                accentGold:      Color(hex: "#56C896"),
                lockedBrown:     Color(hex: "#1E3A2B"),
                drawerHandle:    Color(hex: "#6DD4A3"),
                isDark: true
            )
        case .rose:
            return VaultedTheme(
                name: "Rose",
                icon: "heart.fill",
                paperBackground: Color(hex: "#FDF2F5"),
                cardSurface:     Color(hex: "#FFFBFD"),
                borderMuted:     Color(hex: "#E8D1D8"),
                inkPrimary:      Color(hex: "#2D1B22"),
                inkMuted:        Color(hex: "#8B6B77"),
                accentGold:      Color(hex: "#D94A6B"),
                lockedBrown:     Color(hex: "#B87A8F"),
                drawerHandle:    Color(hex: "#E06B8A"),
                isDark: false
            )
        case .slate:
            return VaultedTheme(
                name: "Slate",
                icon: "cloud.fill",
                paperBackground: Color(hex: "#1A1D24"),
                cardSurface:     Color(hex: "#23262E"),
                borderMuted:     Color(hex: "#3A3F4A"),
                inkPrimary:      Color(hex: "#E8EAED"),
                inkMuted:        Color(hex: "#8B9199"),
                accentGold:      Color(hex: "#A78BFA"),
                lockedBrown:     Color(hex: "#2D2F3A"),
                drawerHandle:    Color(hex: "#B89DFB"),
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
