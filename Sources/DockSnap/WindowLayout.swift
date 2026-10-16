import AppKit

/// The actual save/restore behaviour, shared by the menu bar app and the CLI.
enum WindowLayout {
    enum Outcome {
        case saved
        case applied
        case noWindow
        case noSavedFrame
        case needsAccessibility
        case notMovable

        var message: String {
            switch self {
            case .saved: return "已保存当前窗口"
            case .applied: return "已还原"
            case .noWindow: return "找不到当前窗口"
            case .noSavedFrame: return "还没有保存过，先按保存"
            case .needsAccessibility: return "需要辅助功能权限"
            case .notMovable: return "这个窗口无法移动"
            }
        }
    }

    static func saveCurrent() -> Outcome {
        guard AXIsProcessTrusted() else { return .needsAccessibility }
        guard let window = AX.frontWindow(), let frame = AX.frame(of: window) else { return .noWindow }
        return FrameStore.save(frame) ? .saved : .noWindow
    }

    /// `dockAligned` replaces the saved left edge with the Dock's current left
    /// edge; the rest of the recorded frame is kept, clamped to stay on screen.
    static func restore(dockAligned: Bool) -> Outcome {
        guard AXIsProcessTrusted() else { return .needsAccessibility }
        guard let window = AX.frontWindow() else { return .noWindow }
        guard let saved = FrameStore.load() else { return .noSavedFrame }

        var target = saved
        if dockAligned, let dock = DockGeometry.listFrame() {
            target.origin.x = dock.minX
        }

        let center = CGPoint(x: target.midX, y: target.midY)
        if let visible = Screens.visibleFrame(containing: center) {
            target = Screens.clamp(target, into: visible)
        }

        return AX.setFrame(target, of: window) ? .applied : .notMovable
    }
}
