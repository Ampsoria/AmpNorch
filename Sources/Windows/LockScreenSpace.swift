import AppKit

/// An isolated, optional adapter for undocumented WindowServer spaces. No root,
/// authorization plug-in, login policy changes, or keyboard interception.
/// ABI references: NUIKit/CGSInternal CGSSpace.h and Lakr233/SkyLightWindow.
final class LockScreenSpace {
    private typealias Connection = @convention(c) () -> Int32
    private typealias Create = @convention(c) (Int32, Int32, UnsafeRawPointer?) -> UInt64
    private typealias Destroy = @convention(c) (Int32, UInt64) -> Void
    private typealias Level = @convention(c) (Int32, UInt64, Int32) -> Void
    private typealias Visibility = @convention(c) (Int32, CFArray) -> Void
    private typealias Move = @convention(c) (Int32, UInt64, CFArray, Int32) -> Void
    private typealias Membership = @convention(c) (Int32, UInt32, CFArray, UInt32,
        UnsafeMutablePointer<UInt64>, UnsafeMutablePointer<UInt64>) -> Unmanaged<CFArray>?

    private let library: UnsafeMutableRawPointer
    private let connection: Int32
    private let identifier: UInt64
    private let destroy: Destroy
    private let show: Visibility
    private let hide: Visibility
    private let move: Move
    private let membership: Membership

    init?() {
        guard let library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else { return nil }
        func symbol<T>(_ name: String, as type: T.Type) -> T? {
            guard let address = dlsym(library, name) else { return nil }
            return unsafeBitCast(address, to: type)
        }
        guard let connectionFunction = symbol("SLSMainConnectionID", as: Connection.self),
              let create = symbol("SLSSpaceCreate", as: Create.self),
              let destroy = symbol("SLSSpaceDestroy", as: Destroy.self),
              let level = symbol("SLSSpaceSetAbsoluteLevel", as: Level.self),
              let show = symbol("SLSShowSpaces", as: Visibility.self),
              let hide = symbol("SLSHideSpaces", as: Visibility.self),
              let move = symbol("SLSSpaceAddWindowsAndRemoveFromSpaces", as: Move.self),
              let membership = symbol("SLSCopyWindowsWithOptionsAndTags", as: Membership.self)
        else { dlclose(library); return nil }
        let connection = connectionFunction()
        let identifier = create(connection, 1, nil)
        guard identifier != 0 else { dlclose(library); return nil }
        level(connection, identifier, 400)
        self.library = library; self.connection = connection; self.identifier = identifier
        self.destroy = destroy; self.show = show; self.hide = hide; self.move = move
        self.membership = membership
    }

    func attach(_ window: NSWindow) -> Bool {
        guard window.windowNumber > 0 else { return false }
        let windows = [NSNumber(value: window.windowNumber)] as CFArray
        move(connection, identifier, windows, 7)
        // The move API has no return value. Read back membership instead of
        // interpreting undefined register contents as a CGError.
        // Query the system space directly: CopySpacesForWindows only reports
        // managed desktop spaces and returns empty for this kind of space.
        var setTags: UInt64 = 0, clearTags: UInt64 = 0
        guard let result = membership(connection, 0, [NSNumber(value: identifier)] as CFArray,
                                      7, &setTags, &clearTags)?.takeRetainedValue() else { return false }
        return (result as NSArray).contains(NSNumber(value: window.windowNumber))
    }

    func present() { show(connection, [NSNumber(value: identifier)] as CFArray) }

    deinit {
        hide(connection, [NSNumber(value: identifier)] as CFArray)
        destroy(connection, identifier)
        dlclose(library)
    }
}
