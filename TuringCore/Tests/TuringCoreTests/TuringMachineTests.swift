import Foundation
import Testing
@testable import TuringCore

private enum TestFailure: Error { case didNotHalt, wrongValidationError }

private func halted(_ program: MachineProgram, limit: Int = 20_000) throws -> TuringMachine {
    var machine = try TuringMachine(program: program)
    for _ in 0..<limit {
        if machine.status != .ready && machine.status != .running { return machine }
        machine.step()
    }
    throw TestFailure.didNotHalt
}

private func word(_ machine: TuringMachine) -> String {
    guard let left = machine.configuration.tape.keys.min(),
          let right = machine.configuration.tape.keys.max() else { return "" }
    return (left...right).map { machine.symbol(at: $0) }.joined()
}

private func validationError(_ program: MachineProgram) -> MachineValidationError? {
    do { _ = try TuringMachine(program: program); return nil }
    catch { return error as? MachineValidationError }
}

private func walker(_ direction: HeadMove = .right) -> MachineProgram {
    MachineProgram(id: "walker", name: "Walker", summary: "Walk forever.",
        states: ["walk", "accept", "reject"], inputAlphabet: [], tapeAlphabet: ["□"],
        blank: "□", initialState: "walk", acceptState: "accept", rejectState: "reject",
        transitions: [Transition(state: "walk", read: "□", write: "□", move: direction, nextState: "walk")],
        initialTape: [], initialHead: 0, explanation: "No halt rule.")
}

@Suite("Formal Turing machine and reversible execution")
struct TuringMachineTests {
    @Test("Every library program validates and has a unique identity; terminating examples halt")
    func libraryPrograms() throws {
        #expect(Set(MachineLibrary.programs.map(\.id)).count == MachineLibrary.programs.count)
        for program in MachineLibrary.programs {
            _ = try TuringMachine(program: program)
        }
        for program in MachineLibrary.programs where program.id != MachineLibrary.clockworkLoop.id {
            let machine = try halted(program)
            #expect(machine.status == .accepted)
            #expect(machine.nextTransition == nil)
            #expect(machine.configuration.tape.values.allSatisfy { $0 != program.blank })
        }
        #expect(word(try halted(MachineLibrary.increment)) == "1100")
        #expect(word(try halted(MachineLibrary.unaryDoubling)) == "111111")
        #expect(word(try halted(MachineLibrary.inverter)) == "01001110")
    }

    @Test("Binary increment exhaustively agrees with arithmetic for all 8-bit values")
    func binaryIncrement() throws {
        for number in 0...255 {
            var program = MachineLibrary.increment
            program.initialTape = String(number, radix: 2).map(String.init)
            let machine = try halted(program)
            #expect(machine.status == .accepted)
            #expect(word(machine) == String(number + 1, radix: 2))
        }
        var empty = MachineLibrary.increment
        empty.initialTape = []
        #expect(word(try halted(empty)) == "1")
    }

    @Test("Binary carry grows left of input coordinate zero")
    func carryIntoNegativeTape() throws {
        var program = MachineLibrary.increment
        program.initialTape = ["1", "1", "1"]
        let machine = try halted(program)
        #expect(machine.configuration.tape == [-1: "1", 0: "0", 1: "0", 2: "0"])
        #expect(machine.configuration.head == 0)
        #expect(machine.symbol(at: -2) == "□")
    }

    @Test("Unary doubling produces exactly two copies for input lengths zero through twenty")
    func unaryDoubling() throws {
        for count in 0...20 {
            var program = MachineLibrary.unaryDoubling
            program.initialTape = Array(repeating: "1", count: count)
            let machine = try halted(program)
            #expect(machine.status == .accepted)
            #expect(word(machine) == String(repeating: "1", count: 2 * count))
            #expect(machine.configuration.tape.count == 2 * count)
        }
    }

    @Test("Palindrome decider agrees with reversal for every binary word through length eight")
    func palindromeExhaustive() throws {
        for length in 0...8 {
            for value in 0..<(1 << length) {
                let bits = (0..<length).reversed().map { (value >> $0) & 1 == 1 ? "1" : "0" }
                var program = MachineLibrary.palindrome
                program.initialTape = bits
                let machine = try halted(program)
                let expected: MachineStatus = bits == Array(bits.reversed()) ? .accepted : .rejected
                #expect(machine.status == expected)
            }
        }
    }

    @Test("Inverter complements every bit and preserves input length")
    func inverterExhaustive() throws {
        for length in 0...8 {
            for value in 0..<(1 << length) {
                let bits = (0..<length).reversed().map { (value >> $0) & 1 == 1 ? "1" : "0" }
                var program = MachineLibrary.inverter
                program.initialTape = bits
                let machine = try halted(program)
                #expect(word(machine) == bits.map { $0 == "0" ? "1" : "0" }.joined())
                #expect(machine.configuration.steps == length + 1)
            }
        }
    }

    @Test("Step champion follows the independent 21-step state/head trace and leaves five marks")
    func busyBeaverStepsTrace() throws {
        var machine = try TuringMachine(program: MachineLibrary.busyBeaver)
        let states = ["B", "B", "C", "A", "B", "C", "C", "C", "A", "B", "C", "A", "B", "C", "A", "B", "C", "C", "C", "A", "accept"]
        let heads = [1, 0, 1, 0, 1, 2, 1, 0, -1, 0, 1, 0, 1, 2, 1, 2, 3, 2, 1, 0, 1]
        for index in states.indices {
            let nextRecord = machine.step()
            let record = try #require(nextRecord)
            #expect(record.id == index + 1)
            #expect(machine.configuration.state == states[index])
            #expect(machine.configuration.head == heads[index])
        }
        #expect(machine.status == .accepted)
        #expect(machine.configuration.steps == 21)
        #expect(machine.configuration.tape == [-1: "1", 0: "1", 1: "1", 2: "1", 3: "1"])
    }

    @Test("Mark champion leaves six marks in fourteen steps")
    func busyBeaverMarkChampion() throws {
        let machine = try halted(MachineLibrary.busyBeaverMarks)
        #expect(machine.status == .accepted)
        #expect(machine.configuration.steps == 14)
        #expect(machine.configuration.tape == [-1: "1", 0: "1", 1: "1", 2: "1", 3: "1", 4: "1"])
    }

    @Test("A step performs exactly its visible read, write, move and state rule")
    func atomicTransition() throws {
        for program in MachineLibrary.programs where program.id != MachineLibrary.clockworkLoop.id {
            var machine = try TuringMachine(program: program)
            while machine.status == .ready || machine.status == .running {
                let before = machine.configuration
                let rule = try #require(machine.nextTransition)
                let nextRecord = machine.step()
                let record = try #require(nextRecord)
                var expectedTape = before.tape
                expectedTape[before.head] = rule.write == program.blank ? nil : rule.write
                #expect(record.beforeState == before.state)
                #expect(record.read == (before.tape[before.head] ?? program.blank))
                #expect(record.write == rule.write)
                #expect(record.move == rule.move)
                #expect(machine.configuration == MachineConfiguration(state: rule.nextState,
                    head: before.head + rule.move.offset, tape: expectedTape, steps: before.steps + 1))
            }
        }
    }

    @Test("Explicit blank writes erase sparse cells and undo restores the overwritten symbol")
    func blankErasure() throws {
        let program = MachineLibrary.busyBeaver
        let start = MachineConfiguration(state: "B", head: -7, tape: [-7: "1", 100: "1"], steps: 3)
        var machine = try TuringMachine(program: program, configuration: start)
        let nextRecord = machine.step()
        let record = try #require(nextRecord)
        #expect(record.write == "0")
        #expect(machine.configuration.tape[-7] == nil)
        #expect(machine.symbol(at: -7) == "0")
        #expect(machine.configuration.tape[100] == "1")
        let undone = machine.undo()
        #expect(undone)
        #expect(machine.configuration == start)
    }

    @Test("Initial blanks and unvisited positive and negative cells have identical blank semantics")
    func sparseBlankSemantics() throws {
        var program = MachineLibrary.inverter
        program.initialTape = ["1", "□", "0"]
        let machine = try TuringMachine(program: program)
        #expect(machine.configuration.tape == [0: "1", 2: "0"])
        #expect(machine.symbol(at: 1) == "□")
        #expect(machine.symbol(at: Int.min) == "□")
        #expect(machine.symbol(at: Int.max) == "□")
    }

    @Test("Missing transitions become stuck without changing configuration or entering reject")
    func missingRule() throws {
        var program = walker()
        program.transitions = []
        var machine = try TuringMachine(program: program)
        let original = machine.configuration
        #expect(machine.status == .stuck)
        #expect(machine.status != .rejected)
        #expect(machine.nextTransition == nil)
        #expect(machine.step() == nil)
        #expect(machine.configuration == original)
        #expect(machine.statusDetail.contains("No rule"))
    }

    @Test("Accepted and rejected machines cannot execute more transitions")
    func terminalIsIdempotent() throws {
        var reject = MachineLibrary.palindrome
        reject.initialTape = ["0", "1"]
        for program in [MachineLibrary.inverter, reject] {
            var machine = try halted(program)
            let configuration = machine.configuration
            let last = machine.lastStep
            for _ in 0..<10 { #expect(machine.step() == nil) }
            #expect(machine.configuration == configuration)
            #expect(machine.lastStep == last)
        }
    }

    @Test("A valid initial accepting or rejecting configuration is already terminal")
    func initialHaltingState() throws {
        for terminal in ["accept", "reject"] {
            var program = MachineLibrary.inverter
            program.initialState = terminal
            let machine = try TuringMachine(program: program)
            #expect(machine.status.rawValue == (terminal == "accept" ? "accepted" : "rejected"))
            #expect(machine.configuration.steps == 0)
        }
    }

    @Test("Undo restores every configuration and the prior last-step record, including halt")
    func undoExactTrace() throws {
        for program in MachineLibrary.programs where program.id != MachineLibrary.clockworkLoop.id {
            var machine = try TuringMachine(program: program)
            var snapshots: [(MachineConfiguration, MachineStatus, StepRecord?)] = []
            while machine.status == .ready || machine.status == .running {
                snapshots.append((machine.configuration, machine.status, machine.lastStep))
                machine.step()
            }
            #expect(machine.undoDepth == snapshots.count)
            for snapshot in snapshots.reversed() {
                let undone = machine.undo()
                #expect(undone)
                #expect(machine.configuration == snapshot.0)
                #expect(machine.status == snapshot.1)
                #expect(machine.lastStep == snapshot.2)
            }
            #expect(!machine.canUndo)
            let extraUndo = machine.undo()
            #expect(!extraUndo)
        }
    }

    @Test("Execution has no step cap; undo retains exactly the newest 4096 deltas")
    func boundedUndoAndUnboundedExecution() throws {
        var machine = try TuringMachine(program: walker())
        for _ in 0..<4_200 { #expect(machine.step() != nil) }
        #expect(machine.configuration.steps == 4_200)
        #expect(machine.status == .running)
        #expect(machine.configuration.tape.isEmpty)
        #expect(machine.undoDepth == 4_096)
        for _ in 0..<4_096 {
            let undone = machine.undo()
            #expect(undone)
        }
        #expect(machine.configuration.steps == 104)
        #expect(machine.configuration.head == 104)
        #expect(machine.lastStep?.id == 104)
        let extraUndo = machine.undo()
        #expect(!extraUndo)
        for _ in 0..<10 { machine.step() }
        #expect(machine.undoDepth == 10)
        for _ in 0..<10 {
            let undone = machine.undo()
            #expect(undone)
        }
        #expect(machine.configuration.steps == 104)
    }

    @Test("Reset restores the complete original input and execution state")
    func reset() throws {
        var machine = try TuringMachine(program: MachineLibrary.increment)
        let original = machine.configuration
        for _ in 0..<10 { machine.step() }
        try machine.setSymbol("1", at: -100)
        machine.moveHead(to: 99)
        machine.reset()
        #expect(machine.configuration == original)
        #expect(machine.status == .ready)
        #expect(machine.lastStep == nil)
        #expect(machine.undoDepth == 0)
    }

    @Test("Manual edits preserve logical state and step count while clearing the trace")
    func manualEditing() throws {
        var machine = try TuringMachine(program: MachineLibrary.unaryDoubling)
        machine.step()
        let currentState = machine.configuration.state
        try machine.setSymbol("Y", at: -30)
        #expect(machine.configuration.state == currentState)
        #expect(machine.configuration.steps == 1)
        #expect(machine.configuration.tape[-30] == "Y")
        #expect(machine.configuration.tape[0] == "X")
        #expect(machine.undoDepth == 0)
        #expect(machine.lastStep == nil)
        machine.moveHead(to: -30)
        #expect(machine.configuration.head == -30)
        #expect(machine.currentSymbol == "Y")
        try machine.setSymbol("□", at: -30)
        #expect(machine.configuration.tape[-30] == nil)
    }

    @Test("Invalid manual symbols leave configuration and undo intact")
    func invalidEditing() throws {
        var machine = try TuringMachine(program: MachineLibrary.inverter)
        machine.step()
        let configuration = machine.configuration
        #expect(throws: MachineValidationError.symbolNotInTapeAlphabet("bad")) {
            try machine.setSymbol("bad", at: 0)
        }
        #expect(machine.configuration == configuration)
        #expect(machine.undoDepth == 1)
    }

    @Test("Direction-specific coordinate overflow halts before any partial write")
    func coordinateOverflow() throws {
        for (direction, head) in [(HeadMove.right, Int.max), (.left, Int.min)] {
            var machine = try TuringMachine(program: walker(direction),
                configuration: MachineConfiguration(state: "walk", head: head, tape: [:], steps: 0))
            let configuration = machine.configuration
            #expect(machine.step() == nil)
            #expect(machine.configuration == configuration)
            #expect(machine.status == .stuck)
            #expect(machine.undoDepth == 0)
            #expect(machine.statusDetail.contains("coordinate"))
            // Moving back into the representable range makes an edited configuration executable.
            machine.moveHead(to: 0)
            #expect(machine.status == .ready)
            #expect(machine.step() != nil)
        }
    }

    @Test("Step counter overflow halts atomically")
    func stepCounterOverflow() throws {
        var machine = try TuringMachine(program: walker(),
            configuration: MachineConfiguration(state: "walk", head: 0, tape: [:], steps: Int.max))
        let configuration = machine.configuration
        #expect(machine.step() == nil)
        #expect(machine.configuration == configuration)
        #expect(machine.status == .stuck)
        #expect(machine.statusDetail.contains("step counter"))
    }

    @Test("Restored tape is validated and explicit blanks are canonicalized")
    func restoration() throws {
        let restored = try TuringMachine(program: MachineLibrary.busyBeaver,
            configuration: MachineConfiguration(state: "C", head: -2, tape: [-2: "0", -3: "1", 100: "0"], steps: 9))
        #expect(restored.configuration.tape == [-3: "1"])
        #expect(restored.configuration.steps == 9)
        #expect(restored.status == .ready)
        #expect(restored.undoDepth == 0)
        #expect(restored.lastStep == nil)
        #expect(throws: MachineValidationError.negativeStepCount(-1)) {
            try TuringMachine(program: MachineLibrary.inverter,
                configuration: MachineConfiguration(state: "flip", head: 0, tape: [:], steps: -1))
        }
        #expect(throws: MachineValidationError.symbolNotInTapeAlphabet("?")) {
            try TuringMachine(program: MachineLibrary.inverter,
                configuration: MachineConfiguration(state: "flip", head: 0, tape: [0: "?"], steps: 1))
        }
        #expect(throws: MachineValidationError.stateNotDeclared(field: "Saved state", state: "unknown")) {
            try TuringMachine(program: MachineLibrary.inverter,
                configuration: MachineConfiguration(state: "unknown", head: 0, tape: [:], steps: 1))
        }
    }

    @Test("Program, configuration and trace records survive Codable round trips")
    func codable() throws {
        for program in MachineLibrary.programs {
            let data = try JSONEncoder().encode(program)
            #expect(try JSONDecoder().decode(MachineProgram.self, from: data) == program)
        }
        for program in MachineLibrary.programs where program.id != MachineLibrary.clockworkLoop.id {
            let machine = try halted(program)
            let configData = try JSONEncoder().encode(machine.configuration)
            let config = try JSONDecoder().decode(MachineConfiguration.self, from: configData)
            #expect(config == machine.configuration)
            let restored = try TuringMachine(program: program, configuration: config)
            #expect(restored.status == machine.status)
            let record = try #require(machine.lastStep)
            #expect(try JSONDecoder().decode(StepRecord.self, from: JSONEncoder().encode(record)) == record)
        }
    }

    @Test("Copies can branch independently without sharing mutable tape or undo state")
    func valueSemantics() throws {
        var original = try TuringMachine(program: MachineLibrary.increment)
        original.step()
        var branch = original
        try branch.setSymbol("0", at: 0)
        branch.moveHead(to: -1)
        #expect(original.configuration.tape[0] == "1")
        #expect(original.configuration.head == 1)
        #expect(original.undoDepth == 1)
        #expect(branch.undoDepth == 0)
        let undone = original.undo()
        #expect(undone)
        #expect(branch.configuration.tape[0] == "0")
    }

    @Test("Duplicate source/read pairs violate determinism regardless of destination")
    func validationDeterminism() {
        var program = MachineLibrary.inverter
        program.transitions.append(Transition(state: "flip", read: "1", write: "1", move: .left, nextState: "reject"))
        #expect(validationError(program) == .duplicateTransition(state: "flip", read: "1"))
    }

    @Test("Malformed state sets and terminal states are rejected")
    func validationStates() {
        var program = MachineLibrary.inverter
        program.states.append("flip")
        #expect(validationError(program) == .duplicateState("flip"))
        program = MachineLibrary.inverter
        program.initialState = "undeclared"
        #expect(validationError(program) == .stateNotDeclared(field: "Initial state", state: "undeclared"))
        program = MachineLibrary.inverter
        program.rejectState = "accept"
        #expect(validationError(program) == .haltingStatesMustDiffer)
        program = MachineLibrary.inverter
        program.states.append("   ")
        #expect(validationError(program) == .emptyValue("State name"))
    }

    @Test("Alphabet inclusion, blank exclusion and duplicate symbols are enforced")
    func validationAlphabets() {
        var program = MachineLibrary.inverter
        program.blank = "?"
        #expect(validationError(program) == .blankNotInTapeAlphabet("?"))
        program = MachineLibrary.inverter
        program.inputAlphabet.append("□")
        #expect(validationError(program) == .blankInInputAlphabet("□"))
        program = MachineLibrary.inverter
        program.inputAlphabet.append("?")
        #expect(validationError(program) == .inputSymbolNotInTapeAlphabet("?"))
        program = MachineLibrary.inverter
        program.tapeAlphabet.append("0")
        #expect(validationError(program) == .duplicateSymbol(alphabet: "Γ", symbol: "0"))
        program = MachineLibrary.inverter
        program.inputAlphabet.append("1")
        #expect(validationError(program) == .duplicateSymbol(alphabet: "Σ", symbol: "1"))
    }

    @Test("Transitions cannot use undeclared states, symbols or halting sources")
    func validationTransitions() {
        var program = MachineLibrary.inverter
        program.transitions[0].nextState = "?"
        #expect(validationError(program) == .stateNotDeclared(field: "Transition destination", state: "?"))
        program = MachineLibrary.inverter
        program.transitions[0].state = "?"
        #expect(validationError(program) == .stateNotDeclared(field: "Transition source", state: "?"))
        program = MachineLibrary.inverter
        program.transitions[0].read = "?"
        #expect(validationError(program) == .transitionSymbolNotDeclared(field: "read", symbol: "?"))
        program = MachineLibrary.inverter
        program.transitions[0].write = "?"
        #expect(validationError(program) == .transitionSymbolNotDeclared(field: "write", symbol: "?"))
        program = MachineLibrary.inverter
        program.transitions[0].state = "accept"
        #expect(validationError(program) == .transitionFromHaltingState("accept"))
    }

    @Test("Initial input may include blank gaps but cannot contain internal marker symbols")
    func validationInitialInput() {
        var program = MachineLibrary.unaryDoubling
        program.initialTape = ["1", "X"]
        #expect(validationError(program) == .initialSymbolNotInInputAlphabet(index: 1, symbol: "X"))
        program.initialTape = ["1", "□", "1"]
        #expect(validationError(program) == nil)
    }

    @Test("Multi-character tokens are atomic and transition IDs avoid delimiter collisions")
    func customAlphabet() throws {
        let program = MachineProgram(id: "tokens", name: "Tokens", summary: "Atomic strings.",
            states: ["state:α", "yes", "no"], inputAlphabet: ["red"], tapeAlphabet: ["red", "blue", "blank"],
            blank: "blank", initialState: "state:α", acceptState: "yes", rejectState: "no",
            transitions: [Transition(state: "state:α", read: "red", write: "blue", move: .left, nextState: "yes")],
            initialTape: ["red"], initialHead: 0, explanation: "One token per tape cell.")
        let machine = try halted(program)
        #expect(machine.status == .accepted)
        #expect(machine.configuration.tape == [0: "blue"])
        #expect(machine.configuration.head == -1)
        let first = Transition(state: "a:b", read: "c", write: "c", move: .left, nextState: "a:b")
        let second = Transition(state: "a", read: "b:c", write: "b:c", move: .left, nextState: "a")
        #expect(first.id != second.id)
        #expect(HeadMove.left.offset == -1)
        #expect(HeadMove.right.offset == 1)
    }

    @Test("A literal space is a valid nonempty blank symbol")
    func whitespaceBlank() throws {
        var program = walker()
        program.blank = " "
        program.tapeAlphabet = [" "]
        program.transitions = [Transition(state: "walk", read: " ", write: " ", move: .right, nextState: "accept")]
        let machine = try halted(program)
        #expect(machine.status == .accepted)
        #expect(machine.currentSymbol == " ")
        #expect(machine.configuration.tape.isEmpty)
    }

    @Test("Clockwork loop repeats its exact two-cell pattern through 1024 transitions and reverses")
    func clockworkLoop() throws {
        var machine = try TuringMachine(program: MachineLibrary.clockworkLoop)
        let initial = machine.configuration
        for step in 1...1_024 {
            let record = machine.step()
            #expect(record != nil)
            #expect(machine.status == .running)
            #expect(machine.configuration.head == step % 2)
            #expect(machine.configuration.state == (step % 2 == 0 ? "right" : "left"))
            #expect(machine.configuration.tape.isEmpty)
        }
        #expect(machine.configuration.steps == 1_024)
        for _ in 0..<1_024 {
            let undone = machine.undo()
            #expect(undone)
        }
        #expect(machine.configuration == initial)
        #expect(machine.status == .ready)
    }
}
