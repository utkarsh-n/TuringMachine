import SwiftUI

enum MachineStyle {
    static let cyan = Color(red: 0.43, green: 0.91, blue: 0.94)
    static let amber = Color(red: 1, green: 0.76, blue: 0.42)
    static let ink = Color(red: 0.035, green: 0.055, blue: 0.085)
    static let surface = Color(red: 0.075, green: 0.10, blue: 0.14)
}

struct InstrumentCaption: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(.caption2, design: .monospaced, weight: .medium))
            .tracking(2)
            .foregroundStyle(.secondary)
    }
}

extension View {
    func instrumentPanel() -> some View {
        self.padding(16)
            .background(MachineStyle.surface.opacity(0.88), in: .rect(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.09)))
    }
}
