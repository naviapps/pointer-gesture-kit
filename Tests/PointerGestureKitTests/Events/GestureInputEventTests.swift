import PointerGestureKit
import XCTest

final class GestureInputEventTests: XCTestCase {
  func testInitializerStoresKindLocationAndModifiers() {
    let event = GestureInputEvent(
      kind: .buttonDragged(.secondary),
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.command, .shift]
    )

    XCTAssertEqual(event.kind, .buttonDragged(.secondary))
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

  func testEqualityUsesKindLocationAndModifiers() {
    let event = GestureInputEvent(
      kind: .buttonDown(.secondary),
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.command]
    )

    XCTAssertEqual(
      event,
      GestureInputEvent(
        kind: .buttonDown(.secondary),
        location: GesturePoint(x: 10, y: 20),
        modifiers: [.command]
      )
    )
    XCTAssertNotEqual(
      event,
      GestureInputEvent(
        kind: .buttonUp(.secondary),
        location: GesturePoint(x: 10, y: 20),
        modifiers: [.command]
      )
    )
    XCTAssertNotEqual(
      event,
      GestureInputEvent(
        kind: .buttonDown(.primary),
        location: GesturePoint(x: 10, y: 20),
        modifiers: [.command]
      )
    )
    XCTAssertNotEqual(
      event,
      GestureInputEvent(
        kind: .buttonDown(.secondary),
        location: GesturePoint(x: 10, y: 21),
        modifiers: [.command]
      )
    )
    XCTAssertNotEqual(
      event,
      GestureInputEvent(
        kind: .buttonDown(.secondary),
        location: GesturePoint(x: 10, y: 20),
        modifiers: [.shift]
      )
    )
  }

  func testCancelEventKeepsSourceLocationAndModifiers() {
    let event = GestureInputEvent(
      kind: .cancel,
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.option]
    )

    XCTAssertEqual(event.kind, .cancel)
    XCTAssertEqual(event.location, GesturePoint(x: 10, y: 20))
    XCTAssertEqual(event.modifiers, [.option])
  }

  func testKindHashableContractSupportsCollections() {
    XCTAssertEqual(
      Set<GestureInputEvent.Kind>([
        .buttonDown(.secondary),
        .buttonDragged(.secondary),
        .buttonUp(.secondary),
        .cancel,
        .cancel,
      ]),
      [.buttonDown(.secondary), .buttonDragged(.secondary), .buttonUp(.secondary), .cancel]
    )
  }

  func testHashableContractSupportsCollections() {
    let event = GestureInputEvent(
      kind: .buttonDown(.secondary),
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.command]
    )
    let same = GestureInputEvent(
      kind: .buttonDown(.secondary),
      location: GesturePoint(x: 10, y: 20),
      modifiers: [.command]
    )
    let different = GestureInputEvent(
      kind: .buttonDown(.secondary),
      location: GesturePoint(x: 10, y: 21),
      modifiers: [.command]
    )

    XCTAssertEqual(Set([event, same, different]), [event, different])
  }

  func testSendableContractAcceptsEventAndKindValues() {
    assertSendable(
      GestureInputEvent(
        kind: .buttonDown(.secondary),
        location: GesturePoint(x: 10, y: 20),
        modifiers: [.command]
      )
    )
    assertSendable(GestureInputEvent.Kind.buttonDragged(.secondary))
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureInputEvent.self is any Codable.Type)
    XCTAssertFalse(GestureInputEvent.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureInputEvent.self is any CaseIterable.Type)
    XCTAssertFalse(GestureInputEvent.self is any Error.Type)

    XCTAssertFalse(GestureInputEvent.Kind.self is any Codable.Type)
    XCTAssertFalse(GestureInputEvent.Kind.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureInputEvent.Kind.self is any CaseIterable.Type)
    XCTAssertFalse(GestureInputEvent.Kind.self is any Error.Type)
  }
}
