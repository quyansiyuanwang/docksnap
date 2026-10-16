import AppKit

/// Persisted window frame, stored under Application Support.
struct SavedFrame: Codable, Sendable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double

    init(_ rect: CGRect) {
        x = rect.origin.x
        y = rect.origin.y
        width = rect.width
        height = rect.height
    }

    var rect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }
}

enum FrameStore {
    static var directory: URL {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DockSnap", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    static var fileURL: URL {
        directory.appendingPathComponent("frame.json")
    }

    @discardableResult
    static func save(_ rect: CGRect) -> Bool {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(SavedFrame(rect))
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func load() -> CGRect? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return (try? JSONDecoder().decode(SavedFrame.self, from: data))?.rect
    }
}
