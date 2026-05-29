import Foundation

/// Host-defined context used to select gesture policy and gesture matches.
public struct GestureRecognitionContext: Hashable, Sendable {
  /// Stable host-owned identifier for the context.
  public let identifier: String

  /// Creates a context with a stable host-owned identifier.
  ///
  /// Trims surrounding whitespace and returns `nil` when the trimmed identifier is empty.
  /// Use `nil` recognition contexts when no host context is active.
  public init?(identifier: String) {
    let normalizedIdentifier = Self.normalizedIdentifier(identifier)
    guard !normalizedIdentifier.isEmpty else { return nil }
    self.identifier = normalizedIdentifier
  }

  private static func normalizedIdentifier(_ identifier: String) -> String {
    identifier.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}
