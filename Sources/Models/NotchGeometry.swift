import Foundation

enum NotchGeometry {
    static func frame(screen: CGRect, notchWidth: CGFloat, notchHeight: CGFloat,
                      expanded: Bool, activity: NotchActivity.Kind?, extraHeight: CGFloat = 0,
                      activityExpanded: Bool = false) -> CGRect {
        let width: CGFloat
        let height: CGFloat
        switch activity {
        case .capsLock:
            width = max(240, notchWidth + 48)
            height = notchHeight + 36
        case .volume, .charging:
            width = max(280, notchWidth + 48)
            height = notchHeight + 52
        case .headphones:
            width = max(300, notchWidth + 48)
            height = notchHeight + 56
        case .airPodsCase:
            width = activityExpanded ? max(320, notchWidth + 48) : notchWidth + 92
            height = activityExpanded ? notchHeight + 68 : max(32, notchHeight)
        case .recognition:
            width = max(376, notchWidth + 92)
            height = notchHeight + 94
        case nil:
            width = expanded ? max(376, notchWidth + 92) : notchWidth + 92
            height = expanded ? notchHeight + 138 + extraHeight : max(32, notchHeight)
        }
        return CGRect(x: screen.midX - width / 2, y: screen.maxY - height, width: width, height: height)
    }
}
