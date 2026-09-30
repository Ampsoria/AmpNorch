import AppKit
import SwiftUI

final class SetupWindowManager: NSObject, NSWindowDelegate {
    static let shared = SetupWindowManager()
    private var window: NSWindow?

    func showOnFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: "setupWelcomeShown") else { return }
        show()
    }

    func show() {
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 680),
                                 styleMask: [.titled, .closable], backing: .buffered, defer: false)
            panel.title = "Set up AmpNotch"
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: SetupPermissionsView())
            panel.delegate = self
            panel.center(); window = panel
        }
        UserDefaults.standard.set(true, forKey: "setupWelcomeShown")
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() { window?.close() }
    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil; window = nil
    }
}

private struct SetupPermissionsView: View {
    @StateObject private var permissions = SetupPermissionsService()
    @ObservedObject private var audio = AudioMeterService.shared
    @ObservedObject private var bluetooth = AirPodsProximityService.shared
    @ObservedObject private var browser = WebSocketBridgeService.shared

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Welcome to AmpNotch").font(.title2.bold())
                Text("Choose the features you want. macOS asks for permission when you enable them. You can skip any step and return from Settings → Setup & permissions.")
                    .font(.callout).foregroundStyle(.secondary)
            }.frame(maxWidth: .infinity, alignment: .leading).padding(22)
            Divider()
            Form {
                Section("1. Music controls · Automation") {
                    Text("Allow the player you use so AmpNotch can read the song and control playback.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Connect Apple Music") { permissions.connect(.appleMusic) }
                        Button("Connect Spotify") { permissions.connect(.spotify) }
                    }.disabled(permissions.requesting != nil)
                    Text("Apple Music: \(permissions.musicStatus)").font(.caption)
                    Text("Spotify: \(permissions.spotifyStatus)").font(.caption)
                    Button("Open Automation settings") { SetupPermissionsService.openPrivacy("Privacy_Automation") }
                }
                Section("2. Live waveform · System audio") {
                    Text("Optional. Reads system sound locally to animate the bars. No audio is saved or uploaded.")
                        .font(.caption).foregroundStyle(.secondary)
                    if #available(macOS 14.2, *) {
                        HStack {
                            Button(audio.enabled ? "Retry audio connection" : "Enable live waveform") { permissions.enableWaveform() }
                            Button("Open audio permissions") { SetupPermissionsService.openPrivacy("Privacy_ScreenCapture") }
                        }
                        Text(audio.status).font(.caption)
                        Text("In Screen & System Audio Recording, enable AmpNotch under System Audio Recording Only. If macOS asks to restart the app, reopen AmpNotch afterwards.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Live waveform requires macOS 14.2 or later.").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Section("3. AirPods · Bluetooth") {
                    Text("Optional. Detects nearby case-opening broadcasts and Bluetooth headphone connections.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button(bluetooth.enabled ? "Check Bluetooth access" : "Enable AirPods detection") { permissions.enableBluetooth() }
                        Button("Open Bluetooth permissions") { SetupPermissionsService.openPrivacy("Privacy_Bluetooth") }
                    }
                    Text(bluetooth.status).font(.caption)
                }
                Section("4. Identify songs · Microphone") {
                    Text("Optional. Needed only for Shazam song recognition, not for normal music playback or the waveform.")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("Allow microphone") { permissions.requestMicrophone() }
                        Button("Open Microphone settings") { SetupPermissionsService.openPrivacy("Privacy_Microphone") }
                    }
                    Text(permissions.microphoneStatus).font(.caption)
                }
                Section("5. Browser music · Extension") {
                    Text("Optional. For Chrome, Edge, Brave or Arc, install Ampsoria Connected and pair it with this Mac. Apple Music and Spotify do not need the extension.")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(browser.status).font(.caption)
                    HStack {
                        Button("Open extension setup guide") {
                            if let url = Bundle.main.url(forResource: "Extension Setup", withExtension: "txt") { NSWorkspace.shared.open(url) }
                        }
                        Button("Extension & pairing settings") { SettingsWindowManager.shared.show() }
                    }
                }
            }.formStyle(.grouped)
            Divider()
            HStack {
                Button("Refresh status") { permissions.refresh() }
                Spacer()
                Button("Done / Set up later") { SetupWindowManager.shared.close() }
                    .keyboardShortcut(.defaultAction)
            }.padding(16)
        }
        .frame(width: 560, height: 680)
        .onAppear { permissions.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in permissions.refresh() }
    }
}
