import AppKit
import ApplicationServices
import Foundation

/// Thin wrappers over the Accessibility API. Everything here must be called on
/// the main thread because `AXUIElement` values are only valid in the process
/// that owns them and are not `Sendable`.
enum AX {
    private static let positionAttribute = kAXPositionAttribute as String
    private static let sizeAttribute = kAXSizeAttribute as String
    private static let fullScreenAttribute = "AXFullScreen"
    private static let zoomButtonAttribute = "AXZoomButton"

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

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        guard
            let value = value(element, attribute),
            CFGetTypeID(value) == CFBooleanGetTypeID()
        else { return nil }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    static func frame(of element: AXUIElement) -> CGRect? {
        guard
            let positionValue = value(element, positionAttribute),
            let sizeValue = value(element, sizeAttribute),
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
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

    /// Applies `rect` and verifies the result. macOS can silently ignore or roll
    /// back individual writes, so this retries only the attributes that still
    /// differ. When both change, the position is written before the size; a
    /// trailing position write is deliberately avoided because some applications
    /// undo the resize when they receive it.
    @discardableResult
    static func setFrame(_ rect: CGRect, of element: AXUIElement) -> Bool {
        guard rect.isUsableWindowFrame else { return false }

        AXUIElementSetMessagingTimeout(element, 2.0)

        if bool(element, fullScreenAttribute) == true {
            // A full-screen window rejects position changes and ignores size
            // changes. Leave the full-screen space first so the window can be
            // moved and resized normally again.
            if let current = frame(of: element), FramePlan.matches(rect, current) {
                return true
            }
            guard exitFullScreen(element) else { return false }
        }

        guard let initial = frame(of: element) else { return false }

        for _ in 0..<8 {
            guard let current = frame(of: element) else { return false }
            let mutations = FramePlan.mutations(to: rect, from: current)
            if mutations.isEmpty { return true }

            for mutation in mutations {
                guard set(mutation, of: element) else { return false }
            }

            // Window-server and application-side constraints settle
            // asynchronously. Give them a chance before reading the frame back.
            Thread.sleep(forTimeInterval: 0.03)
        }

        guard let observed = frame(of: element) else { return false }
        if FramePlan.matches(rect, observed) { return true }

        // Some applications deliberately constrain a window to a grid or a
        // minimum size. Treat that as success when the position is right and
        // the window did resize from where it started; report failure when the
        // size write was ignored completely.
        return FramePlan.positionsMatch(rect, observed)
            && !FramePlan.sizesMatch(initial, observed)
    }

    private static func set(_ mutation: FramePlan.Mutation, of element: AXUIElement) -> Bool {
        switch mutation {
        case .position(let point):
            let attribute = positionAttribute
            guard isSettable(element, attribute) else { return false }
            var point = point
            guard let value = AXValueCreate(.cgPoint, &point) else { return false }
            return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success

        case .size(let size):
            let attribute = sizeAttribute
            guard isSettable(element, attribute) else { return false }
            var size = size
            guard let value = AXValueCreate(.cgSize, &size) else { return false }
            return AXUIElementSetAttributeValue(element, attribute as CFString, value) == .success
        }
    }

    /// Leaves the full-screen space and waits until the window is back on the
    /// desktop and its geometry is writable again.
    private static func exitFullScreen(_ element: AXUIElement) -> Bool {
        var accepted = false
        if isSettable(element, fullScreenAttribute) {
            accepted = AXUIElementSetAttributeValue(
                element,
                fullScreenAttribute as CFString,
                kCFBooleanFalse
            ) == .success
        }

        if accepted, waitForDesktop(element) { return true }

        // If the flag already cleared but geometry is still locked, pressing the
        // green button would enter full screen again instead of helping.
        if bool(element, fullScreenAttribute) != true { return false }

        // Fallback for applications that expose the full-screen flag but do not
        // implement the setter: the green button toggles the same state.
        guard
            let buttonValue = value(element, zoomButtonAttribute),
            CFGetTypeID(buttonValue) == AXUIElementGetTypeID()
        else { return false }

        guard AXUIElementPerformAction(buttonValue as! AXUIElement, kAXPressAction as CFString) == .success
        else { return false }
        return waitForDesktop(element)
    }

    private static func waitForDesktop(_ element: AXUIElement) -> Bool {
        for _ in 0..<40 {
            Thread.sleep(forTimeInterval: 0.05)
            if bool(element, fullScreenAttribute) != true,
               isSettable(element, positionAttribute) {
                return true
            }
        }
        return false
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

private extension CGRect {
    var isUsableWindowFrame: Bool {
        width.isFinite && height.isFinite
            && origin.x.isFinite && origin.y.isFinite
            && width > 0 && height > 0
    }
}
