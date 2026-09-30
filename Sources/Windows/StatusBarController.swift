import AppKit

public final class StatusBarController {
    private var statusItem: NSStatusItem
    public init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "AmpNotch.StatusItem"
        statusItem.behavior = []
        statusItem.isVisible = true
        statusItem.button?.image = StatusBarIcon.load()
        statusItem.button?.toolTip = "AmpNotch"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "AmpNotch", action: nil, keyEquivalent: ""))
        add("Settings…", #selector(settings), to: menu, key: ",")
        add("Setup & permissions…", #selector(setupPermissions), to: menu)
        add("Show / Hide Notch", #selector(toggle), to: menu)
        add("Open StandBy", #selector(standBy), to: menu)
        add("Identify a Song", #selector(recognize), to: menu)
        menu.addItem(.separator())
        add("Quit AmpNotch", #selector(quit), to: menu, key: "q")
        statusItem.menu = menu
    }
    private func add(_ title: String, _ action: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key); item.target = self; menu.addItem(item)
    }
    @objc private func settings() { SettingsWindowManager.shared.show() }
    @objc private func setupPermissions() { SetupWindowManager.shared.show() }
    @objc private func toggle() { NotchWindowManager.shared.toggleVisibility() }
    @objc private func standBy() { IdleTrackerService.shared.triggerStandByNow() }
    @objc private func recognize() { ShazamService.shared.toggleListening() }
    @objc private func quit() { NSApp.terminate(nil) }
}
