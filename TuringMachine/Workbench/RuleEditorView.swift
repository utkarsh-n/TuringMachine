import SwiftUI
import TuringCore

struct RuleEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: MachineDraft
    @State private var errorMessage: String?
    @State private var showsError = false
    let onSave: (MachineProgram) -> Void

    init(program: MachineProgram, onSave: @escaping (MachineProgram) -> Void) {
        _draft = State(initialValue: MachineDraft(program: program))
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        Label {
                            Text(errorMessage).fixedSize(horizontal: false, vertical: true)
                        } icon: {
                            Image(systemName: "exclamationmark.triangle.fill")
                        }
                        .foregroundStyle(.orange)
                        .accessibilityLabel("Cannot save: \(errorMessage)")
                    } header: {
                        Text("Check the machine")
                    }
                }
                identitySection
                alphabetsSection
                statesSection
                tapeSection
                rulesSection
                Section("Explanation") {
                    TextEditor(text: $draft.explanation)
                        .frame(minHeight: 130)
                        .accessibilityLabel("Explanation of this machine")
                }
            }
            .scrollContentBackground(.hidden)
            .background(WorkbenchStyle.background)
            .navigationTitle("Machine editor")
            .navigationBarTitleDisplayMode(.inline)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", systemImage: "checkmark") { save() }
                        .fontWeight(.semibold)
                }
            }
            .tint(WorkbenchStyle.accent)
            .alert("Check the machine", isPresented: $showsError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "The program could not be saved.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var identitySection: some View {
        Section {
            TextField("Name", text: $draft.name)
            TextField("Summary", text: $draft.summary, axis: .vertical)
                .lineLimit(2...5)
        } header: {
            Text("Custom machine")
        } footer: {
            Text("Saving creates a new custom program. All rules and initial conditions below become part of it.")
        }
    }

    private var alphabetsSection: some View {
        Section {
            LabeledContent("Q · states") {
                TextField("q0, q1, accept, reject", text: $draft.states, axis: .vertical)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Σ · input symbols") {
                TextField("0, 1", text: $draft.inputAlphabet, axis: .vertical)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Γ · tape symbols") {
                TextField("0, 1, □", text: $draft.tapeAlphabet, axis: .vertical)
                    .multilineTextAlignment(.trailing)
            }
            LabeledContent("Blank symbol") {
                TextField("□", text: $draft.blank)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("States & alphabets")
        } footer: {
            Text("Separate values with commas. The tape alphabet includes every input symbol and the blank; the input alphabet excludes the blank. Quote a value containing a comma, such as \",\". To use a space as the blank, type \" \" in both the alphabet and blank field.")
        }
    }

    private var statesSection: some View {
        Section("Control states") {
            LabeledContent("Initial · q₀") {
                TextField("q0", text: $draft.initialState).multilineTextAlignment(.trailing)
            }
            LabeledContent("Accept · q_accept") {
                TextField("accept", text: $draft.acceptState).multilineTextAlignment(.trailing)
            }
            LabeledContent("Reject · q_reject") {
                TextField("reject", text: $draft.rejectState).multilineTextAlignment(.trailing)
            }
        }
    }

    private var tapeSection: some View {
        Section {
            TextField("Initial input", text: $draft.input, axis: .vertical)
                .font(.system(.body, design: .monospaced))
                .lineLimit(2...6)
                .accessibilityLabel("Initial input symbols")
            LabeledContent("Head position") {
                TextField("0", text: $draft.initialHead)
                    .keyboardType(.numbersAndPunctuation)
                    .multilineTextAlignment(.trailing)
            }
        } header: {
            Text("Initial tape")
        } footer: {
            Text("Input starts at cell 0. Separate symbols with spaces, or type a sequence such as 1011 for a single-character alphabet. An empty input means blank tape. The head may start at a negative cell.")
        }
    }

    private var rulesSection: some View {
        Section {
            Text("state  read  →  write  L/R  nextState")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(WorkbenchStyle.accent)
                .fixedSize(horizontal: false, vertical: true)
            TextEditor(text: $draft.rules)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 280)
                .accessibilityLabel("Transition rules. One rule per line.")
            Button("Add transition line", systemImage: "plus") {
                let state = (try? RuleDraftCodec.parseScalar(draft.initialState, field: "Initial state")) ?? draft.initialState
                let blank = (try? RuleDraftCodec.parseScalar(draft.blank, field: "Blank symbol")) ?? draft.blank
                let accept = (try? RuleDraftCodec.parseScalar(draft.acceptState, field: "Accept state")) ?? draft.acceptState
                let rule = "\(RuleDraftCodec.quote(state)) \(RuleDraftCodec.quote(blank)) → \(RuleDraftCodec.quote(blank)) R \(RuleDraftCodec.quote(accept))"
                draft.rules += (draft.rules.isEmpty || draft.rules.hasSuffix("\n") ? "" : "\n") + rule
            }
        } header: {
            Text("Transition function · δ")
        } footer: {
            Text("One rule per line. Example: q0 0 → 1 R q0. Use L or R; either → or -> is accepted. Edit or delete any line to change a rule. Each (state, read) pair must appear only once. Quote a value containing spaces or quotes.")
        }
    }

    private func save() {
        do {
            let program = try draft.makeProgram()
            _ = try TuringMachine(program: program)
            errorMessage = nil
            onSave(program)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showsError = true
        }
    }
}

private struct MachineDraft {
    var source: MachineProgram
    var name: String
    var summary: String
    var states: String
    var inputAlphabet: String
    var tapeAlphabet: String
    var blank: String
    var initialState: String
    var acceptState: String
    var rejectState: String
    var input: String
    var initialHead: String
    var rules: String
    var explanation: String

    init(program: MachineProgram) {
        source = program
        name = program.name + " · custom"
        summary = program.summary
        states = CommaDraftCodec.encode(program.states)
        inputAlphabet = CommaDraftCodec.encode(program.inputAlphabet)
        tapeAlphabet = CommaDraftCodec.encode(program.tapeAlphabet)
        blank = RuleDraftCodec.quote(program.blank)
        initialState = RuleDraftCodec.quote(program.initialState)
        acceptState = RuleDraftCodec.quote(program.acceptState)
        rejectState = RuleDraftCodec.quote(program.rejectState)
        input = RuleDraftCodec.formatWord(program.initialTape, alphabet: program.inputAlphabet)
        initialHead = String(program.initialHead)
        rules = RuleDraftCodec.encode(program.transitions)
        explanation = program.explanation
    }

    func makeProgram() throws -> MachineProgram {
        var result = source
        result.id = "custom-" + UUID().uuidString
        result.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.name.isEmpty else { throw DraftParseError("Give the machine a name.") }
        result.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        result.states = try CommaDraftCodec.decode(states, field: "Q · states")
        result.inputAlphabet = try CommaDraftCodec.decode(inputAlphabet, field: "Σ · input alphabet")
        result.tapeAlphabet = try CommaDraftCodec.decode(tapeAlphabet, field: "Γ · tape alphabet")
        result.blank = try RuleDraftCodec.parseScalar(blank, field: "Blank symbol")
        result.initialState = try RuleDraftCodec.parseScalar(initialState, field: "Initial state")
        result.acceptState = try RuleDraftCodec.parseScalar(acceptState, field: "Accept state")
        result.rejectState = try RuleDraftCodec.parseScalar(rejectState, field: "Reject state")
        guard let head = Int(initialHead.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            throw DraftParseError("Head position must be a whole number, such as 0 or −3.")
        }
        result.initialHead = head
        result.initialTape = try RuleDraftCodec.parseWord(input, alphabet: result.inputAlphabet)
        result.transitions = try RuleDraftCodec.decode(rules)
        result.explanation = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        return result
    }
}
