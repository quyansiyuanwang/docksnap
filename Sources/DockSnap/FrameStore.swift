import CoreGraphics
import Foundation

/// A persisted window frame. Coordinates use the Accessibility API space
/// (origin at the top-left of the primary display, y growing downwards).
struct SavedFrame: Codable, Sendable, Equatable {
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

/// Reads and writes the single saved frame as JSON. The directory is injectable
/// so tests never touch the real Application Support location.
struct FrameStore: Sendable {
    static let shared = FrameStore(directory: defaultDirectory)

    static var defaultDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DockSnap", isDirectory: true)
    }

    let directory: URL

    init(directory: URL) {
        self.directory = directory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    var fileURL: URL {
        directory.appendingPathComponent("frame.json")
    }

    @discardableResult
    func save(_ rect: CGRect) -> Bool {
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

    func load() -> CGRect? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return (try? JSONDecoder().decode(SavedFrame.self, from: data))?.rect
    }
}
