import AppKit
import SwiftUI

private final class LockScreenPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

final class LockScreenWindowManager {
    private var panels: [NSPanel] = []
    private var space: LockScreenSpace?
    var isPresented: Bool { !panels.isEmpty }

    func show() -> Bool {
        guard !isPresented else { return true }
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first,
              screen.frame.width >= 800, screen.frame.height >= 600,
              let space = LockScreenSpace() else { return false }
        self.space = space
        let layout = LockScreenLayout(size: screen.frame.size)
        let origin = screen.frame.origin
        let music = makePanel(rect: layout.music.offsetBy(dx: origin.x, dy: origin.y),
                              view: LockScreenMusicView(artworkSize: layout.artworkSize), interactive: true)
        let lyrics = makePanel(rect: layout.lyrics.offsetBy(dx: origin.x, dy: origin.y),
                               view: LockScreenLyricsView(), interactive: false)
        panels = [music, lyrics]
        // AppKit assigns the WindowServer ID when ordering in. Keep the windows
        // invisible until every panel is attached to the lock-screen space.
        panels.forEach { $0.alphaValue = 0; $0.orderFrontRegardless() }
        space.present()
        guard panels.allSatisfy({ space.attach($0) }) else { hide(); return false }
        panels.forEach { $0.alphaValue = 1; $0.orderFrontRegardless() }
        return true
    }

    private func makePanel<V: View>(rect: NSRect, view: V, interactive: Bool) -> NSPanel {
        let panel = LockScreenPanel(contentRect: rect, styleMask: [.borderless, .nonactivatingPanel],
                                    backing: .buffered, defer: false)
        panel.isReleasedWhenClosed = false
        panel.level = .screenSaver
        panel.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.canBecomeVisibleWithoutLogin = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.ignoresMouseEvents = !interactive
        panel.appearance = NSAppearance(named: .darkAqua)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: rect.size)
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        return panel
    }

    func hide() {
        panels.forEach { $0.orderOut(nil); $0.contentView = nil; $0.close() }
        panels.removeAll()
        space = nil
    }
    deinit { hide() }
}

final class LockScreenPreviewWindowManager: NSObject, NSWindowDelegate {
    static let shared = LockScreenPreviewWindowManager()
    private var window: NSWindow?
    func show() {
        if window == nil {
            let panel = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
                                 styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            panel.title = "Lock Screen layout preview — your Mac is not locked"
            panel.minSize = NSSize(width: 800, height: 640)
            panel.isReleasedWhenClosed = false
            panel.contentView = NSHostingView(rootView: LockScreenLayoutPreview())
            panel.delegate = self; panel.center(); window = panel
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
    func windowWillClose(_ notification: Notification) {
        window?.contentView = nil; window = nil
    }
}

private struct LockScreenLayoutPreview: View {
    @ObservedObject private var player = MusicPlayerService.shared
    private let wallpaper = NSScreen.main
        .flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
        .flatMap { NSImage(contentsOf: $0) }
    var body: some View {
        GeometryReader { geo in
            let layout = LockScreenLayout(size: geo.size)
            ZStack {
                Color(white: 0.09)
                if let wallpaper {
                    Image(nsImage: wallpaper).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height).clipped()
                }
                VStack(spacing: 10) {
                    Text("Your system wallpaper and clock remain visible").font(.headline)
                    Text("Preview only · Lock with Control–Command–Q to test").font(.caption)
                }.foregroundStyle(.secondary).position(x: geo.size.width / 2, y: geo.size.height * 0.16)
                if player.currentTrack != nil {
                    LockScreenMusicView(artworkSize: layout.artworkSize)
                        .frame(width: layout.music.width, height: layout.music.height)
                        .position(x: layout.music.midX, y: geo.size.height - layout.music.midY)
                    LockScreenLyricsView().frame(width: layout.lyrics.width, height: layout.lyrics.height)
                        .position(x: layout.lyrics.midX, y: geo.size.height - layout.lyrics.midY)
                } else {
                    Text("Play music to preview the artwork and lyrics").foregroundStyle(.secondary)
                }
                Text("System sign-in area stays clear").font(.caption).foregroundStyle(.secondary)
                    .position(x: geo.size.width / 2, y: geo.size.height - 80)
            }
        }.preferredColorScheme(.dark)
    }
}
