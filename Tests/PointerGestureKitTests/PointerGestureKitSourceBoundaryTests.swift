import XCTest

final class PointerGestureKitSourceBoundaryTests: XCTestCase {
  func testCoreTargetStaysPlatformNeutral() throws {
    let source = try productionSource(for: "PointerGestureKit")
    for forbiddenFragment in [
      "import AppKit",
      "import Combine",
      "import CoreGraphics",
      "import SwiftUI",
      "CGEvent",
      "CGPoint",
      "NSEvent",
      "NSView",
      "NSWindow",
    ] {
      XCTAssertFalse(source.contains(forbiddenFragment), "Unexpected \(forbiddenFragment) in core")
    }
  }

}

private func productionSource(for target: String) throws -> String {
  let root = try packageRoot().appendingPathComponent("Sources/\(target)")
  return try FileManager.default
    .subpathsOfDirectory(atPath: root.path)
    .filter { $0.hasSuffix(".swift") }
    .sorted()
    .map { try String(contentsOf: root.appendingPathComponent($0), encoding: .utf8) }
    .joined(separator: "\n")
}

private func packageRoot() throws -> URL {
  var url = URL(fileURLWithPath: #filePath)
  while url.path != "/" {
    if FileManager.default.fileExists(atPath: url.appendingPathComponent("Package.swift").path) {
      return url
    }
    url.deleteLastPathComponent()
  }
  throw XCTSkip("Package.swift not found")
}
