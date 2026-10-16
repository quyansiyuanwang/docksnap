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
        return FrameStore.shared.save(frame) ? .saved : .noWindow
    }

    /// `dockAligned` ignores the saved size and fills the whole usable height
    /// from the Dock's current left edge to the screen's right edge. Otherwise
    /// the recorded frame is reapplied exactly (clamped to stay on screen).
    static func restore(dockAligned: Bool) -> Outcome {
        guard AXIsProcessTrusted() else { return .needsAccessibility }
        guard let window = AX.frontWindow() else { return .noWindow }

        var target: CGRect
        if dockAligned {
            guard
                let dock = DockGeometry.listFrame(),
                let visible = Screens.visibleFrame(containing: CGPoint(x: dock.midX, y: dock.midY))
            else { return .noWindow }

            target = CGRect(
                x: dock.minX,
                y: visible.minY,
                width: max(0, visible.maxX - dock.minX),
                height: visible.height
            )
        } else {
            guard let saved = FrameStore.shared.load() else { return .noSavedFrame }
            target = saved
        }

        let center = CGPoint(x: target.midX, y: target.midY)
        if let visible = Screens.visibleFrame(containing: center) {
            target = Screens.clamp(target, into: visible)
        }

        return AX.setFrame(target, of: window) ? .applied : .notMovable
    }
}
