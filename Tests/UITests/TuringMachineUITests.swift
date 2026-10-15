import XCTest

@MainActor
final class TuringMachineUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--fresh-session"]
        app.launch()
        XCTAssertTrue(app.buttons["machine.step"].waitForExistence(timeout: 15))
        return app
    }

    func testAtomicStepRewindAndReset() {
        let app = launch()
        XCTAssertEqual(app.staticTexts["machine.steps"].value as? String, "0")
        app.buttons["machine.step"].tap()
        XCTAssertEqual(app.staticTexts["machine.steps"].value as? String, "1")
        XCTAssertEqual(app.staticTexts["machine.head"].value as? String, "1")
        app.buttons["machine.back"].tap()
        XCTAssertEqual(app.staticTexts["machine.steps"].value as? String, "0")
        XCTAssertEqual(app.staticTexts["machine.head"].value as? String, "0")
        app.buttons["machine.step"].tap()
        app.buttons["machine.reset"].tap()
        XCTAssertEqual(app.staticTexts["machine.steps"].value as? String, "0")
    }

    func testTapeEditAndHeadPlacement() {
        let app = launch()
        app.buttons["tape.cell.1"].tap()
        XCTAssertTrue(app.buttons["tape.placeHead"].waitForExistence(timeout: 5))
        app.buttons["tape.placeHead"].tap()
        XCTAssertEqual(app.staticTexts["machine.head"].value as? String, "1")
        app.buttons["tape.cell.1"].tap()
        app.buttons["tape.write.1"].tap()
        XCTAssertTrue(app.buttons["tape.cell.1"].label.contains("1, under the head"))
    }

    func testInputLoadAndAcceptingOutput() {
        let app = launch()
        app.buttons["machine.input"].tap()
        let word = app.textFields["input.word"]
        XCTAssertTrue(word.waitForExistence(timeout: 5))
        word.tap()
        word.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "0")
        app.buttons["input.load"].tap()
        XCTAssertTrue(app.buttons["machine.step"].waitForExistence(timeout: 5))
        for _ in 0..<4 { app.buttons["machine.step"].tap() }
        XCTAssertTrue(app.staticTexts["machine.outcome"].label.contains("Accepted"))
        XCTAssertFalse(app.buttons["machine.step"].isEnabled)
        XCTAssertTrue(app.buttons["tape.cell.0"].label.contains(", 1"))
    }
}
