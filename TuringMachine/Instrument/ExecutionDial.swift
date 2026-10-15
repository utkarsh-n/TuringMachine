import SwiftUI

/// A rotary speed control around a stationary, legible read-head lens.
struct ExecutionDial: View {
    @Binding var speed: Double
    let state: String
    let symbol: String
    let isRunning: Bool
    let progress: Double
    let lighting: MotionLighting
    let reduceMotion: Bool
    let hapticsEnabled: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @State private var lastDragAngle: Double?
    @State private var dragAngle = 0.0
    @State private var isDragging = false
    @State private var feedbackDetent = 0

    private let diameter: CGFloat = 216
    private let cyan = Color(red: 0.44, green: 0.92, blue: 1.0)
    private let amber = Color(red: 1.0, green: 0.74, blue: 0.36)
    private var tiltX: Double { reduceMotion ? 0 : lighting.x }
    private var tiltY: Double { reduceMotion ? 0 : lighting.y }
    private var dialAngle: Double { -140 + (min(12, max(1, speed)) - 1) / 11 * 280 }

    init(speed: Binding<Double>, state: String, symbol: String, isRunning: Bool, progress: Double, lighting: MotionLighting, reduceMotion: Bool, hapticsEnabled: Bool = true) {
        _speed = speed
        self.state = state
        self.symbol = symbol
        self.isRunning = isRunning
        self.progress = progress
        self.lighting = lighting
        self.reduceMotion = reduceMotion
        self.hapticsEnabled = hapticsEnabled
    }

    var body: some View {
        ZStack {
            housing
            scaleMarks
            runningTrace
            lens
            opticalRim
            speedIndicator
        }
        .frame(width: diameter, height: diameter)
        .contentShape(Circle())
        .gesture(rotaryGesture)
        .sensoryFeedback(.selection, trigger: feedbackDetent) { _, _ in hapticsEnabled }
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier("machine.dial")
        .accessibilityLabel("Execution speed dial")
        .accessibilityValue("\(speed.formatted(.number.precision(.fractionLength(0...1)))) transitions per second. State \(state). Reads \(symbol).")
        .accessibilityHint("Swipe up or down to adjust speed. Drag around the dial to turn it.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setSpeed(speed + 1)
            case .decrement: setSpeed(speed - 1)
            @unknown default: break
            }
        }
    }

    private var housing: some View {
        Circle()
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: Color(white: 0.36), location: 0),
                        .init(color: Color(white: 0.13), location: 0.25),
                        .init(color: Color(white: 0.04), location: 0.57),
                        .init(color: Color(white: 0.24), location: 0.9),
                        .init(color: Color(white: 0.08), location: 1)
                    ],
                    startPoint: UnitPoint(x: 0.05 + tiltX * 0.13, y: tiltY * 0.12),
                    endPoint: UnitPoint(x: 0.9 - tiltX * 0.13, y: 1 - tiltY * 0.12)
                )
            )
            .overlay {
                Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1)
                Circle().strokeBorder(.black.opacity(0.55), lineWidth: 3).padding(2)
                Circle().strokeBorder(.white.opacity(0.06), lineWidth: 1).padding(5)
            }
            .shadow(color: .black.opacity(0.65), radius: 20, x: 0, y: 12)
            .shadow(color: cyan.opacity(0.05), radius: 20, x: 0, y: 0)
    }

    private var scaleMarks: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            for index in 0...44 {
                let degrees = -140.0 + Double(index) / 44 * 280
                let radians = degrees * .pi / 180
                let major = index.isMultiple(of: 4)
                let outer = size.width / 2 - 11
                let inner = outer - (major ? 9 : 4)
                var tick = Path()
                tick.move(to: CGPoint(x: center.x + sin(radians) * inner, y: center.y - cos(radians) * inner))
                tick.addLine(to: CGPoint(x: center.x + sin(radians) * outer, y: center.y - cos(radians) * outer))
                let selected = degrees <= dialAngle
                context.stroke(tick, with: .color(selected ? cyan.opacity(major ? 0.83 : 0.36) : .white.opacity(major ? 0.45 : 0.15)), style: StrokeStyle(lineWidth: major ? 1.5 : 0.8, lineCap: .round))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var runningTrace: some View {
        Circle()
            .trim(from: 0, to: min(1, max(0, progress)))
            .stroke(cyan.opacity(isRunning ? 0.7 : 0.23), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .frame(width: 173, height: 173)
            .animation(reduceMotion ? nil : .linear(duration: 0.15), value: progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var lens: some View {
        ZStack {
            if reduceTransparency {
                Circle().fill(Color(red: 0.035, green: 0.085, blue: 0.12))
            } else {
                DialOpticsView(lighting: lighting, reduceMotion: reduceMotion)
            }
            // Information is a separate stationary plane above the optical model.
            lensContent
        }
        .frame(width: 162, height: 162)
        .modifier(DialGlassSurface(reduceTransparency: reduceTransparency, isPressed: isDragging))
        .overlay { Circle().strokeBorder(.white.opacity(0.10), lineWidth: 0.5) }
    }

    private var lensContent: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isRunning ? cyan : amber)
                    .frame(width: 4, height: 4)
                Text(isRunning ? "READ HEAD · LIVE" : "READ HEAD")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .tracking(1.5)
            }
            .foregroundStyle(.white.opacity(0.61))
            .padding(.bottom, 3)

            Text(state)
                .font(.system(size: 31, weight: .medium, design: .monospaced))
                .foregroundStyle(cyan)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
                .frame(maxWidth: 128)
                .contentTransition(.numericText())

            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("READS")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.55))
                Text(symbol)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            if differentiateWithoutColor {
                Text(isRunning ? "RUNNING" : "PAUSED")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                Rectangle()
                    .fill(.white.opacity(0.13))
                    .frame(width: 25, height: 1)
                    .padding(.top, 6)
            }
        }
        .accessibilityHidden(true)
    }

    private var opticalRim: some View {
        ZStack {
            Circle()
                .trim(from: 0.56, to: 0.89)
                .stroke(
                    LinearGradient(colors: [.clear, .white.opacity(0.65), .white.opacity(0.02)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 1, lineCap: .round)
                )
                .frame(width: 164, height: 164)
                .rotationEffect(.degrees(tiltX * 25 + tiltY * 12))
            if !reduceTransparency {
                Circle()
                    .trim(from: 0.035, to: 0.13)
                    .stroke(
                        AngularGradient(colors: [cyan.opacity(0.7), Color.purple.opacity(0.4), amber.opacity(0.7)], center: .center, startAngle: .degrees(12), endAngle: .degrees(47)),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round)
                    )
                    .frame(width: 165, height: 165)
                    .rotationEffect(.degrees(tiltX * -25 + tiltY * 10))
                    .opacity(0.7)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var speedIndicator: some View {
        ZStack {
            Capsule()
                .fill(cyan)
                .frame(width: 3, height: 10)
                .shadow(color: cyan.opacity(0.65), radius: 5)
                .offset(y: -92)
                .rotationEffect(.degrees(dialAngle))
            Text("TURN TO SET PACE")
                .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                .tracking(1.1)
                .foregroundStyle(.white.opacity(0.6))
                .offset(y: 93)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var rotaryGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let dx = value.location.x - diameter / 2
                let dy = value.location.y - diameter / 2
                // Near the center the angle becomes numerically unstable.
                guard hypot(dx, dy) >= 28 else { return }
                let angle = atan2(dx, -dy) * 180 / .pi
                if let previous = lastDragAngle {
                    var delta = angle - previous
                    if delta > 180 { delta -= 360 }
                    if delta < -180 { delta += 360 }
                    dragAngle = min(140, max(-140, dragAngle + delta))
                } else {
                    dragAngle = dialAngle
                    isDragging = true
                }
                lastDragAngle = angle
                setSpeed(1 + (dragAngle + 140) / 280 * 11)
            }
            .onEnded { _ in
                lastDragAngle = nil
                isDragging = false
            }
    }

    private func setSpeed(_ value: Double) {
        let bounded = min(12, max(1, value))
        speed = (bounded * 4).rounded() / 4
        feedbackDetent = Int(speed.rounded())
    }
}

private struct DialGlassSurface: ViewModifier {
    let reduceTransparency: Bool
    let isPressed: Bool

    func body(content: Content) -> some View {
        if reduceTransparency {
            content
                .overlay { Circle().strokeBorder(.white.opacity(isPressed ? 0.4 : 0.18), lineWidth: 1) }
        } else if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular.tint(.white.opacity(0.025)).interactive(), in: Circle())
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}
