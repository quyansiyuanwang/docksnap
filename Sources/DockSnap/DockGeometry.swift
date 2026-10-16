import AppKit
import ApplicationServices

/// Reads the Dock's icon strip geometry through the Accessibility API so the
/// left edge stays correct when the number of Dock items changes.
///
/// The Dock exposes a single `AXList` whose frame is the icon strip. Coordinates
/// are in the global top-left origin space used by the Accessibility API.
enum DockGeometry {
    private static let dockBundleIdentifier = "com.apple.dock"

    static func listFrame() -> CGRect? {
        guard
            let dock = NSRunningApplication
                .runningApplications(withBundleIdentifier: dockBundleIdentifier)
                .first
        else { return nil }

        let application = AXUIElementCreateApplication(dock.processIdentifier)
        guard let children = AX.value(application, kAXChildrenAttribute as String) as? [AXUIElement] else {
            return nil
        }

        // There can be more than one list (for example the minimized windows
        // list); the Dock strip is by far the widest one.
        return children
            .filter { AX.string($0, kAXRoleAttribute as String) == "AXList" }
            .compactMap { AX.frame(of: $0) }
            .max { $0.width * $0.height < $1.width * $1.height }
    }
}
