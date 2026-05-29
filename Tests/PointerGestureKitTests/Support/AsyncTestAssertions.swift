import Foundation
import XCTest

private let asyncAssertionPollingIntervalNanoseconds: UInt64 = 20_000_000

@MainActor
func XCTAssertEventually(
  timeout: TimeInterval = 1,
  file: StaticString = #filePath,
  line: UInt = #line,
  _ predicate: @escaping @MainActor () -> Bool
) async {
  let deadline = ProcessInfo.processInfo.systemUptime + timeout
  if predicate() {
    return
  }
  while ProcessInfo.processInfo.systemUptime < deadline {
    try? await Task.sleep(nanoseconds: asyncAssertionPollingIntervalNanoseconds)
    guard ProcessInfo.processInfo.systemUptime < deadline else { break }
    if predicate() {
      return
    }
  }
  XCTFail("Condition not met within \(timeout)s", file: file, line: line)
}

@MainActor
func XCTAssertNotEventually(
  timeout: TimeInterval,
  file: StaticString = #filePath,
  line: UInt = #line,
  _ predicate: @escaping @MainActor () -> Bool
) async {
  let deadline = ProcessInfo.processInfo.systemUptime + timeout
  if predicate() {
    XCTFail("Condition unexpectedly became true within \(timeout)s", file: file, line: line)
    return
  }
  while ProcessInfo.processInfo.systemUptime < deadline {
    try? await Task.sleep(nanoseconds: asyncAssertionPollingIntervalNanoseconds)
    guard ProcessInfo.processInfo.systemUptime < deadline else { break }
    if predicate() {
      XCTFail("Condition unexpectedly became true within \(timeout)s", file: file, line: line)
      return
    }
  }
}
