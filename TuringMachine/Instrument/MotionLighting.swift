import CoreMotion
import Observation

/// A bounded lighting direction. Motion changes reflections, never the machine's logic.
@MainActor
@Observable
final class MotionLighting {
    private(set) var x = 0.0
    private(set) var y = 0.0
    private(set) var isAvailable: Bool
    @ObservationIgnored private(set) var receivedSamples = 0

    @ObservationIgnored private let manager = CMMotionManager()
    @ObservationIgnored private let queue: OperationQueue
    @ObservationIgnored private var baselineX = 0.0
    @ObservationIgnored private var baselineY = 0.0
    @ObservationIgnored private var latestX = 0.0
    @ObservationIgnored private var latestY = 0.0
    @ObservationIgnored private var hasBaseline = false
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var active = false

    init() {
        isAvailable = manager.isDeviceMotionAvailable
        queue = OperationQueue()
        queue.name = "TuringMachine.motion-lighting"
        queue.qualityOfService = .userInteractive
        queue.maxConcurrentOperationCount = 1
    }

    func start() {
        guard !active, manager.isDeviceMotionAvailable else { return }
        isAvailable = true
        active = true
        receivedSamples = 0
        hasBaseline = false
        generation += 1
        let currentGeneration = generation
        manager.deviceMotionUpdateInterval = 1.0 / 30.0
        manager.startDeviceMotionUpdates(using: .xArbitraryZVertical, to: queue) { @Sendable [weak self] motion, error in
            // Core Motion's legacy handler typedef isn't annotated Sendable.
            // Explicitly making this closure Sendable prevents it inheriting
            // MainActor isolation while Core Motion executes it on our queue.
            // Extract scalar values before the deliberate hop to MainActor.
            let gravityX = motion?.gravity.x
            let gravityY = motion?.gravity.y
            let failed = error != nil
            Task { @MainActor [weak self] in
                guard let self, self.active, self.generation == currentGeneration else { return }
                if failed {
                    self.stop()
                    self.isAvailable = false
                    return
                }
                guard let gravityX, let gravityY else { return }
                self.receive(gravityX: gravityX, gravityY: gravityY)
            }
        }
    }

    func stop() {
        active = false
        generation += 1
        manager.stopDeviceMotionUpdates()
        x = 0
        y = 0
    }

    /// Make the current holding angle the optical center, without changing execution.
    func calibrate() {
        baselineX = latestX
        baselineY = latestY
        hasBaseline = true
        x = 0
        y = 0
    }

    private func receive(gravityX: Double, gravityY: Double) {
        receivedSamples += 1
        latestX = gravityX
        latestY = gravityY
        if !hasBaseline {
            baselineX = gravityX
            baselineY = gravityY
            hasBaseline = true
        }
        let targetX = min(1, max(-1, (gravityX - baselineX) * 2.2))
        let targetY = min(1, max(-1, -(gravityY - baselineY) * 2.2))
        let filteredX = x + (targetX - x) * 0.16
        let filteredY = y + (targetY - y) * 0.16
        // Sub-pixel jitter does not need to invalidate the instrument at 30 Hz.
        if abs(filteredX - x) > 0.001 { x = filteredX }
        if abs(filteredY - y) > 0.001 { y = filteredY }
    }
}
