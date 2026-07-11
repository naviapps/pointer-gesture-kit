/// Stores app-owned matches keyed by pointer gesture direction patterns.
///
/// Build a matcher up front with ``register(pattern:match:)`` and pass the finished value to a
/// ``GestureRecognizer``. Use ``match(pattern:)`` to verify configured patterns in host-app tests.
public struct GesturePatternMatcher<Match: Sendable>: Sendable {
  private var children: [GestureDirection: GesturePatternMatcher<Match>] = [:]
  private var terminalMatch: Match?

  /// Creates an empty matcher.
  public init() {}

  var isEmpty: Bool {
    children.isEmpty && terminalMatch == nil
  }

  /// Registers a direction pattern with an app-owned match value.
  ///
  /// Registering the same pattern again replaces the previous match. Patterns that share prefixes
  /// with other registered patterns remain distinct.
  ///
  /// Returns `false` without changing the matcher when the pattern is empty. Otherwise returns
  /// `true`; registering the same pattern again intentionally replaces its match.
  @discardableResult
  public mutating func register(pattern: [GestureDirection], match: Match) -> Bool {
    guard !pattern.isEmpty else { return false }
    insert(pattern: ArraySlice(pattern), match: match)
    return true
  }

  /// Returns the app-owned match for an exact direction pattern.
  ///
  /// Returns `nil` when the pattern is empty, incomplete, or unregistered.
  public func match(pattern: [GestureDirection]) -> Match? {
    guard !pattern.isEmpty else { return nil }
    return match(pattern: ArraySlice(pattern))
  }

  private mutating func insert(pattern: ArraySlice<GestureDirection>, match: Match) {
    guard let first = pattern.first else { return }

    var child = children[first] ?? GesturePatternMatcher<Match>()
    let remaining = pattern.dropFirst()
    if remaining.isEmpty {
      child.terminalMatch = match
    } else {
      child.insert(pattern: remaining, match: match)
    }
    children[first] = child
  }

  func advanced(to direction: GestureDirection) -> GesturePatternMatcher<Match>? {
    children[direction]
  }

  func completedMatch() -> Match? {
    terminalMatch
  }

  private func match(pattern: ArraySlice<GestureDirection>) -> Match? {
    guard let first = pattern.first, let child = children[first] else { return nil }

    let remaining = pattern.dropFirst()
    if remaining.isEmpty {
      return child.terminalMatch
    }
    return child.match(pattern: remaining)
  }
}
