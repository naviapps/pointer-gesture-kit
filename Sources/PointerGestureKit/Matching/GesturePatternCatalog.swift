/// A host-defined collection of gesture direction patterns that can be checked before matching.
public struct GesturePatternCatalog: Hashable, Sendable {
  /// A validation issue in a host-defined gesture pattern catalog.
  public enum ValidationIssue: Hashable, Sendable {
    /// A pattern is empty and cannot be matched.
    case emptyPattern(index: Int)
    /// A pattern duplicates an earlier pattern and would map the same gesture to multiple host intents.
    case duplicatePattern(
      pattern: [GestureDirection],
      originalIndex: Int,
      duplicateIndex: Int
    )

    /// The host-defined pattern index that should be treated as invalid.
    public var patternIndex: Int {
      switch self {
      case let .emptyPattern(index):
        index
      case let .duplicatePattern(_, _, duplicateIndex):
        duplicateIndex
      }
    }

    /// The earlier pattern index related to this issue, when one exists.
    public var relatedPatternIndex: Int? {
      switch self {
      case .emptyPattern:
        nil
      case let .duplicatePattern(_, originalIndex, _):
        originalIndex
      }
    }
  }

  /// Direction patterns in host-defined order.
  public let patterns: [[GestureDirection]]

  /// Creates a catalog from host-defined direction patterns.
  public init(patterns: [[GestureDirection]]) {
    self.patterns = patterns
  }

  /// Returns empty or duplicate patterns in host-defined order.
  public var validationIssues: [ValidationIssue] {
    Self.validationIssues(for: patterns)
  }

  /// Returns `true` when no validation issues are present.
  public var isValid: Bool {
    validationIssues.isEmpty
  }

  /// Returns empty or duplicate patterns in host-defined order.
  public static func validationIssues(
    for patterns: [[GestureDirection]]
  ) -> [ValidationIssue] {
    var issues: [ValidationIssue] = []
    var originalIndexByPattern: [[GestureDirection]: Int] = [:]

    for (index, pattern) in patterns.enumerated() {
      guard !pattern.isEmpty else {
        issues.append(.emptyPattern(index: index))
        continue
      }

      if let originalIndex = originalIndexByPattern[pattern] {
        issues.append(
          .duplicatePattern(
            pattern: pattern,
            originalIndex: originalIndex,
            duplicateIndex: index
          ))
      } else {
        originalIndexByPattern[pattern] = index
      }
    }

    return issues
  }
}
