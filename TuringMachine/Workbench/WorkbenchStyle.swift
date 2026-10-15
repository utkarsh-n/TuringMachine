import SwiftUI

enum WorkbenchStyle {
    static let background = Color(red: 0.024, green: 0.059, blue: 0.098)
    static let panel = Color(red: 0.047, green: 0.11, blue: 0.17)
    static let accent = Color(red: 0.34, green: 0.91, blue: 0.96)
    static let secondary = Color(red: 0.64, green: 0.75, blue: 0.82)
    static let border = Color.white.opacity(0.12)
}

struct WorkbenchPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WorkbenchStyle.panel, in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(WorkbenchStyle.border, lineWidth: 1)
            }
    }
}

struct WorkbenchCloseButton: View {
    @Environment(\.dismiss) private var dismiss
    let label: String

    var body: some View {
        Button(label, systemImage: "xmark") { dismiss() }
            .labelStyle(.iconOnly)
            .accessibilityLabel(label)
    }
}

struct WorkbenchHeading: View {
    let eyebrow: String
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.semibold))
                .tracking(2)
                .foregroundStyle(WorkbenchStyle.accent)
            Text(title).font(.title.bold())
            Text(detail)
                .font(.body)
                .foregroundStyle(WorkbenchStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
