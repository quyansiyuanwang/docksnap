import AppKit
import ApplicationServices
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let symbolName = "rectangle.split.2x1"
    private var statusItem: NSStatusItem?
    private var flashTask: Task<Void, Never>?
    private let modifierStore = HotKeyModifiersStore()
    private var selectedModifiers = HotKeyModifiers.defaultValue
    private var saveMenuItem: NSMenuItem?
    private var restoreDockAlignedMenuItem: NSMenuItem?
    private var restoreExactMenuItem: NSMenuItem?
    private var modifierMenuItems: [HotKeyModifiers: NSMenuItem] = [:]

    private enum Action {
        case saveCurrent
        case restoreDockAligned
        case restoreExact
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        selectedModifiers = modifierStore.load()
        configureStatusItem()
        writeStatusFile()

        if !registerHotKeys(for: selectedModifiers) {
            let fallback = HotKeyModifiers.defaultValue
            if selectedModifiers != fallback, registerHotKeys(for: fallback) {
                selectedModifiers = fallback
                modifierStore.save(fallback)
                updateShortcutPresentation()
                flash("快捷键不可用，已恢复默认")
            } else {
                flash("全局快捷键注册失败")
            }
        }
    }

    // MARK: - Menu bar

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = statusImage()

        let menu = NSMenu()
        let saveItem = menuItem("保存当前窗口", #selector(saveCurrentWindow), "s")
        let restoreDockAlignedItem = menuItem("还原（左沿对齐程序坞）", #selector(restoreDockAlignedWindow), "r")
        let restoreExactItem = menuItem("还原（精确）", #selector(restoreExactWindow), "e")
        saveMenuItem = saveItem
        restoreDockAlignedMenuItem = restoreDockAlignedItem
        restoreExactMenuItem = restoreExactItem

        menu.addItem(saveItem)
        menu.addItem(restoreDockAlignedItem)
        menu.addItem(restoreExactItem)
        menu.addItem(.separator())
        menu.addItem(modifierMenuItem())
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
            item.keyEquivalentModifierMask = selectedModifiers.appKitFlags
        }
        return item
    }

    private func modifierMenuItem() -> NSMenuItem {
        let title = "快捷键修饰键"
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: title)

        for modifiers in HotKeyModifiers.allCases {
            let choice = NSMenuItem(title: modifiers.symbol, action: #selector(selectHotKeyModifiers(_:)), keyEquivalent: "")
            choice.target = self
            choice.representedObject = modifiers.rawValue
            choice.state = modifiers == selectedModifiers ? .on : .off
            submenu.addItem(choice)
            modifierMenuItems[modifiers] = choice
        }

        item.submenu = submenu
        return item
    }

    private func updateShortcutPresentation() {
        let flags = selectedModifiers.appKitFlags
        saveMenuItem?.keyEquivalentModifierMask = flags
        restoreDockAlignedMenuItem?.keyEquivalentModifierMask = flags
        restoreExactMenuItem?.keyEquivalentModifierMask = flags

        for (modifiers, item) in modifierMenuItems {
            item.state = modifiers == selectedModifiers ? .on : .off
        }
    }

    private func statusImage() -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: "DockSnap")
        image?.isTemplate = true
        return image
    }

    private func writeStatusFile() {
        let trusted = AXIsProcessTrusted()
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let text = "trusted=\(trusted)\nversion=\(version)\n"
        try? text.write(
            to: FrameStore.shared.directory.appendingPathComponent("status.txt"),
            atomically: true,
            encoding: .utf8
        )
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

    // MARK: - Hot keys

    private func registerHotKeys(for modifiers: HotKeyModifiers) -> Bool {
        HotKeys.shared.unregisterAll()

        let registrations: [(keyCode: UInt32, action: Action)] = [
            (UInt32(kVK_ANSI_S), .saveCurrent),
            (UInt32(kVK_ANSI_R), .restoreDockAligned),
            (UInt32(kVK_ANSI_E), .restoreExact)
        ]

        for registration in registrations {
            let registered = HotKeys.shared.register(
                keyCode: registration.keyCode,
                modifiers: modifiers.carbonFlags
            ) { [weak self] in
                self?.perform(registration.action)
            }
            guard registered else {
                HotKeys.shared.unregisterAll()
                return false
            }
        }
        return true
    }

    @objc private func selectHotKeyModifiers(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let modifiers = HotKeyModifiers(rawValue: rawValue),
              modifiers != selectedModifiers else {
            return
        }

        let previousModifiers = selectedModifiers
        guard registerHotKeys(for: modifiers) else {
            _ = registerHotKeys(for: previousModifiers)
            flash("\(modifiers.symbol) 快捷键注册失败")
            return
        }

        selectedModifiers = modifiers
        modifierStore.save(modifiers)
        updateShortcutPresentation()
        flash("快捷键已设为 \(modifiers.symbol)")
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
        if let frame = FrameStore.shared.load() {
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
