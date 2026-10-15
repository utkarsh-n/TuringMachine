import SwiftUI
import TuringCore

private enum MachineSheet: String, Identifiable {
    case library, rules, editor, theory, journal, input, settings
    var id: String { rawValue }
}

struct MachineView: View {
    @State private var session = MachineSession()
    @State private var lighting = MotionLighting()
    @State private var sheet: MachineSheet?
    @State private var selectedCell: TapeSelection?
    @AppStorage("turing.motion") private var motionEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                InstrumentBackdrop(lighting: lighting, reduceMotion: reduceMotion || !motionEnabled)
                ScrollView {
                    VStack(spacing: 14) {
                        masthead
                        programSelector
                        if geometry.size.width > 650 && !typeSize.isAccessibilitySize {
                            HStack(alignment: .center, spacing: 32) {
                                instrument(dialSize: 216).frame(maxWidth: 360)
                                VStack(spacing: 22) { tape; transitionPanel }.frame(maxWidth: 520)
                            }
                        } else {
                            tape
                            instrument(dialSize: geometry.size.height < 800 ? 194 : 216)
                            transitionPanel
                        }
                        if let reason = session.pauseReason {
                            Label(reason, systemImage: "pause.circle")
                                .font(.footnote).foregroundStyle(MachineStyle.amber)
                                .instrumentPanel()
                        }
                        lowerActions
                    }
                    .frame(maxWidth: 940)
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 18)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .safeAreaInset(edge: .bottom) { transport }
        }
        .sheet(item: $sheet, onDismiss: { session.persist() }) { destination in
            switch destination {
            case .library:
                ProgramLibraryView(programs: session.programs, selectedID: session.machine.program.id) {
                    session.select($0); sheet = nil
                }
            case .rules:
                RulebookView(program: session.machine.program, activeTransitionID: session.machine.nextTransition?.id) {
                    sheet = nil
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(350))
                        sheet = .editor
                    }
                }
            case .editor:
                RuleEditorView(program: session.machine.program) {
                    session.select($0, saveAsCustom: true); sheet = nil
                }
            case .theory: TheoryView(program: session.machine.program)
            case .journal: ExecutionTraceView(records: session.records)
            case .input:
                InputTapeView(program: session.machine.program) { input, head in
                    session.loadInput(input, head: head)
                    if session.error == nil { sheet = nil }
                }
            case .settings:
                settings
            }
        }
        .sheet(item: $selectedCell) { selection in
            TapeCellEditor(position: selection.position, symbol: session.machine.symbol(at: selection.position),
                           alphabet: session.machine.program.tapeAlphabet, isHead: selection.position == session.machine.configuration.head,
                           onWrite: { session.write($0, at: selection.position); selectedCell = nil },
                           onPlaceHead: { session.placeHead(at: selection.position); selectedCell = nil })
                .presentationDetents([.medium])
        }
        .alert("Machine needs attention", isPresented: Binding(get: { session.error != nil }, set: { if !$0 { session.error = nil } })) {
            Button("OK", role: .cancel) { session.error = nil }
        } message: { Text(session.error ?? "") }
        .onAppear { updateMotion() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { updateMotion() }
            else { session.pause(); session.persist(); lighting.stop() }
        }
        .onChange(of: reduceMotion) { updateMotion() }
        .onChange(of: motionEnabled) { updateMotion() }
        .onChange(of: session.speed) { session.persist() }
        .onDisappear { session.pause(); session.persist(); lighting.stop() }
    }

    private var masthead: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 5) {
                InstrumentCaption(text: "No. 01 / Computation instrument")
                Text("The Turing Machine")
                    .font(.system(.title, design: .rounded, weight: .semibold))
                    .tracking(-0.8)
                    .accessibilityAddTraits(.isHeader)
            }
            Spacer(minLength: 4)
            Button { open(.theory) } label: {
                Image(systemName: "info").frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("How a Turing machine works")
            .accessibilityIdentifier("machine.theory")
        }
    }

    private var programSelector: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 10) {
                Button { open(.library) } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.stack.3d.up")
                            .foregroundStyle(MachineStyle.cyan)
                        Text(session.machine.program.name).font(.subheadline.weight(.medium)).lineLimit(2)
                        Image(systemName: "chevron.down").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                    }
                    .frame(minHeight: 44).padding(.horizontal, 14)
                }
                .buttonStyle(.glass)
                .accessibilityLabel("Choose program, \(session.machine.program.name)")
                .accessibilityIdentifier("machine.library")
                Spacer(minLength: 0)
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 6, height: 6)
                        .shadow(color: statusColor.opacity(0.5), radius: 5)
                    Text(session.statusLabel)
                        .font(.system(.caption2, design: .monospaced, weight: .semibold))
                }
                .foregroundStyle(statusColor)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("machine.status")
            }
        }
    }

    private var tape: some View {
        TapeView(head: session.machine.configuration.head,
                 readSymbol: { session.machine.symbol(at: $0) },
                 focus: $session.tapeFocus, reduceMotion: reduceMotion,
                 onSelect: { position in session.pause(); selectedCell = TapeSelection(position: position) },
                 onInput: { open(.input) })
    }

    private func instrument(dialSize: CGFloat) -> some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading, spacing: 25) {
                    meter("STEPS", value: session.machine.configuration.steps.formatted(), id: "machine.steps")
                    meter("HEAD", value: session.machine.configuration.head.formatted(), id: "machine.head")
                    VStack(alignment: .leading, spacing: 5) {
                        InstrumentCaption(text: "Tempo")
                        Text("\(session.speed.formatted(.number.precision(.fractionLength(0...2)))) Hz")
                            .font(.system(.title3, design: .monospaced, weight: .medium))
                            .foregroundStyle(MachineStyle.amber)
                    }
                }
                .frame(minWidth: 65, maxWidth: 94, alignment: .leading)
                ExecutionDial(speed: $session.speed, state: session.machine.configuration.state,
                              symbol: session.machine.currentSymbol, isRunning: session.isRunning,
                              progress: Double(session.machine.configuration.steps % 60) / 60,
                              lighting: lighting, reduceMotion: reduceMotion || !motionEnabled,
                              hapticsEnabled: session.haptics)
                    .scaleEffect(dialSize / 216)
                    .frame(width: dialSize, height: dialSize)
            }
            HStack(spacing: 6) {
                Image(systemName: "hand.draw").font(.caption)
                Text("Turn the dial to set the pace")
                    .font(.caption).tracking(0.2)
            }.foregroundStyle(.secondary)
            if session.machine.status == .accepted || session.machine.status == .rejected || session.machine.status == .stuck {
                Text(session.machine.statusDetail)
                    .font(.footnote).foregroundStyle(statusColor)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("machine.outcome")
            }
        }
    }

    private func meter(_ label: String, value: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            InstrumentCaption(text: label)
            Text(value).font(.system(.title2, design: .monospaced, weight: .medium))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.65).lineLimit(1)
                .accessibilityLabel(label).accessibilityValue(value)
                .accessibilityIdentifier(id)
        }
    }

    private var transitionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                InstrumentCaption(text: session.canStep ? "Next transition / δ" : "Execution stopped")
                Spacer()
                Button("Rules", systemImage: "list.bullet.rectangle") { open(.rules) }
                    .font(.caption).buttonStyle(.borderless)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("machine.rules")
            }
            if let rule = session.machine.nextTransition {
                HStack(spacing: 0) {
                    transitionValue("STATE", rule.state, color: .white)
                    transitionValue("READ", rule.read, color: MachineStyle.cyan)
                    Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary).padding(.horizontal, 5)
                    transitionValue("WRITE", rule.write, color: MachineStyle.amber)
                    transitionValue("MOVE", rule.move == .left ? "←" : "→", color: .white)
                    transitionValue("NEXT", rule.nextState, color: MachineStyle.cyan)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Next rule. In \(rule.state), read \(rule.read), write \(rule.write), move \(rule.move == .left ? "left" : "right"), enter \(rule.nextState).")
                .accessibilityIdentifier("machine.transition")
            } else {
                Text(session.machine.statusDetail).font(.subheadline).foregroundStyle(statusColor)
            }
            if let last = session.machine.lastStep {
                Text("LAST  \(last.beforeState) · \(last.read) → \(last.write) · \(last.move.rawValue) · \(last.afterState)")
                    .font(.system(.caption2, design: .monospaced)).foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("Read → write → move → change state. One atomic step.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .instrumentPanel()
    }

    private func transitionValue(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text(label).font(.system(size: 8, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
            Text(value).font(.system(.title3, design: .monospaced, weight: .semibold))
                .foregroundStyle(color).lineLimit(1).minimumScaleFactor(0.45)
        }.frame(maxWidth: .infinity)
    }

    private var lowerActions: some View {
        HStack(spacing: 22) {
            Button("Journal", systemImage: "clock.arrow.circlepath") { open(.journal) }
                .accessibilityIdentifier("machine.journal")
            Spacer()
            Button("Reset", systemImage: "arrow.counterclockwise") { session.reset() }
                .accessibilityIdentifier("machine.reset")
            Button { open(.settings) } label: { Image(systemName: "slider.horizontal.3") }
                .accessibilityLabel("Instrument settings")
                .accessibilityIdentifier("machine.settings")
        }
        .font(.caption).foregroundStyle(.secondary)
        .buttonStyle(.borderless)
        .frame(minHeight: 44)
    }

    private var transport: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button { session.undo() } label: {
                    Label("Back", systemImage: "backward.end.fill")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glass).disabled(!session.machine.canUndo)
                .accessibilityLabel("Rewind one transition")
                .accessibilityIdentifier("machine.back")
                Button { session.step() } label: {
                    Label("Step", systemImage: "forward.end.fill")
                        .font(.subheadline.weight(.medium)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glass).disabled(!session.canStep)
                .accessibilityIdentifier("machine.step")
                Button { session.toggleRun() } label: {
                    Label(session.isRunning ? "Pause" : "Run", systemImage: session.isRunning ? "pause.fill" : "play.fill")
                        .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.glassProminent).tint(MachineStyle.cyan)
                .disabled(!session.canStep && !session.isRunning)
                .accessibilityIdentifier("machine.run")
            }
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(LinearGradient(colors: [.clear, MachineStyle.ink.opacity(0.96)], startPoint: .top, endPoint: .bottom))
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Tactile response") {
                    Toggle("Step haptics", isOn: $session.haptics)
                    Toggle("Mechanical clicks", isOn: $session.sound)
                    Toggle("Motion reflections", isOn: $motionEnabled)
                    Button("Calibrate reflections") { lighting.calibrate() }
                        .disabled(!motionEnabled || reduceMotion || !lighting.isAvailable)
                }
                Section {
                    Text(reduceMotion ? "Reduce Motion is active. The optical surface stays still." :
                         lighting.isAvailable ? "Tilt your phone gently to move the light across the lens. Movement changes the surface, while the logical machine stays deterministic." :
                         "Motion sensing is unavailable here. The dial and every machine control still work.")
                    Text("Your program and current configuration save automatically. Reopening starts paused; the rewind journal begins with this session.")
                    Text("Rewind retains the last 4,096 transitions. Continuous runs pause after 100,000 steps or 50,000 stored cells; this is a resource pause, not a logical halt.")
                }.font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Instrument settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { sheet = nil } } }
        }.preferredColorScheme(.dark)
    }

    private var statusColor: Color {
        switch session.machine.status {
        case .accepted: .green
        case .rejected: .orange
        case .stuck: MachineStyle.amber
        case .ready, .running: MachineStyle.cyan
        }
    }
    private func open(_ destination: MachineSheet) { session.pause(); session.persist(); sheet = destination }
    private func updateMotion() {
        if scenePhase == .active && motionEnabled && !reduceMotion { lighting.start() }
        else { lighting.stop() }
    }
}
