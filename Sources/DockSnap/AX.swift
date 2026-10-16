import AppKit
import ApplicationServices

/// Thin wrappers over the Accessibility API. Everything here must be called on
/// the main thread because `AXUIElement` values are only valid in the process
/// that owns them and are not `Sendable`.
enum AX {
    static func value(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else {
            return nil
        }
        return result
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        value(element, attribute) as? String
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = value(element, kAXPositionAttribute as String),
            let sizeValue = value(element, kAXSizeAttribute as String)
        else { return nil }

        var point = CGPoint.zero
        var size = CGSize.zero
        guard
            AXValueGetValue(positionValue as! AXValue, .cgPoint, &point),
            AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else { return nil }

        return CGRect(origin: point, size: size)
    }

    /// Whether the target window can actually be moved and resized.
    static func isSettable(_ element: AXUIElement, _ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        let error = AXUIElementIsAttributeSettable(element, attribute as CFString, &settable)
        return error == .success && settable.boolValue
    }

    @discardableResult
    static func setFrame(_ rect: CGRect, of element: AXUIElement) -> Bool {
        var point = rect.origin
        var size = rect.size

        guard
            let positionValue = AXValueCreate(.cgPoint, &point),
            let sizeValue = AXValueCreate(.cgSize, &size)
        else { return false }

        // Order matters for some apps: move, resize, then move again so that
        // apps which re-anchor themselves while resizing end up in the right spot.
        let positionError = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)
        let sizeError = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        _ = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, positionValue)

        return positionError == .success && sizeError == .success
    }

    /// The focused window of the frontmost application, if there is one.
    static func frontWindow() -> AXUIElement? {
        guard let application = NSWorkspace.shared.frontmostApplication else { return nil }
        if application.bundleIdentifier == Bundle.main.bundleIdentifier { return nil }

        let applicationElement = AXUIElementCreateApplication(application.processIdentifier)
        if let focused = value(applicationElement, kAXFocusedWindowAttribute as String) {
            return (focused as! AXUIElement)
        }
        if let windows = value(applicationElement, kAXWindowsAttribute as String) as? [AXUIElement] {
            return windows.first
        }
        return nil
    }
}
