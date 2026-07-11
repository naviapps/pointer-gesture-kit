import class CoreGraphics.CGEvent
import enum CoreGraphics.CGEventField
import enum CoreGraphics.CGEventType
import PointerGestureKit

extension GestureEventTap {
  func suppressNextSyntheticEventSignatures(_ signatures: [SyntheticEventSignature]) {
    syntheticEventSuppression.suppress(signatures)
  }

  func consumePendingSyntheticEventSignature(_ signature: SyntheticEventSignature) -> Bool {
    syntheticEventSuppression.consumeThrough(signature)
  }
}

struct SyntheticEventSignature: Equatable, Sendable {
  private let type: CGEventType
  private let button: PointerButton?
  private let eventSourceUserData: Int64

  private init(type: CGEventType, button: PointerButton?, eventSourceUserData: Int64) {
    self.type = type
    self.button = button
    self.eventSourceUserData = eventSourceUserData
  }

  static func markReplayed(_ event: CGEvent) {
    event.setIntegerValueField(
      .eventSourceUserData,
      value: replayEventSourceUserData
    )
  }

  static func replayed(type: CGEventType, button: PointerButton?) -> Self {
    Self(
      type: type,
      button: button,
      eventSourceUserData: replayEventSourceUserData
    )
  }

  static func observed(
    type: CGEventType,
    button: PointerButton?,
    eventSourceUserData: Int64
  ) -> Self {
    Self(
      type: type,
      button: button,
      eventSourceUserData: eventSourceUserData
    )
  }

  static var tapDisabledTimeout: Self {
    Self(type: .tapDisabledByTimeout, button: nil, eventSourceUserData: 0)
  }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.type == rhs.type
      && lhs.button == rhs.button
      && lhs.eventSourceUserData == rhs.eventSourceUserData
  }

  var isReplayedEvent: Bool {
    eventSourceUserData == replayEventSourceUserData
  }
}

private let replayEventSourceUserData: Int64 = 0x5047_4B54

struct SyntheticEventSuppression {
  private let maximumPendingSignatureCount: Int
  private var pendingSignatures: [SyntheticEventSignature] = []

  init(maximumPendingSignatureCount: Int = 512) {
    self.maximumPendingSignatureCount = max(1, maximumPendingSignatureCount)
  }

  /// Queues replayed event signatures that should be ignored when observed through the tap.
  mutating func suppress(_ signatures: [SyntheticEventSignature]) {
    pendingSignatures.append(contentsOf: signatures)
    trimPendingSignatures()
  }

  /// Removes the matching replayed event signature and any earlier pending signatures.
  ///
  /// The tap may not observe every replayed event. When a later replayed signature arrives, earlier
  /// pending signatures can no longer be consumed and are discarded.
  mutating func consumeThrough(_ signature: SyntheticEventSignature) -> Bool {
    guard signature.isReplayedEvent else {
      return false
    }
    guard let signatureIndex = pendingSignatures.firstIndex(of: signature) else {
      return true
    }
    pendingSignatures.removeFirst(signatureIndex + 1)
    return true
  }

  mutating func removeAll() {
    pendingSignatures.removeAll()
  }

  private mutating func trimPendingSignatures() {
    let overflow = pendingSignatures.count - maximumPendingSignatureCount
    guard overflow > 0 else { return }
    pendingSignatures.removeFirst(overflow)
  }
}
