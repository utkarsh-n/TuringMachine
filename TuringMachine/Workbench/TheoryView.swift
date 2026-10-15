import SwiftUI
import TuringCore

struct TheoryView: View {
    let program: MachineProgram
    @State private var part = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    WorkbenchHeading(
                        eyebrow: "The logical machine",
                        title: "A computer, reduced to its essentials.",
                        detail: "An ideal Turing machine has a tape, one read/write head, and a finite table of rules. This instrument executes those rules exactly. Its dial sets the pace; its lighting follows your phone."
                    )
                    tuplePanel
                    AtomicTransitionLesson(program: program, part: $part)
                    explanationPanel(
                        title: "The tape extends both ways",
                        symbol: "arrow.left.and.right",
                        text: "Cells have integer addresses: … −2, −1, 0, 1, 2 … . Unwritten cells contain the blank symbol \(program.blank). Only nonblank cells need storage. Moving off the visible strip reveals more tape; the screen edge is never a logical boundary."
                    )
                    explanationPanel(
                        title: "One rule, one atomic step",
                        symbol: "arrow.trianglehead.2.clockwise.rotate.90",
                        text: "The engine reads the current symbol and state, finds δ(q, s), then commits the write, one-cell L/R move, and next state together. There is no stay-put movement. The visual phases help you follow that single indivisible update."
                    )
                    explanationPanel(
                        title: "Three distinct stopping conditions",
                        symbol: "stop.circle",
                        text: "Entering \(program.acceptState) accepts. Entering \(program.rejectState) rejects. If no rule matches the current state and symbol, the machine becomes stuck; that is neither acceptance nor rejection. Pausing or reaching a run budget also makes no claim that the mathematical machine halts."
                    )
                    explanationPanel(
                        title: "Exact logic, finite hardware",
                        symbol: "memorychip",
                        text: "The mathematical tape is bi-infinite and execution may continue forever. A phone has finite memory and a finite integer address range. This app stores a sparse tape and retains at most 4,096 undo records. Those engineering limits do not change the transition rules, but the phone cannot represent an actually infinite tape or run."
                    )
                    explanationPanel(
                        title: "The instrument does not alter the program",
                        symbol: "gyroscope",
                        text: "Phone movement changes the optical presentation. It never chooses a rule, modifies a symbol, or changes the state. A program started with the same tape and head position produces the same execution sequence at every dial speed."
                    )
                }
                .padding(20)
            }
            .background(WorkbenchStyle.background)
            .navigationTitle("How it works")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    WorkbenchCloseButton(label: "Close machine theory")
                }
            }
            .tint(WorkbenchStyle.accent)
        }
        .preferredColorScheme(.dark)
    }

    private var tuplePanel: some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("M = (Q, Σ, Γ, δ, q₀, q_accept, q_reject)")
                    .font(.system(.body, design: .monospaced).weight(.semibold))
                    .foregroundStyle(WorkbenchStyle.accent)
                    .fixedSize(horizontal: false, vertical: true)
                tupleLine("Q", meaning: "Finite states", value: set(program.states))
                tupleLine("Σ", meaning: "Input alphabet", value: set(program.inputAlphabet))
                tupleLine("Γ", meaning: "Tape alphabet", value: set(program.tapeAlphabet))
                tupleLine("δ", meaning: "Partial transition function", value: "Q × Γ ⇀ Q × Γ × {L, R}; \(program.transitions.count) rules")
                tupleLine("q₀", meaning: "Initial state", value: program.initialState)
                tupleLine("q_accept", meaning: "Accepting state", value: program.acceptState)
                tupleLine("q_reject", meaning: "Rejecting state", value: program.rejectState)
                Text("Distinguished blank: \(program.blank) ∈ Γ, and \(program.blank) ∉ Σ.")
                    .font(.subheadline)
                    .foregroundStyle(WorkbenchStyle.secondary)
            }
        }
    }

    private func set(_ values: [String]) -> String {
        "{ " + values.joined(separator: ", ") + " }"
    }

    private func tupleLine(_ symbol: String, meaning: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(symbol) · \(meaning)")
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(WorkbenchStyle.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func explanationPanel(title: String, symbol: String, text: String) -> some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 12) {
                Label(title, systemImage: symbol)
                    .font(.headline)
                    .foregroundStyle(WorkbenchStyle.accent)
                Text(text)
                    .foregroundStyle(WorkbenchStyle.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct AtomicTransitionLesson: View {
    let program: MachineProgram
    @Binding var part: Int

    private var readSymbol: String {
        program.initialTape.indices.contains(program.initialHead) ? program.initialTape[program.initialHead] : program.blank
    }

    private var rule: TuringCore.Transition? {
        program.transitions.first { $0.state == program.initialState && $0.read == readSymbol }
    }

    var body: some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 16) {
                Text("Inspect the first transition").font(.title3.bold())
                if let rule {
                    HStack(spacing: 8) {
                        ForEach(0..<4) { index in
                            Text(String(index + 1))
                                .font(.system(.body, design: .monospaced).weight(.bold))
                                .frame(minWidth: 44, minHeight: 44)
                                .background(index == part ? WorkbenchStyle.accent : Color.white.opacity(0.07), in: Circle())
                                .foregroundStyle(index == part ? WorkbenchStyle.background : Color.white)
                        }
                    }
                    .accessibilityHidden(true)
                    Text(lessonText(rule))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("theory.atomicPart")
                    Text("These are the parts of one atomic update. This lesson does not execute the instrument.")
                        .font(.caption)
                        .foregroundStyle(WorkbenchStyle.secondary)
                    Button(part == 3 ? "Replay inspection" : "Inspect next part", systemImage: part == 3 ? "arrow.counterclockwise" : "arrow.right") {
                        part = (part + 1) % 4
                    }
                    .buttonStyle(.glass)
                } else {
                    Text("Initial state \(program.initialState), cell \(program.initialHead), symbol \(readSymbol): no matching rule.")
                        .font(.system(.body, design: .monospaced))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("A terminal initial state halts immediately; otherwise this configuration is stuck.")
                        .foregroundStyle(WorkbenchStyle.secondary)
                }
            }
        }
    }

    private func lessonText(_ rule: TuringCore.Transition) -> String {
        switch part {
        case 0: return "1 · Read \(rule.read) at cell \(program.initialHead) while in state \(rule.state). That pair selects the rule."
        case 1: return "2 · Write \(rule.write) into cell \(program.initialHead), replacing \(rule.read). Every other tape cell stays as it was."
        case 2:
            let next = program.initialHead.addingReportingOverflow(rule.move == .left ? -1 : 1)
            if next.overflow {
                return "3 · This movement would exceed the phone's integer coordinate range. The engine reports the limit and leaves the whole configuration unchanged."
            }
            return "3 · Move the head one cell \(rule.move == .left ? "left" : "right"), from \(program.initialHead) to \(next.partialValue)."
        default:
            if rule.nextState == program.acceptState {
                return "4 · Enter state \(rule.nextState). The machine accepts immediately; no further transition executes."
            }
            if rule.nextState == program.rejectState {
                return "4 · Enter state \(rule.nextState). The machine rejects immediately; no further transition executes."
            }
            return "4 · Enter state \(rule.nextState). The next step looks for a rule at the new head position using this new state."
        }
    }
}
