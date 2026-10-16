import AppKit
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let symbolName = "rectangle.split.2x1"
    private var statusItem: NSStatusItem?
    private var flashTask: Task<Void, Never>?

    private enum Action {
        case saveCurrent
        case restoreDockAligned
        case restoreExact
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()

        let modifiers = UInt32(controlKey | optionKey | cmdKey)
        HotKeys.shared.register(keyCode: UInt32(kVK_ANSI_S), modifiers: modifiers) { [weak self] in
            self?.perform(.saveCurrent)
        }
        HotKeys.shared.register(keyCode: UInt32(kVK_ANSI_R), modifiers: modifiers) { [weak self] in
            self?.perform(.restoreDockAligned)
        }
        HotKeys.shared.register(keyCode: UInt32(kVK_ANSI_E), modifiers: modifiers) { [weak self] in
            self?.perform(.restoreExact)
        }
    }

    // MARK: - Menu bar

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusImage()

        let menu = NSMenu()
        menu.addItem(menuItem("保存当前窗口", #selector(saveCurrentWindow), "s"))
        menu.addItem(menuItem("还原（左沿对齐程序坞）", #selector(restoreDockAlignedWindow), "r"))
        menu.addItem(menuItem("还原（精确）", #selector(restoreExactWindow), "e"))
        menu.addItem(.separator())
        menu.addItem(menuItem("查看已保存的窗口", #selector(showSavedWindow), ""))
        menu.addItem(menuItem("辅助功能设置…", #selector(openAccessibilitySettings), ""))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    private func menuItem(_ title: String, _ selector: Selector, _ keyEquivalent: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: keyEquivalent)
        if !keyEquivalent.isEmpty {
            item.keyEquivalentModifierMask = [.control, .option, .command]
        }
        return item
    }

    private func statusImage() -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "DockSnap")
        image?.isTemplate = true
        return image
    }

    private func flash(_ message: String) {
        guard let button = statusItem?.button else { return }
        flashTask?.cancel()
        button.image = nil
        button.title = " " + message + " "
        flashTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            guard !Task.isCancelled, let self else { return }
            self.statusItem?.button?.title = ""
            self.statusItem?.button?.image = self.statusImage()
        }
    }

    // MARK: - Actions

    private func perform(_ action: Action) {
        let outcome: WindowLayout.Outcome
        switch action {
        case .saveCurrent:
            outcome = WindowLayout.saveCurrent()
        case .restoreDockAligned:
            outcome = WindowLayout.restore(dockAligned: true)
        case .restoreExact:
            outcome = WindowLayout.restore(dockAligned: false)
        }

        flash(outcome.message)
        if outcome == .needsAccessibility {
            openAccessibilitySettings()
        }
    }

    @objc private func saveCurrentWindow() {
        perform(.saveCurrent)
    }

    @objc private func restoreDockAlignedWindow() {
        perform(.restoreDockAligned)
    }

    @objc private func restoreExactWindow() {
        perform(.restoreExact)
    }

    @objc private func showSavedWindow() {
        let text: String
        if let frame = FrameStore.load() {
            text = "x=\(Int(frame.origin.x))  y=\(Int(frame.origin.y))  \(Int(frame.width))×\(Int(frame.height))"
        } else {
            text = "尚未保存任何窗口"
        }

        let alert = NSAlert()
        alert.messageText = "已保存的窗口"
        alert.informativeText = text
        alert.addButton(withTitle: "好")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    @objc private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }
}
