import Foundation
import XCTest
import TuringCore
@testable import TuringMachine

@MainActor
final class MachineSessionTests: XCTestCase {
    private func isolatedStorage() throws -> (UserDefaults, String) {
        let suite = "com.utkarsh.turingmachine.session-tests." + UUID().uuidString
        let storage = try XCTUnwrap(UserDefaults(suiteName: suite))
        storage.removePersistentDomain(forName: suite)
        return (storage, suite)
    }

    private func waitUntil(timeout: Duration = .seconds(5),
                           _ predicate: () -> Bool) async throws -> Bool {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !predicate(), ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(25))
        }
        return predicate()
    }

    func testNaturalTerminalRunPersistsExactConfigurationBeforeManualPause() async throws {
        let (storage, suite) = try isolatedStorage()
        let session = MachineSession(storage: storage)
        defer {
            session.pause()
            storage.removePersistentDomain(forName: suite)
        }
        session.haptics = false
        session.sound = false
        session.speed = 12
        session.toggleRun()

        let halted = try await waitUntil { !session.isRunning }
        XCTAssertTrue(halted, "The ten-transition increment should halt within five seconds at 12 Hz.")
        XCTAssertEqual(session.machine.status, .accepted)
        XCTAssertEqual(session.machine.configuration.steps, 10)
        XCTAssertFalse(session.canStep)

        // Ten is below the periodic checkpoint of twenty. This must be the natural-halt save.
        let data = try XCTUnwrap(storage.data(forKey: "turing.session"))
        let saved = try JSONDecoder().decode(MachineSession.SavedSession.self, from: data)
        XCTAssertEqual(saved.configuration, session.machine.configuration)
        XCTAssertEqual(saved.program, session.machine.program)
        XCTAssertEqual(saved.speed, 12)

        session.pause()
        let restored = MachineSession(storage: storage)
        XCTAssertEqual(restored.machine.configuration, session.machine.configuration)
        XCTAssertEqual(restored.machine.status, .accepted)
        XCTAssertFalse(restored.isRunning)
        XCTAssertFalse(restored.canStep)
        XCTAssertTrue(restored.records.isEmpty)
        XCTAssertFalse(restored.machine.canUndo, "Undo history belongs to the current live session.")
    }

    func testManualTapeAndHeadEditsClearTraceAndPreserveLogicalStateAndStepCount() throws {
        let (storage, suite) = try isolatedStorage()
        let session = MachineSession(storage: storage)
        defer {
            session.pause()
            storage.removePersistentDomain(forName: suite)
        }
        session.haptics = false
        session.select(MachineLibrary.unaryDoubling)
        session.step()
        XCTAssertEqual(session.records.count, 1)
        XCTAssertTrue(session.machine.canUndo)
        let stateBeforeWrite = session.machine.configuration.state
        let stepsBeforeWrite = session.machine.configuration.steps

        session.write("Y", at: -7)
        XCTAssertEqual(session.machine.configuration.state, stateBeforeWrite)
        XCTAssertEqual(session.machine.configuration.steps, stepsBeforeWrite)
        XCTAssertEqual(session.machine.symbol(at: -7), "Y")
        XCTAssertEqual(session.machine.symbol(at: 0), "X", "The original transition's tape write is retained.")
        XCTAssertTrue(session.records.isEmpty)
        XCTAssertFalse(session.machine.canUndo)
        XCTAssertNil(session.machine.lastStep)

        session.step()
        XCTAssertEqual(session.records.count, 1)
        XCTAssertTrue(session.machine.canUndo)
        let stateBeforeMove = session.machine.configuration.state
        let stepsBeforeMove = session.machine.configuration.steps
        session.placeHead(at: -7)
        XCTAssertEqual(session.machine.configuration.head, -7)
        XCTAssertEqual(session.machine.configuration.state, stateBeforeMove)
        XCTAssertEqual(session.machine.configuration.steps, stepsBeforeMove)
        XCTAssertEqual(session.machine.currentSymbol, "Y")
        XCTAssertTrue(session.records.isEmpty)
        XCTAssertFalse(session.machine.canUndo)
        XCTAssertNil(session.machine.lastStep)

        let persisted = try JSONDecoder().decode(MachineSession.SavedSession.self,
            from: XCTUnwrap(storage.data(forKey: "turing.session")))
        XCTAssertEqual(persisted.configuration, session.machine.configuration)
    }

    func testSelectingProgramCancelsRunnerAndPreventsStaleAdvances() async throws {
        let (storage, suite) = try isolatedStorage()
        let session = MachineSession(storage: storage)
        defer {
            session.pause()
            storage.removePersistentDomain(forName: suite)
        }
        session.haptics = false
        session.speed = 12
        session.select(MachineLibrary.clockworkLoop)
        session.toggleRun()
        let began = try await waitUntil(timeout: .seconds(1)) {
            session.machine.configuration.steps > 0
        }
        XCTAssertTrue(began)
        XCTAssertTrue(session.isRunning)

        session.select(MachineLibrary.inverter)
        let selected = session.machine.configuration
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(session.machine.program, MachineLibrary.inverter)
        XCTAssertEqual(session.machine.configuration, selected,
                       "A cancelled clockwork task must not commit a transition to the newly selected machine.")
        XCTAssertEqual(session.machine.configuration.steps, 0)
        XCTAssertEqual(session.machine.status, .ready)
        XCTAssertFalse(session.isRunning)
        XCTAssertTrue(session.records.isEmpty)

        // Also cancel before a newly scheduled task gets its first main-actor turn.
        session.toggleRun()
        session.pause()
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertEqual(session.machine.configuration, selected)
        XCTAssertTrue(session.records.isEmpty)
    }

    func testInputCodecPreservesMixedLengthSymbolsAndQuotedAtomicTokens() throws {
        let mixed = ["0", "1", "01"]
        for input in [["0", "1"], ["01"], ["0", "01", "1"], []] {
            let text = RuleDraftCodec.formatWord(input, alphabet: mixed)
            XCTAssertEqual(try RuleDraftCodec.parseWord(text, alphabet: mixed), input,
                           "Formatting must preserve tape-cell boundaries for a mixed-length alphabet.")
            // The no-alphabet serializer must remain safe for callers without alphabet context.
            let fallback = RuleDraftCodec.formatWord(input)
            XCTAssertEqual(try RuleDraftCodec.parseWord(fallback, alphabet: mixed), input)
        }
        XCTAssertEqual(RuleDraftCodec.formatWord(["1", "0", "1", "1"], alphabet: ["0", "1"]), "1011")

        let special = ["alpha beta", "\"", " ", ",", "red"]
        let input = ["alpha beta", " ", "\"", ",", "red"]
        let encoded = RuleDraftCodec.formatWord(input, alphabet: special)
        XCTAssertEqual(try RuleDraftCodec.parseWord(encoded, alphabet: special), input)
    }

    func testRestoredIntegerBoundariesStopAtomicallyAndDisableFurtherSteps() throws {
        let cases = [
            MachineConfiguration(state: "right", head: Int.max, tape: [:], steps: 41),
            MachineConfiguration(state: "left", head: Int.min, tape: [:], steps: 41),
            MachineConfiguration(state: "right", head: 0, tape: [:], steps: Int.max)
        ]
        for configuration in cases {
            let (storage, suite) = try isolatedStorage()
            let saved = MachineSession.SavedSession(program: MachineLibrary.clockworkLoop,
                configuration: configuration, speed: 3)
            storage.set(try JSONEncoder().encode(saved), forKey: "turing.session")
            let session = MachineSession(storage: storage)
            defer {
                session.pause()
                storage.removePersistentDomain(forName: suite)
            }
            session.haptics = false
            XCTAssertEqual(session.machine.configuration, configuration)
            XCTAssertTrue(session.canStep, "The formal rule exists before the implementation boundary is attempted.")

            session.step()
            XCTAssertEqual(session.machine.status, .stuck)
            XCTAssertEqual(session.statusLabel, "RESOURCE LIMIT")
            XCTAssertFalse(session.canStep)
            XCTAssertFalse(session.isRunning)
            XCTAssertEqual(session.machine.configuration, configuration, "An overflow must not partially commit a rule.")
            XCTAssertTrue(session.records.isEmpty)
            XCTAssertFalse(session.machine.canUndo)

            session.step()
            XCTAssertEqual(session.machine.configuration, configuration)
            XCTAssertTrue(session.records.isEmpty)
        }
    }

    func testPhysicalCoreMotionSensorCalibratesAndStops() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("Physical Core Motion check")
        #else
        let lighting = MotionLighting()
        defer { lighting.stop() }
        XCTAssertTrue(lighting.isAvailable, "The physical iPhone should provide a device-motion sensor.")
        lighting.start()
        let received = try await waitUntil(timeout: .seconds(3)) {
            lighting.receivedSamples > 0
        }
        XCTAssertTrue(received, "Device-motion updates should reach the lighting model within three seconds.")
        XCTAssertGreaterThan(lighting.receivedSamples, 0)
        XCTAssertTrue(lighting.isAvailable)
        XCTAssertTrue(lighting.x.isFinite)
        XCTAssertTrue(lighting.y.isFinite)
        XCTAssertGreaterThanOrEqual(lighting.x, -1)
        XCTAssertLessThanOrEqual(lighting.x, 1)
        XCTAssertGreaterThanOrEqual(lighting.y, -1)
        XCTAssertLessThanOrEqual(lighting.y, 1)

        lighting.calibrate()
        XCTAssertEqual(lighting.x, 0)
        XCTAssertEqual(lighting.y, 0)
        lighting.stop()
        XCTAssertEqual(lighting.x, 0)
        XCTAssertEqual(lighting.y, 0)
        #endif
    }
}
