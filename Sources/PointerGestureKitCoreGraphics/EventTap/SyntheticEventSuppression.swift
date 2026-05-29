import class CoreGraphics.CGEvent
import enum CoreGraphics.CGEventField
import enum CoreGraphics.CGEventType
import PointerGestureKit

extension GestureEventTap {
  func suppressNextSyntheticEventSignatures(_ signatures: [SyntheticEventSignature]) {
    syntheticEventSuppression.suppress(signatures)
  }

  func consumePendingSyntheticEventSignature(_ signature: SyntheticEventSignature) -> Bool {
    syntheticEventSuppression.consume(signature)
  }
}

struct SyntheticEventSignature: Equatable, Sendable {
  let type: CGEventType
  let button: PointerButton?
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
}

private let replayEventSourceUserData: Int64 = 0x5047_4B54

struct SyntheticEventSuppression {
  private var pendingSignatures: [SyntheticEventSignature] = []

  mutating func suppress(_ signatures: [SyntheticEventSignature]) {
    pendingSignatures.append(contentsOf: signatures)
  }

  mutating func consume(_ signature: SyntheticEventSignature) -> Bool {
    guard let signatureIndex = pendingSignatures.firstIndex(of: signature) else {
      return false
    }
    pendingSignatures.removeFirst(signatureIndex + 1)
    return true
  }

  mutating func removeAll() {
    pendingSignatures.removeAll()
  }
}
