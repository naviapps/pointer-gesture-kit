import CoreFoundation
import CoreGraphics
import Foundation
import PointerGestureKit

/// Captures macOS Core Graphics events for pointer gesture recognition.
///
/// The tap translates configured pointer-button mouse events and Escape key-down events into
/// platform-neutral `GestureInputEvent` values.
@MainActor
public final class GestureEventTap: GestureEventSource {
  let capturedButtons: Set<PointerButton>
  private var tapPort: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var eventHandler: (@MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition)?
  var syntheticEventSuppression = SyntheticEventSuppression()

  /// Creates an event tap for the provided pointer buttons.
  ///
  /// Passing an empty set creates a tap configuration that captures no input.
  public init(capturedButtons: Set<PointerButton> = [.secondary]) {
    self.capturedButtons = capturedButtons
  }

  @MainActor
  deinit {
    stop()
  }

  /// Starts the macOS event tap.
  ///
  /// A successful start replaces any previously active event tap and handler.
  /// Returns `false` when no pointer buttons are configured, or when CoreGraphics cannot create or
  /// install the event tap, for example when the process is missing the required Accessibility
  /// permission.
  public func start(
    handler: @escaping @MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition
  ) -> Bool {
    stop()
    guard !capturedButtons.isEmpty else { return false }
    guard let port = makeTapPort() else { return false }

    guard let source = makeRunLoopSource(for: port) else {
      CFMachPortInvalidate(port)
      return false
    }
    activateTapPort(port, source: source, handler: handler)
    return true
  }

  /// Stops the macOS event tap and clears pending synthetic-event suppression.
  ///
  /// Calling this while the tap is already stopped is safe.
  public func stop() {
    if let source = runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
      runLoopSource = nil
    }
    if let port = tapPort {
      CGEvent.tapEnable(tap: port, enable: false)
      CFMachPortInvalidate(port)
      tapPort = nil
    }
    eventHandler = nil
    syntheticEventSuppression.removeAll()
  }

  private func reenableTapPort() {
    guard let port = tapPort else { return }
    CGEvent.tapEnable(tap: port, enable: true)
  }

  private func makeTapPort() -> CFMachPort? {
    CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: makeTapCallback(),
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    )
  }

  private func makeRunLoopSource(for port: CFMachPort) -> CFRunLoopSource? {
    CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
  }

  private func activateTapPort(
    _ port: CFMachPort,
    source: CFRunLoopSource,
    handler: @escaping @MainActor @Sendable (GestureInputEvent) -> GestureEventDisposition
  ) {
    eventHandler = handler
    CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
    tapPort = port
    runLoopSource = source
    CGEvent.tapEnable(tap: port, enable: true)
  }

  private func makeTapCallback() -> CGEventTapCallBack {
    { _, type, event, refcon -> Unmanaged<CGEvent>? in
      guard let refcon else { return Unmanaged.passUnretained(event) }
      let gestureEventTap = Unmanaged<GestureEventTap>
        .fromOpaque(refcon)
        .takeUnretainedValue()
      return gestureEventTap.handleTapEvent(type: type, event: event)
    }
  }

  private nonisolated func handleTapEvent(
    type: CGEventType,
    event: CGEvent
  ) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
      Task { @MainActor [weak self] in
        self?.reenableTapPort()
      }
      return Unmanaged.passUnretained(event)
    }

    guard Thread.isMainThread else { return Unmanaged.passUnretained(event) }

    guard let mappedInputEvent = mappedInputEvent(for: type, event: event) else {
      return Unmanaged.passUnretained(event)
    }

    let disposition = MainActor.assumeIsolated {
      dispatchInputEvent(mappedInputEvent.input, sourceSignature: mappedInputEvent.sourceSignature)
    }
    return disposition == .consume ? nil : Unmanaged.passUnretained(event)
  }

  private func dispatchInputEvent(
    _ input: GestureInputEvent,
    sourceSignature: SyntheticEventSignature
  ) -> GestureEventDisposition {
    if consumePendingSyntheticEventSignature(sourceSignature) {
      return .passThrough
    }

    guard let gestureHandler = eventHandler else { return .passThrough }

    return gestureHandler(input)
  }
}
