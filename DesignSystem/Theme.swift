import SwiftUI
import UIKit

/// MIND BLOOM colour tokens. Each token has a light and a dark value and adapts
/// automatically. Accents were chosen so text on them meets WCAG AA contrast
/// when paired with `Theme.onAccent`.
enum Theme {
    // Surfaces
    static let canvas = Color(light: 0xF4F6F2, dark: 0x0D1416)
    static let surface = Color(light: 0xFFFFFF, dark: 0x162024)
    static let surfaceSunken = Color(light: 0xE9EEEA, dark: 0x1D2A2F)
    static let hairline = Color(light: 0xDCE3DF, dark: 0x26353A)

    // Text
    static let ink = Color(light: 0x1B2A30, dark: 0xE6EFEC)
    static let inkSecondary = Color(light: 0x56676D, dark: 0x9DB0B2)
    static let onAccent = Color(light: 0xFFFFFF, dark: 0x0D1416)

    // Brand accents
    static let teal = Color(light: 0x177E74, dark: 0x4CC7B5)
    static let mint = Color(light: 0x7FD4BC, dark: 0x5BBFA3)
    static let lavender = Color(light: 0x7B68C8, dark: 0xB4A6F2)
    static let lavenderMist = Color(light: 0xE8E3F8, dark: 0x2A2645)
    static let mintMist = Color(light: 0xDDF3EC, dark: 0x173A33)
    static let sky = Color(light: 0x4F8FC9, dark: 0x8DBDF0)
    static let sun = Color(light: 0xC98A1E, dark: 0xF0C36B)
    static let peach = Color(light: 0xD9775A, dark: 0xF2A88E)

    static let bloomGradient = LinearGradient(colors: [teal, lavender],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)
    static let mistGradient = LinearGradient(colors: [mintMist, lavenderMist],
                                             startPoint: .topLeading, endPoint: .bottomTrailing)

    // Layout rhythm
    static let cornerRadius: CGFloat = 24
    static let spacing: CGFloat = 16
    static let screenPadding: CGFloat = 20
    /// Content is width-limited on iPad so lines stay readable.
    static let maxContentWidth: CGFloat = 720
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

// MARK: - Semantic colours for domain types

extension Emotion {
    var tint: Color {
        switch valence {
        case 2: Theme.teal
        case 1: Theme.mint
        case 0: Theme.sun
        case -1: Theme.sky
        default: Theme.lavender
        }
    }
}

extension HabitTint {
    var color: Color {
        switch self {
        case .teal: Theme.teal
        case .mint: Theme.mint
        case .lavender: Theme.lavender
        case .sky: Theme.sky
        case .sun: Theme.sun
        case .peach: Theme.peach
        }
    }

    var name: String { rawValue.capitalized }
}

// MARK: - Typography (all based on text styles, so Dynamic Type scales them)

extension Font {
    static let bloomDisplay = Font.system(.largeTitle, design: .serif).weight(.semibold)
    static let bloomTitle = Font.system(.title2, design: .serif).weight(.semibold)
    static let bloomHeadline = Font.system(.headline, design: .rounded)
    static let bloomBody = Font.system(.body, design: .rounded)
    static let bloomCaption = Font.system(.caption, design: .rounded).weight(.medium)
    static let bloomNumber = Font.system(.title, design: .rounded).weight(.bold).monospacedDigit()
    static let bloomTimer = Font.system(size: 56, weight: .light, design: .rounded).monospacedDigit()
}

// MARK: - Motion preference

extension EnvironmentValues {
    /// True when the system "Reduce Motion" setting is on *or* the student chose
    /// "Calmer motion" in MIND BLOOM's settings. Views check this one value.
    @Entry var bloomReduceMotion: Bool = false
}
