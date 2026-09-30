import AppKit
import SwiftUI

final class SettingsWindowManager {
    static let shared = SettingsWindowManager()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 510, height: 590),
                                  styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "AmpNotch Settings"
            window.contentView = NSHostingView(rootView: AmpNotchSettingsView())
            window.isReleasedWhenClosed = false
            window.center(); self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct AmpNotchSettingsView: View {
    @ObservedObject private var audio = AudioMeterService.shared
    @ObservedObject private var presentation = NotchPresentationService.shared
    @ObservedObject private var media = MusicPlayerService.shared
    @ObservedObject private var browser = WebSocketBridgeService.shared
    @ObservedObject private var airPods = AirPodsProximityService.shared
    @ObservedObject private var weather = WeatherService.shared
    @ObservedObject private var idle = IdleTrackerService.shared
    @ObservedObject private var lockScreen = LockScreenService.shared
    @AppStorage("showVolumeHUD") private var volume = true
    @AppStorage("showBatteryHUD") private var battery = true
    @AppStorage("showCapsLockHUD") private var capsLock = true
    @State private var copied = false
    var body: some View {
        VStack(spacing: 0) {
        Form {
            Section("Get started") {
                Button("Setup & permissions…") { SetupWindowManager.shared.show() }
            }
            Section("Appearance") {
                Picker("Expanded notch material", selection: $presentation.glassStyle) {
                    ForEach(NotchGlassStyle.allCases, id: \.rawValue) { Text($0.title).tag($0) }
                }
                GlassOpacityControls(notchUsesGlass: presentation.glassStyle != .black)
                Toggle("Live audio waveform", isOn: $audio.enabled)
                Text(audio.status).font(.caption).foregroundStyle(.secondary)
                Toggle("Volume notification", isOn: $volume)
                Toggle("Charging notification", isOn: $battery)
                Toggle("Caps Lock notification", isOn: $capsLock)
            }
            Section("AirPods") {
                Toggle("Detect nearby case opening", isOn: $airPods.enabled)
                Text(airPods.status).font(.caption).foregroundStyle(.secondary)
                Text("Case detection uses Bluetooth broadcasts. Nearby devices may also appear. Model and battery availability depend on the device.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("Music & browser") {
                Text(media.currentTrack.map { "\($0.playerType.rawValue) · \($0.title)" } ?? "No active media")
                    .lineLimit(1)
                if let error = media.errorMessage { Text(error).font(.caption).foregroundStyle(.orange) }
                HStack {
                    Button("Retry music connection") { media.pollCurrentPlayer() }
                    Button("Automation settings") { openSettings("Privacy_Automation") }
                }
                Text(browser.status).font(.caption).foregroundStyle(browser.isExtensionConnected ? .green : .secondary)
                HStack {
                    Button(copied ? "Pairing code copied" : "Copy browser pairing code") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(browser.pairingToken, forType: .string)
                        copied = true
                    }
                    Button("Extension folder") {
                        if let path = Bundle.main.resourceURL?.appendingPathComponent("BrowserExtension") {
                            NSWorkspace.shared.open(path)
                        }
                    }
                }
                Text("Load the extension folder in Chrome, Edge, Brave or Arc, then paste the pairing code in its popup.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Extension setup guide") {
                    if let guide = Bundle.main.url(forResource: "Extension Setup", withExtension: "txt") {
                        NSWorkspace.shared.open(guide)
                    }
                }
            }
            Section("Lock Screen") {
                Toggle("Show music and lyrics when locked", isOn: $lockScreen.enabled)
                Text(lockScreen.status).font(.caption).foregroundStyle(.secondary)
                Button("Preview Lock Screen layout") { LockScreenPreviewWindowManager.shared.show() }
                Text("Shows the current song and synced lyrics beside the system sign-in area. Music information is visible to anyone at this Mac while locked. Uses an experimental macOS integration; compatibility may change after system updates.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("StandBy") {
                Picker("Weather city", selection: $weather.city) {
                    ForEach(WeatherCity.choices) { Text($0.id).tag($0.id) }
                }
                Picker("Start when idle", selection: $idle.idleThreshold) {
                    Text("Off").tag(0.0); Text("1 minute").tag(60.0)
                    Text("2 minutes").tag(120.0); Text("5 minutes").tag(300.0)
                }
                HStack {
                    Button("Open StandBy") { idle.triggerStandByNow() }
                    Button("Bluetooth settings") { openSettings("Privacy_Bluetooth") }
                }
            }
        }.formStyle(.grouped)
        Divider()
        HStack {
            Text("AmpNotch").font(.caption).foregroundStyle(.secondary)
            Spacer()
            Button("Quit AmpNotch") { NSApp.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
        }.padding(.horizontal, 20).padding(.vertical, 12)
        }.frame(width: 510, height: 590)
    }
    private func openSettings(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") { NSWorkspace.shared.open(url) }
    }
}

private struct GlassOpacityControls: View {
    let notchUsesGlass: Bool
    @ObservedObject private var glass = GlassAppearanceSettings.shared
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            opacitySlider("Notch glass opacity", value: $glass.notchOpacity)
                .disabled(!notchUsesGlass || reduceTransparency)
            opacitySlider("Lock Screen glass opacity", value: $glass.lockScreenOpacity)
                .disabled(reduceTransparency)
            Text("Lower values make the glass clearer. The collapsed notch stays black. Text, artwork and controls stay fully visible. Changes are saved automatically.")
                .font(.caption).foregroundStyle(.secondary)
            if reduceTransparency {
                Text("Reduce Transparency is enabled in macOS Accessibility, so backgrounds remain opaque.")
                    .font(.caption).foregroundStyle(.secondary)
            } else if !notchUsesGlass {
                Text("Choose Clear or Regular to adjust the notch glass.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Button("Restore glass defaults") { glass.restoreDefaults() }
                Spacer()
                Button("Preview") { LockScreenPreviewWindowManager.shared.show() }
                    .accessibilityLabel("Preview Lock Screen glass")
            }
        }.padding(.vertical, 6)
    }

    private func opacitySlider(_ title: String, value: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                Text("\(Int((value.wrappedValue * 100).rounded()))%")
                    .monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: value, in: GlassAppearanceSettings.opacityRange, step: 0.01)
                .accessibilityLabel(title)
                .accessibilityValue("\(Int((value.wrappedValue * 100).rounded())) percent")
        }
    }
}
