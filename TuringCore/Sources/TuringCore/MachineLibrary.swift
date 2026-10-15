/// Small, inspectable programs whose behavior follows their transition tables exactly.
public enum MachineLibrary {
    public static let increment = MachineProgram(
        id: "binary-increment", name: "Binary increment", summary: "Add one, one tape cell at a time.",
        states: ["scan", "carry", "rewind", "accept", "reject"],
        inputAlphabet: ["0", "1"], tapeAlphabet: ["0", "1", "□"], blank: "□",
        initialState: "scan", acceptState: "accept", rejectState: "reject",
        transitions: [
            rule("scan", "0", "0", .right, "scan"),
            rule("scan", "1", "1", .right, "scan"),
            rule("scan", "□", "□", .left, "carry"),
            rule("carry", "0", "1", .left, "rewind"),
            rule("carry", "1", "0", .left, "carry"),
            rule("carry", "□", "1", .right, "accept"),
            rule("rewind", "0", "0", .left, "rewind"),
            rule("rewind", "1", "1", .left, "rewind"),
            rule("rewind", "□", "□", .right, "accept")
        ], initialTape: ["1", "0", "1", "1"], initialHead: 0,
        explanation: "Scan right to the blank after the binary word. Carry left: replace each trailing 1 with 0, then change the first 0 to 1. If the carry reaches a blank, write a new leading 1 there. Rewind to the beginning and accept. The two-way tape lets overflow use cell −1. An empty word is treated as zero.")

    public static let unaryDoubling = MachineProgram(
        id: "unary-doubling", name: "Unary doubling", summary: "Make one copy for every original mark.",
        states: ["choose", "append", "return", "cleanLeft", "cleanRight", "accept", "reject"],
        inputAlphabet: ["1"], tapeAlphabet: ["1", "X", "Y", "□"], blank: "□",
        initialState: "choose", acceptState: "accept", rejectState: "reject",
        transitions: [
            rule("choose", "1", "X", .right, "append"),
            rule("choose", "X", "X", .right, "choose"),
            rule("choose", "Y", "Y", .left, "cleanLeft"),
            rule("choose", "□", "□", .right, "accept"),
            rule("append", "1", "1", .right, "append"),
            rule("append", "X", "X", .right, "append"),
            rule("append", "Y", "Y", .right, "append"),
            rule("append", "□", "Y", .left, "return"),
            rule("return", "1", "1", .left, "return"),
            rule("return", "X", "X", .left, "return"),
            rule("return", "Y", "Y", .left, "return"),
            rule("return", "□", "□", .right, "choose"),
            rule("cleanLeft", "X", "1", .left, "cleanLeft"),
            rule("cleanLeft", "□", "□", .right, "cleanRight"),
            rule("cleanRight", "1", "1", .right, "cleanRight"),
            rule("cleanRight", "Y", "1", .right, "cleanRight"),
            rule("cleanRight", "□", "□", .left, "accept")
        ], initialTape: ["1", "1", "1"], initialHead: 0,
        explanation: "Choose the first original 1 and mark it X. Travel to the right edge and append a Y as its copy. Return to the left edge and repeat. Y marks distinguish copies from originals, so a copy is never copied again. When all originals are X, sweep through the tape to restore X and Y to 1. The result is a contiguous unary word of twice the original length.")

    public static let palindrome = MachineProgram(
        id: "binary-palindrome", name: "Palindrome test", summary: "Compare the two ends of a binary word.",
        states: ["choose", "seek0", "seek1", "check0", "check1", "return", "accept", "reject"],
        inputAlphabet: ["0", "1"], tapeAlphabet: ["0", "1", "X", "Y", "□"], blank: "□",
        initialState: "choose", acceptState: "accept", rejectState: "reject",
        transitions: palindromeRules, initialTape: ["0", "1", "1", "0"], initialHead: 0,
        explanation: "Mark the leftmost unexamined bit: X remembers 0 and Y remembers 1. Scan to the right edge, skip marked cells, and compare the rightmost unexamined bit. A mismatch enters reject. A match is marked, then the head returns to the left edge. Accept when no unexamined symbols remain, including a single center bit or the empty word. This is a decider for binary palindromes.")

    /// The three-state, two-symbol step champion: 21 transitions and five 1s.
    public static let busyBeaver = MachineProgram(
        id: "three-state-busy-beaver", name: "Busy beaver · 21 steps", summary: "Three working states. Five marks. Twenty-one steps.",
        states: ["A", "B", "C", "accept", "reject"],
        inputAlphabet: ["1"], tapeAlphabet: ["0", "1"], blank: "0",
        initialState: "A", acceptState: "accept", rejectState: "reject",
        transitions: [
            rule("A", "0", "1", .right, "B"),
            rule("A", "1", "1", .right, "accept"),
            rule("B", "0", "1", .left, "B"),
            rule("B", "1", "0", .right, "C"),
            rule("C", "0", "1", .left, "C"),
            rule("C", "1", "1", .left, "A")
        ], initialTape: [], initialHead: 0,
        explanation: "Begin on an all-zero tape. Here 0 is blank and 1 is a mark. The six rules use only working states A, B, and C; accept is the halting state. This three-state, two-symbol step champion takes exactly 21 transitions and leaves five 1s. The separate mark champion leaves six 1s in 14 transitions: maximizing steps and maximizing marks are distinct problems. This preset is a concrete machine, not a solver for arbitrary busy beaver values.")

    public static let busyBeaverMarks = MachineProgram(
        id: "three-state-busy-beaver-marks", name: "Busy beaver · 6 marks", summary: "Three working states. Six marks. Fourteen steps.",
        states: ["A", "B", "C", "accept", "reject"],
        inputAlphabet: ["1"], tapeAlphabet: ["0", "1"], blank: "0",
        initialState: "A", acceptState: "accept", rejectState: "reject",
        transitions: [
            rule("A", "0", "1", .right, "B"),
            rule("A", "1", "1", .right, "accept"),
            rule("B", "0", "0", .right, "C"),
            rule("B", "1", "1", .right, "B"),
            rule("C", "0", "1", .left, "C"),
            rule("C", "1", "1", .left, "A")
        ], initialTape: [], initialHead: 0,
        explanation: "Begin on an all-zero tape; 0 is blank. This three-state, two-symbol mark champion halts after 14 transitions with six 1s, the largest number of marks a halting machine of this size can leave. Compare its B rules with the 21-step champion. Maximizing output marks and maximizing runtime have different winners at three states.")

    public static let inverter = MachineProgram(
        id: "bit-inverter", name: "Bit inverter", summary: "Invert a binary word with one working state.",
        states: ["flip", "accept", "reject"], inputAlphabet: ["0", "1"],
        tapeAlphabet: ["0", "1", "□"], blank: "□", initialState: "flip",
        acceptState: "accept", rejectState: "reject",
        transitions: [
            rule("flip", "0", "1", .right, "flip"),
            rule("flip", "1", "0", .right, "flip"),
            rule("flip", "□", "□", .left, "accept")
        ], initialTape: ["1", "0", "1", "1", "0", "0", "0", "1"], initialHead: 0,
        explanation: "Read the current bit, write its complement, and move right while staying in flip. On the first blank, move left and enter accept. There is no hidden arithmetic: one transition changes one cell. This is the smallest preset for learning the read → write → move → state cycle.")

    public static let clockworkLoop = MachineProgram(
        id: "clockwork-loop", name: "Clockwork loop", summary: "Two states return to the same tape and head forever.",
        states: ["right", "left", "accept", "reject"], inputAlphabet: [], tapeAlphabet: ["□"], blank: "□",
        initialState: "right", acceptState: "accept", rejectState: "reject",
        transitions: [
            rule("right", "□", "□", .right, "left"),
            rule("left", "□", "□", .left, "right")
        ], initialTape: [], initialHead: 0,
        explanation: "In right, move from cell 0 to cell 1 and enter left. In left, return to cell 0 and enter right. Both transitions leave the blank tape unchanged. Every two transitions reproduce the same state, head position, and tape, proving that this particular machine never halts. Recognizing this simple loop does not solve the general halting problem: no algorithm can decide whether every arbitrary Turing machine will eventually halt.")

    public static let programs = [increment, unaryDoubling, palindrome, busyBeaver, busyBeaverMarks, inverter, clockworkLoop]

    private static func rule(_ state: String, _ read: String, _ write: String,
                             _ move: HeadMove, _ next: String) -> Transition {
        Transition(state: state, read: read, write: write, move: move, nextState: next)
    }

    private static var palindromeRules: [Transition] {
        var result = [
            rule("choose", "0", "X", .right, "seek0"),
            rule("choose", "1", "Y", .right, "seek1"),
            rule("choose", "X", "X", .right, "choose"),
            rule("choose", "Y", "Y", .right, "choose"),
            rule("choose", "□", "□", .right, "accept"),
            rule("check0", "0", "X", .left, "return"),
            rule("check0", "1", "1", .right, "reject"),
            rule("check1", "1", "Y", .left, "return"),
            rule("check1", "0", "0", .right, "reject")
        ]
        for bit in ["0", "1"] {
            let seek = "seek\(bit)"
            let check = "check\(bit)"
            for symbol in ["0", "1", "X", "Y"] {
                result.append(rule(seek, symbol, symbol, .right, seek))
            }
            result.append(rule(seek, "□", "□", .left, check))
            for symbol in ["X", "Y"] {
                result.append(rule(check, symbol, symbol, .left, check))
            }
            result.append(rule(check, "□", "□", .right, "accept"))
        }
        for symbol in ["0", "1", "X", "Y"] {
            result.append(rule("return", symbol, symbol, .left, "return"))
        }
        result.append(rule("return", "□", "□", .right, "choose"))
        return result
    }
}
