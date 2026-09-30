import SwiftUI
import AppKit
import Combine

public final class NotchWindowManager: ObservableObject {
    public static let shared = NotchWindowManager()
    private var window: NSPanel?
    private var hosting: NSHostingView<NotchContainerView>?
    private var surface: NSView?
    private var contentRoot: NSView?
    private var subscriptions = Set<AnyCancellable>()
    private let presentation = NotchPresentationService.shared

    private var targetScreen: NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.screens.first
    }

    public func setup() {
        guard window == nil, let screen = targetScreen else { return }
        updateScreenMetrics(screen)
        let panel = NSPanel(contentRect: frame(on: screen),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar + 1
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.appearance = NSAppearance(named: .darkAqua)
        let root = NSView(frame: NSRect(origin: .zero, size: panel.frame.size))
        root.autoresizingMask = [.width, .height]
        let host = NSHostingView(rootView: NotchContainerView())
        host.sizingOptions = []
        host.frame = root.bounds
        host.autoresizingMask = [.width, .height]
        root.addSubview(host)
        panel.contentView = root
        contentRoot = root
        hosting = host
        window = panel
        rebuildSurface()
        GlassAppearanceSettings.shared.$notchOpacity.removeDuplicates()
            .receive(on: DispatchQueue.main).sink { [weak self] opacity in
                self?.updateSurfaceOpacity(opacity)
            }.store(in: &subscriptions)
        presentation.objectWillChange.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.refresh()
        }.store(in: &subscriptions)
        MusicPlayerService.shared.$errorMessage.removeDuplicates().receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .sink { [weak self] _ in
                guard let self, let screen = self.targetScreen else { return }
                self.updateScreenMetrics(screen)
                self.refresh()
            }.store(in: &subscriptions)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification)
            .sink { [weak self] _ in self?.rebuildSurface() }.store(in: &subscriptions)
        panel.orderFrontRegardless()
    }

    private func updateScreenMetrics(_ screen: NSScreen) {
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            presentation.notchWidth = max(0, right.minX - left.maxX)
        } else { presentation.notchWidth = 100 }
        presentation.notchHeight = screen.safeAreaInsets.top
    }

    private var isOpen: Bool {
        if presentation.activity?.kind == .airPodsCase { return presentation.isActivityExpanded }
        return presentation.isExpanded || (presentation.activity != nil)
    }

    private func frame(on screen: NSScreen) -> NSRect {
        return NotchGeometry.frame(screen: screen.frame, notchWidth: presentation.notchWidth,
            notchHeight: presentation.notchHeight, expanded: presentation.isExpanded, activity: presentation.activity?.kind,
            extraHeight: MusicPlayerService.shared.errorMessage == nil ? 0 : 44,
            activityExpanded: presentation.isActivityExpanded)
    }

    private var appliedStyle: NotchGlassStyle?
    private var appliedOpen: Bool?
    private func rebuildSurface() {
        guard let window, let contentRoot, let hosting else { return }
        // Keep SwiftUI and its hover/gesture state alive while only replacing the
        // native background material. Glass never owns or resizes the content host.
        surface?.removeFromSuperview()
        let radius: CGFloat = isOpen ? 28 : 16
        let reduceTransparency = NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        let root: NSView
        if #available(macOS 26.0, *), presentation.glassStyle != .black, !reduceTransparency, isOpen {
            let glass = NSGlassEffectView()
            glass.style = presentation.glassStyle == .clear ? .clear : .regular
            glass.cornerRadius = radius
            glass.tintColor = nil
            // Expanded content uses glass; the resting capsule stays black.
            // Fade only the material, never the artwork or controls.
            root = glass
        } else if presentation.glassStyle != .black && !reduceTransparency && isOpen {
            let blur = NSVisualEffectView()
            blur.material = .hudWindow
            blur.blendingMode = .behindWindow
            blur.state = .active
            root = blur
        } else {
            root = NSView()
            root.wantsLayer = true
            root.layer?.backgroundColor = NSColor.black.cgColor
            if !isOpen {
                root.layer?.borderWidth = 1
                root.layer?.borderColor = NSColor(white: 0.2, alpha: 1).cgColor
            }
        }
        root.frame = NSRect(origin: .zero, size: window.frame.size)
        root.autoresizingMask = [.width, .height]
        // The native compositor owns the glass edge and refraction.
        if presentation.glassStyle == .black || reduceTransparency || !isOpen {
            root.layer?.cornerRadius = radius
            root.layer?.masksToBounds = true
        }
        contentRoot.addSubview(root, positioned: .below, relativeTo: hosting)
        surface = root
        updateSurfaceOpacity(GlassAppearanceSettings.shared.notchOpacity)
        appliedStyle = presentation.glassStyle
        appliedOpen = isOpen
    }

    private func updateSurfaceOpacity(_ opacity: Double) {
        let opaque = !isOpen || presentation.glassStyle == .black || NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        surface?.alphaValue = opaque ? 1 : CGFloat(GlassAppearanceSettings.validOpacity(opacity))
    }

    private func refresh() {
        guard let window, let screen = targetScreen else { return }
        if appliedStyle != presentation.glassStyle || appliedOpen != isOpen { rebuildSurface() }
        let radius: CGFloat = isOpen ? 28 : 16
        if #available(macOS 26.0, *), let glass = surface as? NSGlassEffectView { glass.cornerRadius = radius }
        else {
            surface?.wantsLayer = true
            surface?.layer?.cornerRadius = radius
            surface?.layer?.masksToBounds = true
        }
        let destination = frame(on: screen)
        guard window.frame != destination else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.3
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(destination, display: true)
        }
    }

    public func updateWindowFrame(expanded: Bool) { presentation.isExpanded = expanded }
    public func toggleVisibility() {
        guard let window else { return }
        if window.isVisible { window.orderOut(nil) } else { window.orderFrontRegardless() }
    }
}
