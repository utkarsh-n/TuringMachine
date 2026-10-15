import UIKit
import AudioToolbox
import TuringCore

@MainActor
final class MachineFeedback {
    private let impact = UIImpactFeedbackGenerator(style: .light)
    private let selector = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    func selection(enabled: Bool) {
        if enabled { selector.selectionChanged() }
    }
    func step(direction: HeadMove, outcome: MachineStatus, haptics: Bool, sound: Bool) {
        if haptics {
            switch outcome {
            case .accepted: notification.notificationOccurred(.success)
            case .rejected: notification.notificationOccurred(.error)
            case .stuck: notification.notificationOccurred(.warning)
            case .ready, .running: impact.impactOccurred(intensity: direction == .left ? 0.5 : 0.7)
            }
        }
        if sound { AudioServicesPlaySystemSound(1104) }
    }
}
