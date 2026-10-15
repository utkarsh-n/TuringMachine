import Foundation
import TuringCore

struct DraftParseError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

enum RuleDraftCodec {
    static func parseScalar(_ text: String, field: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw DraftParseError("\(field) cannot be empty. Put a whitespace symbol in double quotes, such as \" \".")
        }
        if trimmed.first == "\"" {
            let values = try tokens(trimmed, context: field)
            guard values.count == 1, let value = values.first, !value.isEmpty else {
                throw DraftParseError("\(field) must contain one nonempty value.")
            }
            return value
        }
        return trimmed
    }

    /// Compact words are convenient for single-character alphabets. Quoted tokens
    /// preserve multi-character symbols, including a single symbol on its own.
    static func parseWord(_ text: String, alphabet: [String]? = nil) throws -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let compactAlphabet = alphabet?.allSatisfy { $0.count == 1 } ?? true
        if compactAlphabet, !trimmed.contains(where: { $0.isWhitespace || $0 == "\"" }) {
            return trimmed.map(String.init)
        }
        return try tokens(trimmed, context: "Initial input")
    }

    static func formatWord(_ symbols: [String], alphabet: [String]? = nil) -> String {
        let compactAlphabet = alphabet?.allSatisfy { $0.count == 1 } ?? false
        if compactAlphabet, symbols.allSatisfy({ $0.count == 1 && !$0.contains(where: { $0.isWhitespace || $0 == "\"" }) }) {
            return symbols.joined()
        }
        return symbols.map { symbol in
            if symbol.count != 1 {
                return "\"" + symbol.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return quote(symbol)
        }.joined(separator: " ")
    }

    static func encode(_ rules: [TuringCore.Transition]) -> String {
        rules.map { rule in
            "\(quote(rule.state)) \(quote(rule.read)) → \(quote(rule.write)) \(rule.move == .left ? "L" : "R") \(quote(rule.nextState))"
        }.joined(separator: "\n")
    }

    static func quote(_ value: String) -> String {
        if value.isEmpty || value.contains(where: { $0.isWhitespace || $0 == "\"" }) {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }

    static func decode(_ text: String) throws -> [TuringCore.Transition] {
        var result: [TuringCore.Transition] = []
        var seen = Set<RuleKey>()
        for (index, line) in text.components(separatedBy: .newlines).enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let context = "Rule line \(index + 1)"
            let values = try tokens(trimmed, context: context)
            guard values.count == 6, values[2] == "→" || values[2] == "->" else {
                throw DraftParseError("\(context): use state read → write L/R nextState (six values).")
            }
            let move: HeadMove
            switch values[4].uppercased() {
            case "L": move = .left
            case "R": move = .right
            default: throw DraftParseError("\(context): movement must be L or R.")
            }
            let key = RuleKey(state: values[0], read: values[1])
            guard seen.insert(key).inserted else {
                throw DraftParseError("\(context): a rule for (\(values[0]), \(values[1])) already exists. A deterministic machine allows only one.")
            }
            result.append(TuringCore.Transition(state: values[0], read: values[1], write: values[3], move: move, nextState: values[5]))
        }
        return result
    }

    static func tokens(_ text: String, context: String) throws -> [String] {
        let characters = Array(text)
        var index = 0
        var result: [String] = []
        while index < characters.count {
            while index < characters.count, characters[index].isWhitespace { index += 1 }
            guard index < characters.count else { break }
            var token = ""
            if characters[index] == "\"" {
                index += 1
                var closed = false
                while index < characters.count {
                    if characters[index] == "\"" {
                        if index + 1 < characters.count, characters[index + 1] == "\"" {
                            token.append("\"")
                            index += 2
                        } else {
                            closed = true
                            index += 1
                            break
                        }
                    } else {
                        token.append(characters[index])
                        index += 1
                    }
                }
                guard closed else { throw DraftParseError("\(context): close the quoted value with a double quote.") }
                guard index == characters.count || characters[index].isWhitespace else {
                    throw DraftParseError("\(context): separate each quoted value with a space.")
                }
            } else {
                while index < characters.count, !characters[index].isWhitespace {
                    guard characters[index] != "\"" else {
                        throw DraftParseError("\(context): put double quotes around the complete value.")
                    }
                    token.append(characters[index])
                    index += 1
                }
            }
            result.append(token)
        }
        return result
    }

    private struct RuleKey: Hashable {
        let state: String
        let read: String
    }
}

enum CommaDraftCodec {
    static func encode(_ values: [String]) -> String {
        values.map { value in
            if value.contains(",") || value.contains("\"") || value != value.trimmingCharacters(in: .whitespacesAndNewlines) {
                return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
            }
            return value
        }.joined(separator: ", ")
    }

    static func decode(_ text: String, field: String) throws -> [String] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return [] }
        let characters = Array(text)
        var index = 0
        var result: [String] = []
        while index < characters.count {
            while index < characters.count, characters[index].isWhitespace { index += 1 }
            var value = ""
            if index < characters.count, characters[index] == "\"" {
                index += 1
                var closed = false
                while index < characters.count {
                    if characters[index] == "\"" {
                        if index + 1 < characters.count, characters[index + 1] == "\"" {
                            value.append("\"")
                            index += 2
                        } else {
                            index += 1
                            closed = true
                            break
                        }
                    } else {
                        value.append(characters[index])
                        index += 1
                    }
                }
                guard closed else { throw DraftParseError("\(field): close the quoted value with a double quote.") }
                while index < characters.count, characters[index].isWhitespace { index += 1 }
                guard index == characters.count || characters[index] == "," else {
                    throw DraftParseError("\(field): separate values with commas.")
                }
            } else {
                while index < characters.count, characters[index] != "," {
                    guard characters[index] != "\"" else {
                        throw DraftParseError("\(field): put double quotes around the complete value.")
                    }
                    value.append(characters[index])
                    index += 1
                }
                value = value.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard !value.isEmpty else { throw DraftParseError("\(field): remove the empty value between commas.") }
            result.append(value)
            if index < characters.count {
                index += 1
                guard index < characters.count else { throw DraftParseError("\(field): remove the trailing comma.") }
            }
        }
        return result
    }
}
