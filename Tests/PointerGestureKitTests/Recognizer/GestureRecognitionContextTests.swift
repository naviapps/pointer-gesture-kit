import PointerGestureKit
import XCTest

final class GestureRecognitionContextTests: XCTestCase {
  func testInitializerStoresIdentifier() throws {
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: "host.context"))

    XCTAssertEqual(context.identifier, "host.context")
  }

  func testInitializerReturnsNilForEmptyIdentifier() {
    XCTAssertNil(GestureRecognitionContext(identifier: ""))
    XCTAssertNil(GestureRecognitionContext(identifier: " \n\t "))
  }

  func testInitializerTrimsSurroundingWhitespace() throws {
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: "  host.context\n"))

    XCTAssertEqual(context.identifier, "host.context")
  }

  func testInitializerKeepsInternalWhitespace() throws {
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: "host context"))

    XCTAssertEqual(context.identifier, "host context")
  }

  func testEqualityUsesIdentifier() throws {
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: "host.context"))
    let same = try XCTUnwrap(GestureRecognitionContext(identifier: "host.context"))
    let different = try XCTUnwrap(GestureRecognitionContext(identifier: "other.context"))

    XCTAssertEqual(context, same)
    XCTAssertNotEqual(context, different)
  }

  func testEqualityUsesNormalizedIdentifier() throws {
    XCTAssertEqual(
      try XCTUnwrap(GestureRecognitionContext(identifier: " host.context ")),
      try XCTUnwrap(GestureRecognitionContext(identifier: "host.context"))
    )
  }

  func testHashableContractSupportsCollections() throws {
    let context = try XCTUnwrap(GestureRecognitionContext(identifier: " host.context "))
    let same = try XCTUnwrap(GestureRecognitionContext(identifier: "host.context"))
    let different = try XCTUnwrap(GestureRecognitionContext(identifier: "other.context"))

    XCTAssertEqual(Set([context, same, different]), [same, different])
  }

  func testSendableContractAcceptsContext() throws {
    assertSendable(try XCTUnwrap(GestureRecognitionContext(identifier: "host.context")))
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GestureRecognitionContext.self is any Codable.Type)
    XCTAssertFalse(GestureRecognitionContext.self is any RawRepresentable.Type)
    XCTAssertFalse(GestureRecognitionContext.self is any CaseIterable.Type)
    XCTAssertFalse(GestureRecognitionContext.self is any Error.Type)
  }
}
