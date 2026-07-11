import PointerGestureKit
import XCTest

final class GesturePatternMatcherTests: XCTestCase {
  func testRegisterRejectsEmptyPattern() {
    var matcher = GesturePatternMatcher<String>()
    let result = matcher.register(pattern: [], match: "A")

    XCTAssertFalse(result)
    XCTAssertNil(matcher.match(pattern: []))
  }

  func testMatchReturnsRegisteredExactPattern() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up, .right], match: "A")

    XCTAssertEqual(matcher.match(pattern: [.up, .right]), "A")
  }

  func testMatchReturnsNilForEmptyIncompleteAndUnregisteredPatterns() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up, .right], match: "A")

    XCTAssertNil(matcher.match(pattern: []))
    XCTAssertNil(matcher.match(pattern: [.up]))
    XCTAssertNil(matcher.match(pattern: [.right]))
  }

  func testRegisterReplacesExistingExactPatternMatch() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "A")
    matcher.register(pattern: [.up], match: "B")

    XCTAssertEqual(matcher.match(pattern: [.up]), "B")
  }

  func testSharedPrefixPatternsMatchDistinctTerminalValues() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "short")
    matcher.register(pattern: [.up, .right], match: "long")

    XCTAssertEqual(matcher.match(pattern: [.up]), "short")
    XCTAssertEqual(matcher.match(pattern: [.up, .right]), "long")
  }

  func testSendableContractAcceptsMatcherValues() {
    var matcher = GesturePatternMatcher<String>()
    matcher.register(pattern: [.up], match: "A")

    assertSendable(matcher)
  }

  func testRegisterAcceptsNonEquatableSendableMatchValues() {
    var matcher = GesturePatternMatcher<NonEquatableMatch>()

    let result = matcher.register(pattern: [.down], match: NonEquatableMatch(id: 1))

    XCTAssertTrue(result)
  }

  private struct NonEquatableMatch: Sendable {
    let id: Int
  }
}
