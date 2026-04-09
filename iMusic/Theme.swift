import SwiftUI

enum Theme {
    static let bg0 = Color(hex: "#0a0a10")
    static let bg1 = Color(hex: "#0d0d14")
    static let bg2 = Color(hex: "#13131c")
    static let bg3 = Color(hex: "#1a1a26")
    static let surface = Color(hex: "#16161f")
    static let surfaceElevated = Color(hex: "#1e1e2a")
    static let border = Color(hex: "#2a2a3a")
    static let borderSubtle = Color(hex: "#1e1e2c")

    static let accent = Color(hex: "#9d6fd4")
    static let accentBright = Color(hex: "#c084fc")
    static let accentDim = Color(hex: "#7B5EA7")
    static let accentGlow = Color(hex: "#9d6fd4").opacity(0.15)

    static let textPrimary = Color.white
    static let textSecondary = Color(hex: "#a0a0b8")
    static let textTertiary = Color(hex: "#606078")

    static let success = Color(hex: "#4ade80")
    static let danger = Color(hex: "#f87171")
    static let warning = Color(hex: "#fb923c")

    static let cornerSm: CGFloat = 8
    static let cornerMd: CGFloat = 12
    static let cornerLg: CGFloat = 16
    static let cornerXl: CGFloat = 20

    static let shadowAccent = Color(hex: "#9d6fd4").opacity(0.3)
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

extension View {
    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.surface)
            .cornerRadius(Theme.cornerMd)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerMd)
                    .stroke(Theme.border, lineWidth: 0.5)
            )
    }

    func glowEffect(color: Color = Theme.accent, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.4), radius: radius)
    }
}
