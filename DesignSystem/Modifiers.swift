import SwiftUI

/// Custom `ViewModifier`: the rounded, softly bordered card used across the app.
struct BloomCard: ViewModifier {
    var padding: CGFloat = Theme.spacing
    var tint: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay {
                        if let tint {
                            RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                                .fill(tint.opacity(0.08))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Theme.hairline, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }
}

/// Screen background: warm neutral canvas with two blurred colour "blooms".
struct BloomBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    Theme.canvas
                    Circle()
                        .fill(Theme.mint.opacity(0.18))
                        .frame(width: 320, height: 320)
                        .blur(radius: 80)
                        .offset(x: -140, y: -260)
                    Circle()
                        .fill(Theme.lavender.opacity(0.16))
                        .frame(width: 300, height: 300)
                        .blur(radius: 90)
                        .offset(x: 160, y: 220)
                }
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }
    }
}

/// Centres content and limits its width on iPad / landscape.
struct ReadableWidth: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: Theme.maxContentWidth)
            .frame(maxWidth: .infinity)
    }
}

extension View {
    func bloomCard(padding: CGFloat = Theme.spacing, tint: Color? = nil) -> some View {
        modifier(BloomCard(padding: padding, tint: tint))
    }

    func bloomBackground() -> some View { modifier(BloomBackground()) }

    func readableWidth() -> some View { modifier(ReadableWidth()) }
}

// MARK: - Button styles

struct BloomPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.bloomReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bloomHeadline)
            .foregroundStyle(Theme.onAccent)
            .padding(.vertical, 16)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(Capsule().fill(isEnabled ? AnyShapeStyle(Theme.bloomGradient) : AnyShapeStyle(Theme.inkSecondary.opacity(0.35))))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(reduceMotion ? nil : .spring(duration: 0.25), value: configuration.isPressed)
            .contentShape(Capsule())
    }
}

struct BloomSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bloomHeadline)
            .foregroundStyle(Theme.teal)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Theme.mintMist))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(Capsule())
    }
}

extension ButtonStyle where Self == BloomPrimaryButtonStyle {
    static var bloomPrimary: BloomPrimaryButtonStyle { BloomPrimaryButtonStyle() }
}

extension ButtonStyle where Self == BloomSecondaryButtonStyle {
    static var bloomSecondary: BloomSecondaryButtonStyle { BloomSecondaryButtonStyle() }
}
