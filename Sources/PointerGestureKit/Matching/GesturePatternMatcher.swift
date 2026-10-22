/// Stores app-owned matches keyed by pointer gesture direction patterns.
///
/// Build a matcher up front with ``register(pattern:match:)`` and pass the finished value to a
/// ``GestureRecognizer``. Use ``match(pattern:)`` to verify configured patterns in host-app tests.
public struct GesturePatternMatcher<Match: Sendable>: Sendable {
  private struct Node: Sendable {
    var children: [GestureDirection: Int] = [:]
    var terminalMatch: Match?
  }

  private var nodes: [Node] = [Node()]
  private var root = 0

  /// Creates an empty matcher.
  public init() {}

  var isEmpty: Bool {
    nodes[root].children.isEmpty && nodes[root].terminalMatch == nil
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
    var cursor = root
    for direction in pattern {
      if let child = nodes[cursor].children[direction] {
        cursor = child
      } else {
        let child = nodes.count
        nodes.append(Node())
        nodes[cursor].children[direction] = child
        cursor = child
      }
    }
    nodes[cursor].terminalMatch = match
    return true
  }

  /// Returns the app-owned match for an exact direction pattern.
  ///
  /// Returns `nil` when the pattern is empty, incomplete, or unregistered.
  public func match(pattern: [GestureDirection]) -> Match? {
    guard !pattern.isEmpty else { return nil }
    var cursor = root
    for direction in pattern {
      guard let child = nodes[cursor].children[direction] else { return nil }
      cursor = child
    }
    return nodes[cursor].terminalMatch
  }

  func advanced(to direction: GestureDirection) -> GesturePatternMatcher<Match>? {
    guard let child = nodes[root].children[direction] else { return nil }
    var cursor = self
    cursor.root = child
    return cursor
  }

  func completedMatch() -> Match? {
    nodes[root].terminalMatch
  }
}
