import SwiftUI

/// A small optical surface only. The labels and native interactive glass stay in SwiftUI.
struct DialOpticsView: View {
    let lighting: MotionLighting
    let reduceMotion: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { geometry in
            if reduceTransparency {
                Circle().fill(Color(red: 0.035, green: 0.085, blue: 0.12))
            } else {
                Circle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.turingDialOptics(
                            .float2(geometry.size),
                            .float2(Float(reduceMotion ? 0 : lighting.x), Float(reduceMotion ? 0 : lighting.y))
                        )
                    )
            }
        }
        .clipShape(Circle())
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
