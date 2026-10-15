import Foundation
import Observation
import TuringCore
import UIKit

@MainActor @Observable
final class MachineSession {
    private(set) var machine: TuringMachine
    private(set) var isRunning = false
    private(set) var records: [StepRecord] = []
    private(set) var customPrograms: [MachineProgram] = []
    var speed: Double = 3
    var haptics = true
    var sound = false
    var error: String?
    var pauseReason: String?
    var tapeFocus: Int?
    private var runner: Task<Void, Never>?
    private let feedback = MachineFeedback()
    private let storage: UserDefaults
    private var runGeneration = 0
    static let sessionStepBudget = 100_000
    static let cellBudget = 50_000

    struct SavedSession: Codable {
        let program: MachineProgram
        let configuration: MachineConfiguration
        let speed: Double
    }

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        // The bundled definitions are validated independently by the core suite.
        do { machine = try TuringMachine(program: MachineLibrary.increment) }
        catch { preconditionFailure("Invalid bundled Turing machine: \(error)") }
        if let data = storage.data(forKey: "turing.customPrograms"),
           let saved = try? JSONDecoder().decode([MachineProgram].self, from: data) {
            customPrograms = saved.filter { (try? TuringMachine(program: $0)) != nil }
        }
        haptics = storage.object(forKey: "turing.haptics") as? Bool ?? true
        sound = storage.bool(forKey: "turing.sound")
        if !ProcessInfo.processInfo.arguments.contains("--fresh-session"),
           let data = storage.data(forKey: "turing.session"),
           let saved = try? JSONDecoder().decode(SavedSession.self, from: data),
           let restored = try? TuringMachine(program: saved.program, configuration: saved.configuration) {
            machine = restored
            speed = min(12, max(1, saved.speed))
        }
        if ProcessInfo.processInfo.arguments.contains("--fresh-session") { persist() }
    }

    var programs: [MachineProgram] { MachineLibrary.programs + customPrograms }
    var canStep: Bool {
        (machine.status == .ready || machine.status == .running) && machine.nextTransition != nil
    }
    var statusLabel: String {
        if isRunning { return "RUNNING" }
        switch machine.status {
        case .accepted: return "ACCEPTED"
        case .rejected: return "REJECTED"
        case .stuck: return machine.nextTransition == nil ? "NO RULE" : "RESOURCE LIMIT"
        case .ready, .running: return machine.configuration.steps == 0 ? "READY" : "PAUSED"
        }
    }

    func select(_ program: MachineProgram, saveAsCustom: Bool = false) {
        pause()
        do {
            let fresh = try TuringMachine(program: program)
            machine = fresh
            records = []
            pauseReason = nil
            tapeFocus = nil
            if saveAsCustom {
                customPrograms.removeAll { $0.id == program.id }
                customPrograms.append(program)
                if let data = try? JSONEncoder().encode(customPrograms) {
                    storage.set(data, forKey: "turing.customPrograms")
                }
            }
            feedback.selection(enabled: haptics)
            persist()
        } catch { self.error = error.localizedDescription }
    }

    func step() {
        pause()
        advance()
        persist()
    }

    private func advance() {
        guard let record = machine.step() else { pause(); persist(); return }
        records.append(record)
        if records.count > 4096 { records.removeFirst(records.count - 4096) }
        tapeFocus = nil
        feedback.step(direction: record.move, outcome: machine.status, haptics: haptics, sound: sound)
        if !canStep { pause(); persist() }
    }

    func toggleRun() {
        if isRunning { pause(); persist(); return }
        guard canStep else { return }
        pauseReason = nil
        isRunning = true
        runGeneration += 1
        let generation = runGeneration
        let startingSteps = machine.configuration.steps
        runner = Task { [weak self] in
            while let self, !Task.isCancelled, self.isRunning, generation == self.runGeneration {
                if self.machine.configuration.steps - startingSteps >= Self.sessionStepBudget ||
                    self.machine.configuration.tape.count >= Self.cellBudget {
                    self.pauseReason = self.machine.configuration.tape.count >= Self.cellBudget
                        ? "Storage pause at 50,000 nonblank cells. The machine has not halted. Erase cells or reset before running again; manual stepping remains available."
                        : "Resource pause after 100,000 steps in this run. The machine has not halted. Continue running, step manually, or reset."
                    self.pause()
                    self.persist()
                    break
                }
                self.advance()
                if self.machine.configuration.steps.isMultiple(of: 20) { self.persist() }
                do { try await Task.sleep(for: .seconds(1 / self.speed)) }
                catch { break }
            }
        }
    }

    func pause() {
        isRunning = false
        runGeneration += 1
        runner?.cancel()
        runner = nil
    }

    func undo() {
        pause()
        if machine.undo() {
            records.removeAll { $0.id > machine.configuration.steps }
            tapeFocus = nil
            pauseReason = nil
            feedback.selection(enabled: haptics)
        }
        persist()
    }

    func reset() {
        pause()
        machine.reset()
        records = []
        tapeFocus = nil
        pauseReason = nil
        feedback.selection(enabled: haptics)
        persist()
    }

    func write(_ symbol: String, at position: Int) {
        pause()
        do {
            try machine.setSymbol(symbol, at: position)
            records = []
            feedback.selection(enabled: haptics)
            persist()
        } catch { self.error = error.localizedDescription }
    }

    func placeHead(at position: Int) {
        pause()
        machine.moveHead(to: position)
        records = []
        tapeFocus = nil
        feedback.selection(enabled: haptics)
        persist()
    }

    func loadInput(_ input: [String], head: Int) {
        var program = machine.program
        program.initialTape = input
        program.initialHead = head
        select(program)
    }

    func persist() {
        let saved = SavedSession(program: machine.program, configuration: machine.configuration, speed: speed)
        if let data = try? JSONEncoder().encode(saved) { storage.set(data, forKey: "turing.session") }
        storage.set(haptics, forKey: "turing.haptics")
        storage.set(sound, forKey: "turing.sound")
    }
}
