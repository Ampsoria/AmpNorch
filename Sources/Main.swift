import AppKit
import SwiftUI

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // NSApplication's delegate is weak. Keep its status-item owner alive in
        // optimized builds for the entire run loop, not just through assignment.
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set accessory policy so it doesn't clutter the Dock
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize status bar menu
        statusBarController = StatusBarController()
        
        // Setup notch window overlay
        NotchWindowManager.shared.setup()
        
        // Start background services
        _ = MusicPlayerService.shared
        _ = IdleTrackerService.shared
        _ = WebSocketBridgeService.shared
        _ = BatteryService.shared
        _ = WeatherService.shared
        _ = ShazamService.shared
        _ = AirPodsService.shared
        _ = AirPodsProximityService.shared
        _ = SystemHUDService.shared
        _ = LockScreenService.shared
        DispatchQueue.main.async { SetupWindowManager.shared.showOnFirstLaunch() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        LockScreenService.shared.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowManager.shared.show()
        return true
    }
}
