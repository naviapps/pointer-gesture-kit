import PointerGestureKit
import XCTest

final class GesturePatternCatalogTests: XCTestCase {
  func testInitializerPreservesHostDefinedPatternOrder() {
    let patterns: [[GestureDirection]] = [
      [.down, .right],
      [.left],
      [],
      [.up, .left],
    ]

    let catalog = GesturePatternCatalog(patterns: patterns)

    XCTAssertEqual(catalog.patterns, patterns)
  }

  func testEmptyCatalogIsValid() {
    let catalog = GesturePatternCatalog(patterns: [])

    XCTAssertTrue(catalog.isValid)
    XCTAssertTrue(catalog.validationIssues.isEmpty)
    XCTAssertTrue(GesturePatternCatalog.validationIssues(for: []).isEmpty)
  }

  func testUniqueNonEmptyPatternsAreValid() {
    let catalog = GesturePatternCatalog(
      patterns: [
        [.down, .right],
        [.up, .left],
        [.right],
      ])

    XCTAssertTrue(catalog.isValid)
    XCTAssertTrue(catalog.validationIssues.isEmpty)
  }

  func testValidationReportsEmptyPatterns() {
    let issues = GesturePatternCatalog.validationIssues(
      for: [
        [.down],
        [],
        [.up],
      ])

    XCTAssertEqual(issues, [.emptyPattern(index: 1)])
  }

  func testValidationReportsEveryEmptyPattern() {
    let issues = GesturePatternCatalog.validationIssues(
      for: [
        [],
        [.right],
        [],
      ])

    XCTAssertEqual(
      issues,
      [
        .emptyPattern(index: 0),
        .emptyPattern(index: 2),
      ])
  }

  func testValidationReportsDuplicatePatterns() {
    let issues = GesturePatternCatalog.validationIssues(
      for: [
        [.down, .right],
        [.up],
        [.down, .right],
      ])

    XCTAssertEqual(
      issues,
      [
        .duplicatePattern(
          pattern: [.down, .right],
          originalIndex: 0,
          duplicateIndex: 2
        )
      ])
  }

  func testValidationReportsEachDuplicateAgainstFirstOccurrence() {
    let issues = GesturePatternCatalog.validationIssues(
      for: [
        [.left],
        [.right],
        [.left],
        [.left],
      ])

    XCTAssertEqual(
      issues,
      [
        .duplicatePattern(pattern: [.left], originalIndex: 0, duplicateIndex: 2),
        .duplicatePattern(pattern: [.left], originalIndex: 0, duplicateIndex: 3),
      ])
  }

  func testValidationReportsMixedIssuesInPatternOrder() {
    let catalog = GesturePatternCatalog(
      patterns: [
        [.right],
        [],
        [.left],
        [.right],
        [],
      ])

    XCTAssertFalse(catalog.isValid)
    XCTAssertEqual(
      catalog.validationIssues,
      [
        .emptyPattern(index: 1),
        .duplicatePattern(pattern: [.right], originalIndex: 0, duplicateIndex: 3),
        .emptyPattern(index: 4),
      ])
  }

  func testShortAndLongPatternsWithSharedPrefixAreValidForExactMatching() {
    let catalog = GesturePatternCatalog(
      patterns: [
        [.up],
        [.up, .right],
      ])

    XCTAssertTrue(catalog.validationIssues.isEmpty)
  }

  func testIsValidReflectsEmptyPatterns() {
    let catalog = GesturePatternCatalog(patterns: [[]])

    XCTAssertFalse(catalog.isValid)
  }

  func testIsValidReflectsDuplicatePatterns() {
    let catalog = GesturePatternCatalog(patterns: [[.down], [.down]])

    XCTAssertFalse(catalog.isValid)
  }

  func testValidationIssueHashableContractSupportsCollections() {
    let issues: Set<GesturePatternCatalog.ValidationIssue> = [
      .emptyPattern(index: 0),
      .emptyPattern(index: 0),
      .duplicatePattern(pattern: [.right], originalIndex: 1, duplicateIndex: 2),
    ]

    XCTAssertEqual(issues.count, 2)
  }

  func testValidationIssueExposesInvalidAndRelatedPatternIndices() {
    let empty = GesturePatternCatalog.ValidationIssue.emptyPattern(index: 1)
    let duplicate = GesturePatternCatalog.ValidationIssue.duplicatePattern(
      pattern: [.right],
      originalIndex: 0,
      duplicateIndex: 3
    )

    XCTAssertEqual(empty.patternIndex, 1)
    XCTAssertNil(empty.relatedPatternIndex)
    XCTAssertEqual(duplicate.patternIndex, 3)
    XCTAssertEqual(duplicate.relatedPatternIndex, 0)
  }

  func testHashableContractSupportsCollections() {
    let catalog = GesturePatternCatalog(patterns: [[.right]])
    let same = GesturePatternCatalog(patterns: [[.right]])
    let different = GesturePatternCatalog(patterns: [[.left]])

    XCTAssertEqual(Set([catalog, same, different]), [catalog, different])
  }

  func testSendableContractAcceptsCatalogAndIssues() {
    assertSendable(GesturePatternCatalog(patterns: [[.right]]))
    assertSendable(GesturePatternCatalog.ValidationIssue.emptyPattern(index: 0))
  }

  func testDoesNotExposeSerializationOrEnumerationContracts() {
    XCTAssertFalse(GesturePatternCatalog.self is any Codable.Type)
    XCTAssertFalse(GesturePatternCatalog.self is any RawRepresentable.Type)
    XCTAssertFalse(GesturePatternCatalog.self is any CaseIterable.Type)
    XCTAssertFalse(GesturePatternCatalog.self is any Error.Type)

    XCTAssertFalse(GesturePatternCatalog.ValidationIssue.self is any Codable.Type)
    XCTAssertFalse(GesturePatternCatalog.ValidationIssue.self is any RawRepresentable.Type)
    XCTAssertFalse(GesturePatternCatalog.ValidationIssue.self is any CaseIterable.Type)
    XCTAssertFalse(GesturePatternCatalog.ValidationIssue.self is any Error.Type)
  }
}
