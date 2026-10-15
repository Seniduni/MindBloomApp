import SwiftUI

/// Custom `Shape`: a single petal, pointed at the bottom and rounded at the top.
/// The MIND BLOOM logo and the Today "bloom" are built from rotated copies of it.
struct PetalShape: Shape {
    /// 0 = slim petal, 1 = full round petal.
    var fullness: CGFloat = 0.62

    var animatableData: CGFloat {
        get { fullness }
        set { fullness = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        let bulge = w * (0.5 + fullness * 0.45)
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.minY),
                      control1: CGPoint(x: rect.midX - bulge, y: rect.maxY - h * 0.35),
                      control2: CGPoint(x: rect.midX - w * 0.42, y: rect.minY))
        path.addCurve(to: CGPoint(x: rect.midX, y: rect.maxY),
                      control1: CGPoint(x: rect.midX + w * 0.42, y: rect.minY),
                      control2: CGPoint(x: rect.midX + bulge, y: rect.maxY - h * 0.35))
        path.closeSubpath()
        return path
    }
}

/// The MIND BLOOM mark: six petals around a soft core, in the teal→lavender gradient.
/// `openness` animates the petals unfolding (used on onboarding).
struct BloomLogo: View {
    var size: CGFloat = 64
    var openness: CGFloat = 1
    var petals = 6

    var body: some View {
        ZStack {
            ForEach(0..<petals, id: \.self) { index in
                PetalShape(fullness: 0.35 + 0.35 * openness)
                    .fill(index.isMultiple(of: 2) ? Theme.teal.gradient : Theme.lavender.gradient)
                    .opacity(0.88)
                    .frame(width: size * 0.34, height: size * 0.5)
                    .offset(y: -size * 0.25 * openness)
                    .rotationEffect(.degrees(Double(index) / Double(petals) * 360))
            }
            Circle()
                .fill(Theme.mint.gradient)
                .frame(width: size * 0.26, height: size * 0.26)
                .overlay(Circle().stroke(Theme.surface, lineWidth: size * 0.03))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 24) {
        BloomLogo(size: 120)
        BloomLogo(size: 120, openness: 0.3)
    }
    .padding()
}
