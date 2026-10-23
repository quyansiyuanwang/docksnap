import AppKit
import Carbon.HIToolbox
import Foundation
import Testing

@testable import DockSnap

@Suite("HotKeyModifiers")
struct HotKeyModifiersTests {
    @Test("exposes the eight supported combinations in menu order")
    func exposesSupportedCombinations() {
        #expect(HotKeyModifiers.allCases == [
            .controlOptionCommand,
            .controlOptionShift,
            .controlShift,
            .optionShift,
            .controlOption,
            .commandOptionShift,
            .commandControl,
            .commandOption
        ])
        #expect(HotKeyModifiers.allCases.map(\.symbol) == [
            "⌃⌥⌘",
            "⌃⌥⇧",
            "⌃⇧",
            "⌥⇧",
            "⌃⌥",
            "⌘⌥⇧",
            "⌘⌃",
            "⌘⌥"
        ])
        #expect(HotKeyModifiers.defaultValue == .controlOptionCommand)
    }

    @Test("maps each combination to Carbon modifiers")
    func mapsCarbonModifiers() {
        let expected: [(HotKeyModifiers, UInt32)] = [
            (.controlOptionCommand, UInt32(controlKey | optionKey | cmdKey)),
            (.controlOptionShift, UInt32(controlKey | optionKey | shiftKey)),
            (.controlShift, UInt32(controlKey | shiftKey)),
            (.optionShift, UInt32(optionKey | shiftKey)),
            (.controlOption, UInt32(controlKey | optionKey)),
            (.commandOptionShift, UInt32(cmdKey | optionKey | shiftKey)),
            (.commandControl, UInt32(cmdKey | controlKey)),
            (.commandOption, UInt32(cmdKey | optionKey))
        ]

        for (modifiers, flags) in expected {
            #expect(modifiers.carbonFlags == flags)
        }
    }

    @Test("maps each combination to AppKit modifier flags")
    func mapsAppKitModifiers() {
        let expected: [(HotKeyModifiers, NSEvent.ModifierFlags)] = [
            (.controlOptionCommand, [.control, .option, .command]),
            (.controlOptionShift, [.control, .option, .shift]),
            (.controlShift, [.control, .shift]),
            (.optionShift, [.option, .shift]),
            (.controlOption, [.control, .option]),
            (.commandOptionShift, [.command, .option, .shift]),
            (.commandControl, [.command, .control]),
            (.commandOption, [.command, .option])
        ]

        for (modifiers, flags) in expected {
            #expect(modifiers.appKitFlags == flags)
        }
    }

    @Test("persists and restores the selected combination")
    func persistsSelection() {
        let suiteName = "DockSnapTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = HotKeyModifiersStore(defaults: defaults)

        #expect(store.load() == .controlOptionCommand)
        store.save(.commandControl)
        #expect(store.load() == .commandControl)
    }

    @Test("invalid persisted data falls back to the default")
    func invalidSelectionFallsBackToDefault() {
        let suiteName = "DockSnapTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("invalid", forKey: HotKeyModifiersStore.defaultsKey)

        #expect(HotKeyModifiersStore(defaults: defaults).load() == .controlOptionCommand)
    }
}
