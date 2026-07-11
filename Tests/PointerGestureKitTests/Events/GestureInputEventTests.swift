import PointerGestureKit
import XCTest

final class GestureInputEventTests: XCTestCase {
  func testInitializerStoresKindLocationAndModifiers() {
    let event = GestureInputEvent(
      kind: .buttonMoved(.secondary),
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.command, .shift]
    )

    assertKind(event.kind, .buttonMoved(.secondary))
    XCTAssertEqual(event.location, GesturePoint(x: 10, y: 20))
    XCTAssertEqual(event.modifiers, [.command, .shift])
  }

  func testInitializerDefaultsToNoModifiers() {
    let event = GestureInputEvent(
      kind: .buttonDown(.secondary),
      location: .zero
    )

    XCTAssertEqual(event.modifiers, [])
  }

  func testCancelEventKeepsSourceLocationAndModifiers() {
    let event = GestureInputEvent(
      kind: .cancel,
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.option]
    )

    assertKind(event.kind, .cancel)
    XCTAssertEqual(event.location, GesturePoint(x: 10, y: 20))
    XCTAssertEqual(event.modifiers, [.option])
  }

  func testInputKindCasesExposeButtonPayloads() {
    assertKind(.buttonDown(.primary), .buttonDown(.primary))
    assertKind(.buttonMoved(.secondary), .buttonMoved(.secondary))
    assertKind(.buttonUp(.middle), .buttonUp(.middle))
  }

  func testSendableContractAcceptsEventAndKindValues() {
    assertSendable(
      GestureInputEvent(
        kind: .buttonDown(.secondary),
        location: GesturePoint(x: 10, y: 20),
        modifiers: [.command]
      )
    )
    assertSendable(GestureInputEvent.Kind.buttonMoved(.secondary))
  }

  func testEquatableContractComparesValues() {
    let event = GestureInputEvent(
      kind: .buttonMoved(.secondary),
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.command]
    )

    XCTAssertEqual(event, event)
  }

  private func assertKind(
    _ kind: GestureInputEvent.Kind,
    _ expected: ExpectedKind,
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    switch (kind, expected) {
    case let (.buttonDown(button), .buttonDown(expectedButton)):
      XCTAssertEqual(button, expectedButton, file: file, line: line)
    case let (.buttonMoved(button), .buttonMoved(expectedButton)):
      XCTAssertEqual(button, expectedButton, file: file, line: line)
    case let (.buttonUp(button), .buttonUp(expectedButton)):
      XCTAssertEqual(button, expectedButton, file: file, line: line)
    case (.cancel, .cancel):
      break
    default:
      XCTFail("Unexpected input kind \(kind)", file: file, line: line)
    }
  }

  private enum ExpectedKind {
    case buttonDown(PointerButton)
    case buttonMoved(PointerButton)
    case buttonUp(PointerButton)
    case cancel
  }
}
