import ApplicationServices
import Foundation

/// Headless commands so the behaviour can be tested and scripted without the
/// menu bar app. Run the binary with one of these as the first argument.
enum CLI {
    static func isHeadlessCommand(_ command: String) -> Bool {
        ["save", "restore", "restore-exact", "show", "status"].contains(command)
    }

    static func run(_ command: String) -> Int32 {
        switch command {
        case "save":
            let outcome = WindowLayout.saveCurrent()
            print(outcome.message)
            return outcome == .saved ? 0 : 1

        case "restore":
            let outcome = WindowLayout.restore(dockAligned: true)
            print(outcome.message)
            return outcome == .applied ? 0 : 1

        case "restore-exact":
            let outcome = WindowLayout.restore(dockAligned: false)
            print(outcome.message)
            return outcome == .applied ? 0 : 1

        case "show":
            if let frame = FrameStore.load() {
                print("x=\(frame.origin.x) y=\(frame.origin.y) w=\(frame.width) h=\(frame.height)")
            } else {
                print("无已保存的窗口")
            }
            return 0

        case "status":
            print("accessibility trusted: \(AXIsProcessTrusted())")
            if let dock = DockGeometry.listFrame() {
                print("dock: x=\(dock.minX) y=\(dock.minY) w=\(dock.width) h=\(dock.height)")
            } else {
                print("dock: 读取失败")
            }
            if let frame = FrameStore.load() {
                print("saved: x=\(frame.origin.x) y=\(frame.origin.y) w=\(frame.width) h=\(frame.height)")
            } else {
                print("saved: 无")
            }
            return 0

        default:
            print("unknown command: \(command)")
            return 2
        }
    }
}
