import SwiftUI
import TuringCore

struct RulebookView: View {
    let program: MachineProgram
    let activeTransitionID: String?
    let onEdit: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    WorkbenchHeading(
                        eyebrow: "Finite control",
                        title: program.name,
                        detail: "The current state and the symbol under the head select exactly one rule. Its write, movement, and next state form one atomic transition."
                    )
                    WorkbenchPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("δ : (q, s) → (q′, s′, d), d ∈ {L, R}")
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(WorkbenchStyle.accent)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(program.transitions.count) rules · blank = \(program.blank)")
                                .foregroundStyle(WorkbenchStyle.secondary)
                            Text("A missing rule stops the machine without acceptance or rejection.")
                                .font(.subheadline)
                                .foregroundStyle(WorkbenchStyle.secondary)
                        }
                    }
                    StateConnectionsView(program: program, activeTransitionID: activeTransitionID)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transition table").font(.title3.bold())
                        Text("The glowing row is the next rule to execute.")
                            .font(.subheadline)
                            .foregroundStyle(WorkbenchStyle.secondary)
                    }
                    if program.transitions.isEmpty {
                        Text("No transitions. This machine stops immediately unless its initial state is already terminal.")
                            .foregroundStyle(WorkbenchStyle.secondary)
                    }
                    ForEach(Array(program.transitions.enumerated()), id: \.element.id) { index, rule in
                        TransitionRuleCard(rule: rule, number: index + 1, isActive: rule.id == activeTransitionID)
                    }
                }
                .padding(20)
            }
            .background(WorkbenchStyle.background)
            .navigationTitle("Rulebook")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Edit", systemImage: "pencil") { onEdit() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    WorkbenchCloseButton(label: "Close rulebook")
                }
            }
            .tint(WorkbenchStyle.accent)
        }
        .preferredColorScheme(.dark)
    }
}

private struct TransitionRuleCard: View {
    let rule: TuringCore.Transition
    let number: Int
    let isActive: Bool

    var body: some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(String(format: "%02d", number))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(WorkbenchStyle.secondary)
                    Spacer()
                    if isActive {
                        Label("Next transition", systemImage: "scope")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WorkbenchStyle.accent)
                    }
                }
                VStack(alignment: .leading, spacing: 7) {
                    Text("IF  \(rule.state) reads \(rule.read)")
                        .font(.system(.body, design: .monospaced).weight(.medium))
                    Text("Write \(rule.write)  ·  move \(rule.move == .left ? "left ←" : "right →")")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(WorkbenchStyle.accent)
                    Text("Enter \(rule.nextState)")
                        .font(.system(.body, design: .monospaced))
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(WorkbenchStyle.accent, lineWidth: 1.5)
                    .allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rule \(number)\(isActive ? ", next transition" : ""). In state \(rule.state), reading \(rule.read), write \(rule.write), move \(rule.move == .left ? "left" : "right"), enter \(rule.nextState).")
    }
}

private struct StateConnectionsView: View {
    let program: MachineProgram
    let activeTransitionID: String?

    private var activeRule: TuringCore.Transition? {
        program.transitions.first { $0.id == activeTransitionID }
    }

    var body: some View {
        WorkbenchPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("State map").font(.title3.bold())
                Text("Arrows connect states that share a transition. Full conditions appear in the table below.")
                    .font(.subheadline)
                    .foregroundStyle(WorkbenchStyle.secondary)
                ScrollView(.horizontal) {
                    GeometryReader { proxy in
                        let positions = positions(in: proxy.size)
                        ZStack {
                            Canvas { context, _ in
                                for edge in uniqueEdges {
                                    guard let start = positions[edge.from], let end = positions[edge.to] else { continue }
                                    let isActive = activeRule?.state == edge.from && activeRule?.nextState == edge.to
                                    let color = isActive ? WorkbenchStyle.accent : WorkbenchStyle.secondary.opacity(0.4)
                                    drawArrow(from: start, to: end, color: color, context: &context)
                                }
                            }
                            .accessibilityHidden(true)
                            ForEach(program.states, id: \.self) { state in
                                if let point = positions[state] {
                                    Text(state)
                                        .font(.system(.caption, design: .monospaced).weight(.bold))
                                        .foregroundStyle(state == program.acceptState ? Color.green : state == program.rejectState ? Color.orange : Color.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 10)
                                        .background(WorkbenchStyle.background, in: Capsule())
                                        .overlay {
                                            Capsule().strokeBorder(state == activeRule?.state ? WorkbenchStyle.accent : WorkbenchStyle.border, lineWidth: state == activeRule?.state ? 2 : 1)
                                        }
                                        .position(point)
                                        .accessibilityLabel(stateDescription(state))
                                }
                            }
                        }
                    }
                    .frame(width: max(300, CGFloat(program.states.count) * 40), height: 245)
                }
                Text("Green = accept · amber = reject")
                    .font(.caption)
                    .foregroundStyle(WorkbenchStyle.secondary)
            }
        }
    }

    private struct StateEdge: Hashable {
        let from: String
        let to: String
    }

    private func stateDescription(_ state: String) -> String {
        let terminal: String
        if state == program.acceptState { terminal = ", accepting" }
        else if state == program.rejectState { terminal = ", rejecting" }
        else { terminal = "" }
        let outgoing = program.transitions.filter { $0.state == state }.count
        return "State \(state)\(terminal), \(outgoing) outgoing rules"
    }

    private var uniqueEdges: [StateEdge] {
        var seen = Set<StateEdge>()
        return program.transitions.compactMap { rule in
            let edge = StateEdge(from: rule.state, to: rule.nextState)
            return seen.insert(edge).inserted ? edge : nil
        }
    }

    private func positions(in size: CGSize) -> [String: CGPoint] {
        var result: [String: CGPoint] = [:]
        let count = max(program.states.count, 1)
        for (index, state) in program.states.enumerated() {
            let angle = Double(index) / Double(count) * .pi * 2 - .pi / 2
            result[state] = CGPoint(
                x: size.width / 2 + CGFloat(cos(angle)) * (size.width / 2 - 55),
                y: size.height / 2 + CGFloat(sin(angle)) * (size.height / 2 - 48)
            )
        }
        return result
    }

    private func drawArrow(from start: CGPoint, to end: CGPoint, color: Color, context: inout GraphicsContext) {
        if start == end {
            let loop = CGRect(x: start.x - 13, y: start.y - 37, width: 26, height: 29)
            context.stroke(Path(ellipseIn: loop), with: .color(color), lineWidth: 1.2)
            return
        }
        let angle = atan2(end.y - start.y, end.x - start.x)
        let from = CGPoint(x: start.x + cos(angle) * 30, y: start.y + sin(angle) * 22)
        let tip = CGPoint(x: end.x - cos(angle) * 30, y: end.y - sin(angle) * 22)
        var path = Path()
        path.move(to: from)
        path.addLine(to: tip)
        path.move(to: CGPoint(x: tip.x - cos(angle - 0.45) * 8, y: tip.y - sin(angle - 0.45) * 8))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - cos(angle + 0.45) * 8, y: tip.y - sin(angle + 0.45) * 8))
        context.stroke(path, with: .color(color), lineWidth: 1.2)
    }
}
