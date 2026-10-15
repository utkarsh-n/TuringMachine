import SwiftUI
import TuringCore

struct TapeSelection: Identifiable {
    let position: Int
    var id: Int { position }
}

struct TapeView: View {
    let head: Int
    let readSymbol: (Int) -> String
    @Binding var focus: Int?
    let reduceMotion: Bool
    let onSelect: (Int) -> Void
    let onInput: () -> Void
    @State private var drag: Double = 0

    private var center: Int { focus ?? head }
    private var positions: [Int] {
        (-5...5).compactMap { offset in
            let (value, overflow) = center.addingReportingOverflow(offset)
            return overflow ? nil : value
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                InstrumentCaption(text: "The tape / Γ")
                Spacer()
                Button("Input", systemImage: "square.and.pencil", action: onInput)
                    .font(.caption).frame(minHeight: 44).buttonStyle(.borderless)
                    .accessibilityIdentifier("machine.input")
            }
            GeometryReader { geometry in
                ZStack {
                    HStack(spacing: 6) {
                        ForEach(positions, id: \.self) { position in
                            cell(position)
                        }
                    }
                    .fixedSize(horizontal: true, vertical: false)
                    .offset(x: drag)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.06),
                                                  .init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                                         startPoint: .leading, endPoint: .trailing))
                }
                .contentShape(Rectangle())
                .simultaneousGesture(DragGesture(minimumDistance: 16)
                    .onChanged { drag = max(-150, min(150, $0.translation.width)) }
                    .onEnded { value in
                        let amount = Int((-value.translation.width / 50).rounded())
                        let (destination, overflow) = center.addingReportingOverflow(amount)
                        if !overflow { focus = destination }
                        drag = 0
                    })
            }
            .frame(height: 82)
            HStack {
                if focus != nil {
                    Text("Exploring cell \(center)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Follow head") { focus = nil }
                        .font(.caption2).frame(minHeight: 44)
                        .accessibilityIdentifier("tape.follow")
                } else {
                    Text("← swipe to explore · tap a cell to edit →")
                        .font(.caption2).foregroundStyle(.secondary).frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 14).padding(.bottom, 12)
        .background(MachineStyle.surface.opacity(0.7), in: .rect(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(.white.opacity(0.08)))
        .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: head)
    }

    private func cell(_ position: Int) -> some View {
        let isHead = position == head
        return VStack(spacing: 5) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 9)).foregroundStyle(isHead ? MachineStyle.cyan : .clear)
                .accessibilityHidden(true)
            Button { onSelect(position) } label: {
                Text(readSymbol(position))
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .lineLimit(1).minimumScaleFactor(0.25)
                    .foregroundStyle(isHead ? MachineStyle.cyan : .white.opacity(0.9))
                    .frame(width: 44, height: 48)
                    .background(isHead ? MachineStyle.cyan.opacity(0.13) : .white.opacity(0.035), in: .rect(cornerRadius: 9))
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(isHead ? MachineStyle.cyan.opacity(0.8) : .white.opacity(0.12), lineWidth: isHead ? 1.5 : 1))
                    .shadow(color: isHead ? MachineStyle.cyan.opacity(0.13) : .clear, radius: 8)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tape cell \(position), \(readSymbol(position))\(isHead ? ", under the head" : "")")
            .accessibilityHint("Edit this symbol or place the read head here")
            .accessibilityIdentifier("tape.cell.\(position)")
            Text(position.formatted()).font(.system(.caption2, design: .monospaced))
                .foregroundStyle(isHead ? MachineStyle.cyan : .secondary)
        }
    }
}

struct TapeCellEditor: View {
    let position: Int
    let symbol: String
    let alphabet: [String]
    let isHead: Bool
    let onWrite: (String) -> Void
    let onPlaceHead: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Write a symbol from Γ").font(.headline)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 12) {
                        ForEach(alphabet, id: \.self) { value in
                            Button { onWrite(value) } label: {
                                Text(value).font(.system(.title2, design: .monospaced)).frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .buttonStyle(.glass).tint(value == symbol ? MachineStyle.cyan : .white)
                            .accessibilityLabel("Write \(value)")
                            .accessibilityIdentifier("tape.write.\(value)")
                        }
                    }
                    if !isHead {
                        Button("Place read head here", systemImage: "arrow.down.to.line", action: onPlaceHead)
                            .buttonStyle(.glassProminent).controlSize(.large)
                            .accessibilityIdentifier("tape.placeHead")
                    }
                    Text("Manual edits preserve the current state and step count, and clear the rewind journal.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding(20)
            }
            .navigationTitle("Cell \(position)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.preferredColorScheme(.dark)
    }
}

struct InputTapeView: View {
    let program: MachineProgram
    let onLoad: ([String], Int) -> Void
    @State private var input = ""
    @State private var head = "0"
    @State private var error: String?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Input word / Σ") {
                    TextField("Input", text: $input)
                        .font(.system(.title3, design: .monospaced))
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("input.word")
                    Text("Input symbols: \(program.inputAlphabet.joined(separator: "  ")). Type a word such as 1011 for a single-character alphabet; separate longer symbols with spaces. The empty word is allowed; unwritten cells contain \(program.blank).")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Initial read head") {
                    TextField("Position", text: $head).keyboardType(.numbersAndPunctuation)
                        .accessibilityIdentifier("input.head")
                    Text("Input begins at cell 0. The head may start at a negative or positive index.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error { Section { Text(error).foregroundStyle(.orange) } }
                Section {
                    Button("Load input and reset", systemImage: "arrow.down.doc") {
                        guard let position = Int(head) else { error = "Enter a whole-number head position."; return }
                        do {
                            var candidate = program
                            candidate.initialTape = try RuleDraftCodec.parseWord(input, alphabet: program.inputAlphabet)
                            candidate.initialHead = position
                            _ = try TuringMachine(program: candidate)
                            onLoad(candidate.initialTape, position)
                        }
                        catch { self.error = error.localizedDescription }
                    }.accessibilityIdentifier("input.load")
                }
            }
            .navigationTitle("Load the tape")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { input = RuleDraftCodec.formatWord(program.initialTape, alphabet: program.inputAlphabet); head = String(program.initialHead) }
        }.preferredColorScheme(.dark)
    }
}
