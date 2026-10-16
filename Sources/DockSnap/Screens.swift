import AppKit

/// Conversions between Cocoa screen coordinates (bottom-left origin) and the
/// Accessibility/Quartz global space (top-left origin of the primary display).
enum Screens {
    static var primaryHeight: CGFloat {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first)?.frame.height ?? 0
    }

    static func accessibilityRect(_ rect: NSRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { accessibilityRect($0.frame).contains(point) } ?? NSScreen.screens.first
    }

    /// Visible frame (menu bar and Dock excluded) of the screen holding `point`,
    /// in Accessibility coordinates.
    static func visibleFrame(containing point: CGPoint) -> CGRect? {
        screen(containing: point).map { accessibilityRect($0.visibleFrame) }
    }

    static func clamp(_ rect: CGRect, into bounds: CGRect) -> CGRect {
        var result = rect
        let maximumX = max(bounds.minX, bounds.maxX - result.width)
        let maximumY = max(bounds.minY, bounds.maxY - result.height)
        result.origin.x = min(max(result.origin.x, bounds.minX), maximumX)
        result.origin.y = min(max(result.origin.y, bounds.minY), maximumY)
        return result
    }
}
