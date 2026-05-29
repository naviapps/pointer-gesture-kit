import PointerGestureKit
import XCTest

final class GesturePatternMatcherTests: XCTestCase {
  func testMatchReturnsRegisteredExactPatternValue() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up, .right], match: "A")

    XCTAssertEqual(matcher.match(pattern: [.up, .right]), "A")
  }

  func testRegisterOverwritesExistingMatch() {
    var matcher = GesturePatternMatcher<String>()
    XCTAssertTrue(matcher.register(pattern: [.left], match: "first"))
    XCTAssertTrue(matcher.register(pattern: [.left], match: "second"))

    XCTAssertEqual(matcher.match(pattern: [.left]), "second")
  }

  func testMatchSupportsNonEquatableSendableValues() {
    var matcher = GesturePatternMatcher<NonEquatableMatch>()
    matcher.register(pattern: [.down], match: NonEquatableMatch(id: 1))

    XCTAssertEqual(matcher.match(pattern: [.down])?.id, 1)
  }

  func testEmptyPatternNeverMatches() {
    let matcher = GesturePatternMatcher<String>()
    XCTAssertNil(matcher.match(pattern: []))
    XCTAssertNil(matcher.match(pattern: [.up]))
  }

  func testRegisterRejectsEmptyPattern() {
    var matcher = GesturePatternMatcher<String>()
    let didRegister = matcher.register(pattern: [], match: "A")

    XCTAssertFalse(didRegister)
    XCTAssertNil(matcher.match(pattern: []))
    XCTAssertNil(matcher.match(pattern: [.up]))
  }

  func testMatchReturnsNilWhenPatternIsMissing() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "A")
    XCTAssertNil(matcher.match(pattern: [.right]))
  }

  func testMatchReturnsRegisteredBranchValuesWithSharedPrefix() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up, .right], match: "A")
    matcher.register(pattern: [.up, .left], match: "B")

    XCTAssertEqual(matcher.match(pattern: [.up, .right]), "A")
    XCTAssertEqual(matcher.match(pattern: [.up, .left]), "B")
  }

  func testMatchReturnsShortAndLongRegisteredPatternsWithSharedPrefix() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "short")
    matcher.register(pattern: [.up, .right], match: "long")

    XCTAssertEqual(matcher.match(pattern: [.up]), "short")
    XCTAssertEqual(matcher.match(pattern: [.up, .right]), "long")
  }

  func testMatchReturnsNilForIncompletePrefix() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up, .right], match: "A")

    XCTAssertNil(matcher.match(pattern: [.up]))
  }

  func testMatchReturnsNilWhenPatternContinuesPastRegisteredMatch() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "A")

    XCTAssertNil(matcher.match(pattern: [.up, .right]))
  }

  func testSendableContractAcceptsMatcherValues() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "A")

    assertSendable(matcher)
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GesturePatternMatcher<String>.self is any Codable.Type)
    XCTAssertFalse(GesturePatternMatcher<String>.self is any RawRepresentable.Type)
    XCTAssertFalse(GesturePatternMatcher<String>.self is any CaseIterable.Type)
    XCTAssertFalse(GesturePatternMatcher<String>.self is any Error.Type)
  }

  func testDoesNotExposeEqualityOrHashingAsPublicContract() {
    XCTAssertFalse(GesturePatternMatcher<String>.self is any Equatable.Type)
    XCTAssertFalse(GesturePatternMatcher<String>.self is any Hashable.Type)
  }

  private struct NonEquatableMatch: Sendable {
    let id: Int
  }
}
