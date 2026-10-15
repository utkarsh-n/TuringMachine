import SwiftUI

struct InstrumentBackdrop: View {
    let lighting: MotionLighting
    let reduceMotion: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var tiltX: Double { reduceMotion ? 0 : lighting.x }
    private var tiltY: Double { reduceMotion ? 0 : lighting.y }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.025, green: 0.045, blue: 0.070), Color(red: 0.018, green: 0.028, blue: 0.044), Color(red: 0.030, green: 0.045, blue: 0.060)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if !reduceTransparency {
                    RadialGradient(
                        colors: [Color(red: 0.15, green: 0.42, blue: 0.50).opacity(0.19), .clear],
                        center: UnitPoint(x: 0.75 + tiltX * 0.06, y: 0.19 + tiltY * 0.04),
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.95
                    )
                    RadialGradient(
                        colors: [Color(red: 0.55, green: 0.31, blue: 0.11).opacity(0.07), .clear],
                        center: UnitPoint(x: 0.1 - tiltX * 0.04, y: 0.62 - tiltY * 0.025),
                        startRadius: 0,
                        endRadius: geometry.size.width * 0.8
                    )
                }

                gridAndGrain
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var gridAndGrain: some View {
        Canvas { context, size in
            let spacing = 28.0
            var lines = Path()
            for x in stride(from: 0.0, through: size.width, by: spacing) {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: 0.0, through: size.height, by: spacing) {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(lines, with: .color(.white.opacity(0.018)), lineWidth: 0.5)

            // Fixed sampling keeps the surface stable across state changes.
            for index in 0..<280 {
                let value = Double(index)
                let x = (value * 73.0 + 19.0).truncatingRemainder(dividingBy: max(1, size.width))
                let y = (value * 137.0 + 43.0).truncatingRemainder(dividingBy: max(1, size.height))
                let isRegistrationMark = index.isMultiple(of: 37)
                let dot = Path(ellipseIn: CGRect(x: x, y: y, width: isRegistrationMark ? 1.2 : 0.6, height: isRegistrationMark ? 1.2 : 0.6))
                context.fill(dot, with: .color(.white.opacity(isRegistrationMark ? 0.09 : 0.028)))
            }
        }
    }
}
