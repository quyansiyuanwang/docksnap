import Carbon.HIToolbox
import Foundation

/// Registers process-wide hot keys through Carbon's `RegisterEventHotKey`. This
/// is the one global-shortcut API that does not itself require Accessibility
/// permission, and unlike `NSEvent` global monitors it consumes the event.
@MainActor
final class HotKeys {
    static let shared = HotKeys()

    private var handlers: [UInt32: @MainActor () -> Void] = [:]
    private var references: [EventHotKeyRef] = []
    private var nextIdentifier: UInt32 = 1
    private var installed = false

    private init() {}

    func register(keyCode: UInt32, modifiers: UInt32, handler: @escaping @MainActor () -> Void) {
        installIfNeeded()

        let identifier = nextIdentifier
        nextIdentifier += 1
        handlers[identifier] = handler

        var reference: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x44_53_4E_50), id: identifier) // 'DSNP'
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        if status == noErr, let reference {
            references.append(reference)
        }
    }

    fileprivate func fire(_ identifier: UInt32) {
        handlers[identifier]?()
    }

    private func installIfNeeded() {
        guard !installed else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        _ = InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyEventHandler,
            1,
            &eventType,
            nil,
            nil
        )
        installed = true
    }
}

private func hotKeyEventHandler(
    _ callRef: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else { return status }

    let identifier = hotKeyID.id
    DispatchQueue.main.async {
        MainActor.assumeIsolated {
            HotKeys.shared.fire(identifier)
        }
    }
    return noErr
}
