import Foundation

/// A deterministic, single-tape Turing machine over a two-way tape.
/// Symbols are atomic strings, so user-defined alphabets can use multi-character tokens.
public struct MachineProgram: Identifiable, Codable, Equatable, Sendable {
    public var id: String
    public var name: String
    public var summary: String
    public var states: [String]
    public var inputAlphabet: [String]
    public var tapeAlphabet: [String]
    public var blank: String
    public var initialState: String
    public var acceptState: String
    public var rejectState: String
    public var transitions: [Transition]
    /// Input begins at coordinate zero. Blank gaps are allowed; other symbols must belong to Σ.
    public var initialTape: [String]
    public var initialHead: Int
    public var explanation: String

    public init(id: String, name: String, summary: String, states: [String],
                inputAlphabet: [String], tapeAlphabet: [String], blank: String,
                initialState: String, acceptState: String, rejectState: String,
                transitions: [Transition], initialTape: [String], initialHead: Int,
                explanation: String) {
        self.id = id
        self.name = name
        self.summary = summary
        self.states = states
        self.inputAlphabet = inputAlphabet
        self.tapeAlphabet = tapeAlphabet
        self.blank = blank
        self.initialState = initialState
        self.acceptState = acceptState
        self.rejectState = rejectState
        self.transitions = transitions
        self.initialTape = initialTape
        self.initialHead = initialHead
        self.explanation = explanation
    }
}

public enum HeadMove: String, Codable, CaseIterable, Sendable {
    case left = "L"
    case right = "R"

    public var offset: Int { self == .left ? -1 : 1 }
}

public struct Transition: Identifiable, Codable, Equatable, Sendable {
    public var state: String
    public var read: String
    public var write: String
    public var move: HeadMove
    public var nextState: String

    /// Length prefixes prevent collisions when a custom state or symbol contains punctuation.
    public var id: String { "\(state.utf8.count):\(state)\(read.utf8.count):\(read)" }

    public init(state: String, read: String, write: String, move: HeadMove, nextState: String) {
        self.state = state
        self.read = read
        self.write = write
        self.move = move
        self.nextState = nextState
    }
}

public struct MachineConfiguration: Codable, Equatable, Sendable {
    public var state: String
    public var head: Int
    /// Only nonblank cells are stored; absence represents the program's blank symbol.
    public var tape: [Int: String]
    /// Count of successful atomic transitions since this configuration's initial load.
    public var steps: Int

    public init(state: String, head: Int, tape: [Int: String], steps: Int) {
        self.state = state
        self.head = head
        self.tape = tape
        self.steps = steps
    }
}

public enum MachineStatus: String, Codable, Sendable {
    case ready, running, accepted, rejected, stuck
}

public struct StepRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: Int
    public let beforeState: String
    public let afterState: String
    public let headBefore: Int
    public let headAfter: Int
    public let read: String
    public let write: String
    public let move: HeadMove

    public init(id: Int, beforeState: String, afterState: String, headBefore: Int,
                headAfter: Int, read: String, write: String, move: HeadMove) {
        self.id = id
        self.beforeState = beforeState
        self.afterState = afterState
        self.headBefore = headBefore
        self.headAfter = headAfter
        self.read = read
        self.write = write
        self.move = move
    }
}

public enum MachineValidationError: Error, LocalizedError, Equatable, Sendable {
    case emptyValue(String)
    case duplicateState(String)
    case duplicateSymbol(alphabet: String, symbol: String)
    case stateNotDeclared(field: String, state: String)
    case blankNotInTapeAlphabet(String)
    case blankInInputAlphabet(String)
    case inputSymbolNotInTapeAlphabet(String)
    case haltingStatesMustDiffer
    case transitionFromHaltingState(String)
    case transitionSymbolNotDeclared(field: String, symbol: String)
    case duplicateTransition(state: String, read: String)
    case initialSymbolNotInInputAlphabet(index: Int, symbol: String)
    case symbolNotInTapeAlphabet(String)
    case negativeStepCount(Int)
    case coordinateOverflow
    case stepOverflow

    public var errorDescription: String? {
        switch self {
        case .emptyValue(let field): "\(field) must not be empty."
        case .duplicateState(let state): "State “\(state)” appears more than once in Q."
        case .duplicateSymbol(let alphabet, let symbol): "Symbol “\(symbol)” appears more than once in \(alphabet)."
        case .stateNotDeclared(let field, let state): "\(field) “\(state)” is not declared in Q."
        case .blankNotInTapeAlphabet(let symbol): "Blank “\(symbol)” must belong to the tape alphabet Γ."
        case .blankInInputAlphabet(let symbol): "Blank “\(symbol)” cannot belong to the input alphabet Σ."
        case .inputSymbolNotInTapeAlphabet(let symbol): "Input symbol “\(symbol)” must also belong to Γ."
        case .haltingStatesMustDiffer: "Accept and reject states must be distinct."
        case .transitionFromHaltingState(let state): "Halting state “\(state)” cannot have an outgoing transition."
        case .transitionSymbolNotDeclared(let field, let symbol): "Transition \(field) symbol “\(symbol)” is not declared in Γ."
        case .duplicateTransition(let state, let read): "δ(\(state), \(read)) has more than one rule; the machine must be deterministic."
        case .initialSymbolNotInInputAlphabet(let index, let symbol): "Initial cell \(index) contains “\(symbol)”; initial input must use Σ or blank gaps."
        case .symbolNotInTapeAlphabet(let symbol): "Symbol “\(symbol)” is not declared in Γ."
        case .negativeStepCount(let steps): "A saved step count cannot be negative (\(steps))."
        case .coordinateOverflow: "The next move exceeds the device's integer coordinate range. The configuration is unchanged."
        case .stepOverflow: "The step counter has reached the device's integer limit. The configuration is unchanged."
        }
    }
}

public struct TuringMachine: Sendable {
    public static let maximumUndoDepth = 4_096

    public private(set) var program: MachineProgram
    public private(set) var configuration: MachineConfiguration
    public private(set) var status: MachineStatus
    public private(set) var lastStep: StepRecord?

    private var rules: [RuleKey: Transition]
    private var history: [UndoDelta?]
    private var historyCount: Int = 0
    private var nextHistoryIndex: Int = 0
    private var resourceFailure: MachineValidationError?

    public init(program: MachineProgram) throws {
        let rules = try Self.validatedRules(for: program)
        let tape = Dictionary(uniqueKeysWithValues: program.initialTape.enumerated()
            .filter { $0.element != program.blank }.map { ($0.offset, $0.element) })
        self.program = program
        self.configuration = MachineConfiguration(state: program.initialState,
            head: program.initialHead, tape: tape, steps: 0)
        self.rules = rules
        self.status = .ready
        self.lastStep = nil
        self.history = Array(repeating: nil, count: Self.maximumUndoDepth)
        recomputeStatus(nonterminal: .ready)
    }

    /// Restores a logical configuration. Undo is local to the current session and starts empty.
    public init(program: MachineProgram, configuration: MachineConfiguration) throws {
        let rules = try Self.validatedRules(for: program)
        guard program.states.contains(configuration.state) else {
            throw MachineValidationError.stateNotDeclared(field: "Saved state", state: configuration.state)
        }
        guard configuration.steps >= 0 else {
            throw MachineValidationError.negativeStepCount(configuration.steps)
        }
        let alphabet = Set(program.tapeAlphabet)
        for symbol in configuration.tape.values where !alphabet.contains(symbol) {
            throw MachineValidationError.symbolNotInTapeAlphabet(symbol)
        }
        self.program = program
        self.configuration = configuration
        self.configuration.tape = configuration.tape.filter { $0.value != program.blank }
        self.rules = rules
        self.status = .ready
        self.lastStep = nil
        self.history = Array(repeating: nil, count: Self.maximumUndoDepth)
        recomputeStatus(nonterminal: .ready)
    }

    public var currentSymbol: String { symbol(at: configuration.head) }
    public var nextTransition: Transition? {
        guard configuration.state != program.acceptState,
              configuration.state != program.rejectState else { return nil }
        return rules[RuleKey(state: configuration.state, read: currentSymbol)]
    }
    public var canUndo: Bool { historyCount > 0 }
    public var undoDepth: Int { historyCount }

    public var statusDetail: String {
        if let resourceFailure { return resourceFailure.localizedDescription }
        switch status {
        case .ready: return "Ready to read \(currentSymbol) in state \(configuration.state)."
        case .running: return "\(configuration.steps) transitions completed. Read \(currentSymbol) in state \(configuration.state)."
        case .accepted: return "Accepted after \(configuration.steps) transitions."
        case .rejected: return "Rejected after \(configuration.steps) transitions."
        case .stuck: return "No rule for δ(\(configuration.state), \(currentSymbol)); execution is stuck."
        }
    }

    public func symbol(at coordinate: Int) -> String {
        configuration.tape[coordinate] ?? program.blank
    }

    /// Executes one complete δ lookup, write, movement, and state change atomically.
    /// No rule or an integer boundary leaves every part of the configuration unchanged.
    @discardableResult
    public mutating func step() -> StepRecord? {
        guard status == .ready || status == .running else { return nil }
        guard let transition = nextTransition else {
            status = .stuck
            return nil
        }
        let (nextHead, headOverflow) = configuration.head.addingReportingOverflow(transition.move.offset)
        guard !headOverflow else {
            resourceFailure = .coordinateOverflow
            status = .stuck
            return nil
        }
        let (nextStep, stepOverflow) = configuration.steps.addingReportingOverflow(1)
        guard !stepOverflow else {
            resourceFailure = .stepOverflow
            status = .stuck
            return nil
        }
        let record = StepRecord(id: nextStep, beforeState: configuration.state,
            afterState: transition.nextState, headBefore: configuration.head,
            headAfter: nextHead, read: currentSymbol, write: transition.write, move: transition.move)
        pushHistory(UndoDelta(record: record, previousSymbol: configuration.tape[configuration.head],
            previousStatus: status, previousLastStep: lastStep))
        configuration.tape[configuration.head] = transition.write == program.blank ? nil : transition.write
        configuration.head = nextHead
        configuration.state = transition.nextState
        configuration.steps = nextStep
        lastStep = record
        resourceFailure = nil
        recomputeStatus(nonterminal: .running)
        return record
    }

    /// Reverses the most recent successful transition, including a transition into a halting state.
    @discardableResult
    public mutating func undo() -> Bool {
        guard historyCount > 0 else { return false }
        nextHistoryIndex = (nextHistoryIndex + Self.maximumUndoDepth - 1) % Self.maximumUndoDepth
        guard let delta = history[nextHistoryIndex] else { return false }
        history[nextHistoryIndex] = nil
        historyCount -= 1
        configuration.state = delta.record.beforeState
        configuration.head = delta.record.headBefore
        configuration.tape[delta.record.headBefore] = delta.previousSymbol
        configuration.steps = delta.record.id - 1
        status = delta.previousStatus
        lastStep = delta.previousLastStep
        resourceFailure = nil
        return true
    }

    /// Reloads the program's original input, state, and head.
    public mutating func reset() {
        configuration = MachineConfiguration(state: program.initialState, head: program.initialHead,
            tape: Dictionary(uniqueKeysWithValues: program.initialTape.enumerated()
                .filter { $0.element != program.blank }.map { ($0.offset, $0.element) }), steps: 0)
        clearHistory()
        recomputeStatus(nonterminal: .ready)
    }

    /// Manual edits use Γ, preserve the current state and step count, and clear the undo trace.
    public mutating func setSymbol(_ symbol: String, at coordinate: Int) throws {
        guard program.tapeAlphabet.contains(symbol) else {
            throw MachineValidationError.symbolNotInTapeAlphabet(symbol)
        }
        configuration.tape[coordinate] = symbol == program.blank ? nil : symbol
        clearHistory()
        recomputeStatus(nonterminal: .ready)
    }

    public mutating func moveHead(to coordinate: Int) {
        configuration.head = coordinate
        clearHistory()
        recomputeStatus(nonterminal: .ready)
    }

    private mutating func pushHistory(_ delta: UndoDelta) {
        history[nextHistoryIndex] = delta
        nextHistoryIndex = (nextHistoryIndex + 1) % Self.maximumUndoDepth
        historyCount = min(historyCount + 1, Self.maximumUndoDepth)
    }

    private mutating func clearHistory() {
        history = Array(repeating: nil, count: Self.maximumUndoDepth)
        historyCount = 0
        nextHistoryIndex = 0
        lastStep = nil
        resourceFailure = nil
    }

    private mutating func recomputeStatus(nonterminal: MachineStatus) {
        if configuration.state == program.acceptState { status = .accepted }
        else if configuration.state == program.rejectState { status = .rejected }
        else if nextTransition == nil { status = .stuck }
        else { status = nonterminal }
    }

    private static func validatedRules(for program: MachineProgram) throws -> [RuleKey: Transition] {
        for (field, value) in [("Program ID", program.id), ("Program name", program.name)] {
            guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MachineValidationError.emptyValue(field)
            }
        }
        guard !program.blank.isEmpty else { throw MachineValidationError.emptyValue("Blank symbol") }
        var states = Set<String>()
        for state in program.states {
            guard !state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw MachineValidationError.emptyValue("State name")
            }
            guard states.insert(state).inserted else { throw MachineValidationError.duplicateState(state) }
        }
        for (field, state) in [("Initial state", program.initialState), ("Accept state", program.acceptState), ("Reject state", program.rejectState)] {
            guard states.contains(state) else { throw MachineValidationError.stateNotDeclared(field: field, state: state) }
        }
        guard program.acceptState != program.rejectState else { throw MachineValidationError.haltingStatesMustDiffer }
        var alphabetSets: [Set<String>] = []
        for (name, alphabet) in [("Σ", program.inputAlphabet), ("Γ", program.tapeAlphabet)] {
            var seen = Set<String>()
            for symbol in alphabet {
                guard !symbol.isEmpty else {
                    throw MachineValidationError.emptyValue("Symbol in \(name)")
                }
                guard seen.insert(symbol).inserted else {
                    throw MachineValidationError.duplicateSymbol(alphabet: name, symbol: symbol)
                }
            }
            alphabetSets.append(seen)
        }
        let input = alphabetSets[0]
        let tape = alphabetSets[1]
        guard tape.contains(program.blank) else { throw MachineValidationError.blankNotInTapeAlphabet(program.blank) }
        guard !input.contains(program.blank) else { throw MachineValidationError.blankInInputAlphabet(program.blank) }
        for symbol in program.inputAlphabet where !tape.contains(symbol) {
            throw MachineValidationError.inputSymbolNotInTapeAlphabet(symbol)
        }
        for (index, symbol) in program.initialTape.enumerated() where symbol != program.blank && !input.contains(symbol) {
            throw MachineValidationError.initialSymbolNotInInputAlphabet(index: index, symbol: symbol)
        }
        var rules: [RuleKey: Transition] = [:]
        for transition in program.transitions {
            for (field, state) in [("Transition source", transition.state), ("Transition destination", transition.nextState)] {
                guard states.contains(state) else { throw MachineValidationError.stateNotDeclared(field: field, state: state) }
            }
            guard transition.state != program.acceptState && transition.state != program.rejectState else {
                throw MachineValidationError.transitionFromHaltingState(transition.state)
            }
            for (field, symbol) in [("read", transition.read), ("write", transition.write)] where !tape.contains(symbol) {
                throw MachineValidationError.transitionSymbolNotDeclared(field: field, symbol: symbol)
            }
            let key = RuleKey(state: transition.state, read: transition.read)
            guard rules[key] == nil else {
                throw MachineValidationError.duplicateTransition(state: transition.state, read: transition.read)
            }
            rules[key] = transition
        }
        return rules
    }
}

private struct RuleKey: Hashable, Sendable {
    var state: String
    var read: String
}

private struct UndoDelta: Sendable {
    var record: StepRecord
    var previousSymbol: String?
    var previousStatus: MachineStatus
    var previousLastStep: StepRecord?
}
