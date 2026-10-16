import CoreGraphics
import Foundation
import Testing

@testable import DockSnap

@Suite("FrameStore")
struct FrameStoreTests {
    private func makeStore() -> (store: FrameStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DockSnapTests-\(UUID().uuidString)", isDirectory: true)
        return (FrameStore(directory: directory), directory)
    }

    @Test("a saved frame survives a JSON round trip")
    func roundTripsThroughDisk() {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let frame = CGRect(x: 158, y: 25, width: 1_282, height: 789)
        #expect(store.save(frame))
        #expect(store.load() == frame)
    }

    @Test("loading before anything is saved returns nil")
    func returnsNilWhenEmpty() {
        let (store, directory) = makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        #expect(store.load() == nil)
    }

    @Test("SavedFrame preserves the fractional rect")
    func savedFramePreservesTheRect() {
        let rect = CGRect(x: 1.5, y: 2.5, width: 3.5, height: 4.5)
        #expect(SavedFrame(rect).rect == rect)
    }
}
