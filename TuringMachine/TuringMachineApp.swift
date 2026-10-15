import SwiftUI

@main
struct TuringMachineApp: App {
    var body: some Scene {
        WindowGroup {
            MachineView()
                .preferredColorScheme(.dark)
                .tint(MachineStyle.cyan)
        }
    }
}
