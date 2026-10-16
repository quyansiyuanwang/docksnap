import CoreGraphics
import Testing

@testable import DockSnap

@Suite("Screens.clamp")
struct ScreensClampTests {
    private let bounds = CGRect(x: 0, y: 25, width: 1440, height: 790)

    @Test("a frame that already fits is returned unchanged")
    func keepsAFittingFrame() {
        let frame = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(Screens.clamp(frame, into: bounds) == frame)
    }

    @Test("a frame past the top-left corner is pinned to it")
    func pinsToTheTopLeft() {
        let clamped = Screens.clamp(CGRect(x: -40, y: -10, width: 400, height: 300), into: bounds)
        #expect(clamped.origin == CGPoint(x: 0, y: 25))
    }

    @Test("a frame past the bottom-right corner is pinned to it")
    func pinsToTheBottomRight() {
        let clamped = Screens.clamp(CGRect(x: 5_000, y: 5_000, width: 400, height: 300), into: bounds)
        #expect(clamped.origin == CGPoint(x: 1_040, y: 515))
    }

    @Test("a frame larger than the screen keeps its size and its top-left corner")
    func keepsTheSizeWhenOversized() {
        let oversized = CGRect(x: 200, y: 200, width: 2_000, height: 2_000)
        let clamped = Screens.clamp(oversized, into: bounds)
        #expect(clamped.origin == CGPoint(x: 0, y: 25))
        #expect(clamped.size == oversized.size)
    }
}
