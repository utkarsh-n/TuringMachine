import SwiftUI
import TuringCore

struct ProgramLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    let programs: [MachineProgram]
    let selectedID: String
    let onSelect: (MachineProgram) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    WorkbenchHeading(
                        eyebrow: "Program library",
                        title: "Small rules. Real computation.",
                        detail: "Load a complete machine, then follow every read, write, move, and state change. The previews below use the same engine as the instrument."
                    )
                    ForEach(programs, id: \.id) { program in
                        ProgramLibraryCard(
                            program: program,
                            isSelected: selectedID == program.id
                        ) {
                            onSelect(program)
                            dismiss()
                        }
                    }
                }
                .padding(20)
            }
            .background(WorkbenchStyle.background)
            .navigationTitle("Machines")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    WorkbenchCloseButton(label: "Close machine library")
                }
            }
            .tint(WorkbenchStyle.accent)
        }
        .preferredColorScheme(.dark)
    }
}

private struct ProgramLibraryCard: View {
    let program: MachineProgram
    let isSelected: Bool
    let onSelect: () -> Void
    private let preview: ProgramResultPreview

    init(program: MachineProgram, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.program = program
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.preview = ProgramResultPreview(program: program)
    }

    var body: some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(program.name).font(.title3.bold())
                        Text(program.summary)
                            .foregroundStyle(WorkbenchStyle.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(WorkbenchStyle.accent)
                            .accessibilityLabel("Currently loaded")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    previewLine(label: "Input", value: preview.input)
                    previewLine(label: "Result", value: preview.output)
                    Text(preview.detail)
                        .font(.caption)
                        .foregroundStyle(WorkbenchStyle.secondary)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 14))

                DisclosureGroup("Why it works") {
                    Text(program.explanation)
                        .foregroundStyle(WorkbenchStyle.secondary)
                        .padding(.top, 8)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.subheadline)

                HStack {
                    Text("\(program.states.count) states · \(program.transitions.count) rules")
                        .font(.caption)
                        .foregroundStyle(WorkbenchStyle.secondary)
                    Spacer(minLength: 8)
                    Button(isSelected ? "Reload" : "Load", systemImage: "arrow.down.circle") { onSelect() }
                        .buttonStyle(.glass)
                        .accessibilityLabel("\(isSelected ? "Reload" : "Load") \(program.name)")
                }
            }
        }
        .overlay {
            if isSelected {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(WorkbenchStyle.accent.opacity(0.65), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }

    private func previewLine(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(1)
                .foregroundStyle(WorkbenchStyle.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.medium))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("\(label): \(value)")
        }
    }
}

private struct ProgramResultPreview {
    let input: String
    let output: String
    let detail: String

    init(program: MachineProgram) {
        input = program.initialTape.isEmpty ? "Blank tape (\(program.blank))" : program.initialTape.joined(separator: " ")
        do {
            var machine = try TuringMachine(program: program)
            for _ in 0..<512 {
                if machine.step() == nil { break }
            }
            let cells = machine.configuration.tape
            if let first = cells.keys.min(), let last = cells.keys.max() {
                let limit = first.addingReportingOverflow(47)
                let upper = limit.overflow ? last : min(last, limit.partialValue)
                output = (first...upper).map { machine.symbol(at: $0) }.joined(separator: " ") + (last > upper ? " …" : "")
            } else {
                output = "Blank tape (\(program.blank))"
            }
            let status: String
            switch machine.status {
            case .accepted: status = "Accepts"
            case .rejected: status = "Rejects"
            case .stuck: status = machine.statusDetail
            case .ready, .running: status = "Still running at preview limit"
            }
            detail = "\(status) · \(machine.configuration.steps) steps · nonblank tape span"
        } catch {
            output = "Invalid program"
            detail = error.localizedDescription
        }
    }
}
