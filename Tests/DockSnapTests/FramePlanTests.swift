import CoreGraphics
import Testing

@testable import DockSnap

@Suite("FramePlan")
struct FramePlanTests {
    private let current = CGRect(x: 100, y: 80, width: 800, height: 600)

    @Test("an identical frame needs no writes")
    func leavesAnIdenticalFrameAlone() {
        #expect(FramePlan.mutations(to: current, from: current).isEmpty)
        #expect(FramePlan.matches(current, current))
    }

    @Test("a position-only change does not write the size")
    func movesWithoutResizing() {
        let target = CGRect(x: 240, y: 160, width: current.width, height: current.height)
        #expect(FramePlan.mutations(to: target, from: current) == [.position(target.origin)])
    }

    @Test("a size-only change does not write the position")
    func resizesWithoutMoving() {
        let target = CGRect(x: current.origin.x, y: current.origin.y, width: 1_000, height: 700)
        #expect(FramePlan.mutations(to: target, from: current) == [.size(target.size)])
    }

    @Test("the position is written before the size")
    func writesPositionFirst() {
        let target = CGRect(x: 240, y: 160, width: 1_000, height: 700)
        #expect(
            FramePlan.mutations(to: target, from: current)
                == [.position(target.origin), .size(target.size)]
        )
    }

    @Test("sub-point differences are treated as already applied")
    func ignoresSubPointDifferences() {
        let target = current.offsetBy(dx: 0.5, dy: -0.5)
        #expect(FramePlan.mutations(to: target, from: current).isEmpty)
        #expect(FramePlan.matches(target, current))
    }

    @Test("differences above the tolerance are corrected")
    func correctsDifferencesAboveTolerance() {
        let target = current.offsetBy(dx: FramePlan.tolerance + 0.5, dy: 0)
        #expect(FramePlan.mutations(to: target, from: current) == [.position(target.origin)])
        #expect(!FramePlan.matches(target, current))
    }

    @Test("position and size matches are evaluated independently")
    func reportsPositionAndSizeSeparately() {
        let moved = current.offsetBy(dx: 50, dy: 0)
        #expect(!FramePlan.positionsMatch(moved, current))
        #expect(FramePlan.sizesMatch(moved, current))

        let resized = CGRect(
            x: current.origin.x,
            y: current.origin.y,
            width: current.width + 50,
            height: current.height
        )
        #expect(FramePlan.positionsMatch(resized, current))
        #expect(!FramePlan.sizesMatch(resized, current))
    }
}
