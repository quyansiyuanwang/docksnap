import CoreGraphics

/// Decides which Accessibility attributes must be written to move a window from
/// its current frame to a target frame.
///
/// Writing `AXPosition` after `AXSize` can make some applications restore the
/// previous size, even though both writes report success. A plan therefore
/// always emits the position before the size, and never touches an attribute
/// whose current value already matches the target.
enum FramePlan {
    /// AX coordinates are fractional. One point of slack avoids pointless
    /// writes when the window server has already rounded to the same pixel.
    static let tolerance: CGFloat = 1

    enum Mutation: Equatable {
        case position(CGPoint)
        case size(CGSize)
    }

    static func mutations(to target: CGRect, from current: CGRect) -> [Mutation] {
        var mutations: [Mutation] = []
        if !positionsMatch(target, current) {
            mutations.append(.position(target.origin))
        }
        if !sizesMatch(target, current) {
            mutations.append(.size(target.size))
        }
        return mutations
    }

    static func matches(_ target: CGRect, _ current: CGRect) -> Bool {
        positionsMatch(target, current) && sizesMatch(target, current)
    }

    static func positionsMatch(_ target: CGRect, _ current: CGRect) -> Bool {
        abs(target.minX - current.minX) <= tolerance
            && abs(target.minY - current.minY) <= tolerance
    }

    static func sizesMatch(_ target: CGRect, _ current: CGRect) -> Bool {
        abs(target.width - current.width) <= tolerance
            && abs(target.height - current.height) <= tolerance
    }
}
