import AppKit
import Carbon.HIToolbox
import Foundation

/// The shared modifier combination used by every global hot key. Keeping the
/// Carbon, AppKit, menu-label, and persistence representations together keeps
/// the registered shortcut in sync with the menu hint.
enum HotKeyModifiers: String, CaseIterable, Sendable {
    case controlOptionCommand
    case controlOptionShift
    case controlShift
    case optionShift
    case controlOption
    case commandOptionShift
    case commandControl
    case commandOption

    static let defaultValue = HotKeyModifiers.controlOptionCommand

    var symbol: String {
        switch self {
        case .controlOptionCommand:
            "⌃⌥⌘"
        case .controlOptionShift:
            "⌃⌥⇧"
        case .controlShift:
            "⌃⇧"
        case .optionShift:
            "⌥⇧"
        case .controlOption:
            "⌃⌥"
        case .commandOptionShift:
            "⌘⌥⇧"
        case .commandControl:
            "⌘⌃"
        case .commandOption:
            "⌘⌥"
        }
    }

    var carbonFlags: UInt32 {
        switch self {
        case .controlOptionCommand:
            UInt32(controlKey | optionKey | cmdKey)
        case .controlOptionShift:
            UInt32(controlKey | optionKey | shiftKey)
        case .controlShift:
            UInt32(controlKey | shiftKey)
        case .optionShift:
            UInt32(optionKey | shiftKey)
        case .controlOption:
            UInt32(controlKey | optionKey)
        case .commandOptionShift:
            UInt32(cmdKey | optionKey | shiftKey)
        case .commandControl:
            UInt32(cmdKey | controlKey)
        case .commandOption:
            UInt32(cmdKey | optionKey)
        }
    }

    var appKitFlags: NSEvent.ModifierFlags {
        switch self {
        case .controlOptionCommand:
            [.control, .option, .command]
        case .controlOptionShift:
            [.control, .option, .shift]
        case .controlShift:
            [.control, .shift]
        case .optionShift:
            [.option, .shift]
        case .controlOption:
            [.control, .option]
        case .commandOptionShift:
            [.command, .option, .shift]
        case .commandControl:
            [.command, .control]
        case .commandOption:
            [.command, .option]
        }
    }
}

/// Persists the selected modifier combination. The injected defaults instance
/// keeps tests isolated from the application's preferences.
struct HotKeyModifiersStore {
    static let defaultsKey = "hotKeyModifiers"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() -> HotKeyModifiers {
        guard let rawValue = defaults.string(forKey: Self.defaultsKey),
              let modifiers = HotKeyModifiers(rawValue: rawValue) else {
            return .defaultValue
        }
        return modifiers
    }

    func save(_ modifiers: HotKeyModifiers) {
        defaults.set(modifiers.rawValue, forKey: Self.defaultsKey)
    }
}
