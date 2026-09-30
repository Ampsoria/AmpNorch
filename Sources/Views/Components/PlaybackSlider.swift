import AppKit
import SwiftUI

/// Native mouse, keyboard and accessibility input with a thumb-free custom track.
struct PlaybackSlider: NSViewRepresentable {
    let position: Double
    let duration: Double
    let isEnabled: Bool
    let onSeek: (Double) -> Void

    func makeNSView(context: Context) -> HoverPlaybackSlider {
        let slider = HoverPlaybackSlider()
        slider.minValue = 0
        slider.isContinuous = false
        slider.setAccessibilityLabel("Playback position")
        return slider
    }

    func updateNSView(_ slider: HoverPlaybackSlider, context: Context) {
        slider.onSeek = onSeek
        slider.maxValue = duration.isFinite ? max(duration, 1) : 1
        slider.isEnabled = isEnabled && duration.isFinite && duration > 0
        if !slider.isEnabled { slider.isDragging = false }
        if !slider.isDragging {
            slider.doubleValue = position.isFinite ? min(max(position, 0), slider.maxValue) : 0
        }
        slider.updateEmphasis()
        slider.needsDisplay = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: HoverPlaybackSlider, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? 180, height: 20)
    }
}

final class HoverPlaybackSlider: NSSlider {
    var onSeek: (Double) -> Void = { _ in }
    var isDragging = false
    private var isHovering = false
    private var hoverArea: NSTrackingArea?
    @objc dynamic var barThickness: CGFloat = 4 { didSet { needsDisplay = true } }

    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 20) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override class func defaultAnimation(forKey key: NSAnimatablePropertyKey) -> Any? {
        key == "barThickness" ? CABasicAnimation() : super.defaultAnimation(forKey: key)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
        if let window {
            isHovering = bounds.contains(convert(window.mouseLocationOutsideOfEventStream, from: nil))
        }
        updateEmphasis()
    }
    override func mouseEntered(with event: NSEvent) { isHovering = true; updateEmphasis() }
    override func mouseExited(with event: NSEvent) { isHovering = false; updateEmphasis() }

    func updateEmphasis() {
        let target: CGFloat = isEnabled && (isHovering || isDragging) ? 9 : 4
        guard barThickness != target else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.16
            animator().barThickness = target
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        let bar = NSRect(x: 0, y: (bounds.height - barThickness) / 2,
                         width: bounds.width, height: barThickness)
        let capsule = NSBezierPath(roundedRect: bar, xRadius: barThickness / 2, yRadius: barThickness / 2)
        NSColor.white.withAlphaComponent(isEnabled ? 0.24 : 0.12).setFill()
        capsule.fill()
        NSGraphicsContext.saveGraphicsState()
        capsule.addClip()
        let fraction = maxValue > 0 ? min(max(doubleValue / maxValue, 0), 1) : 0
        NSColor.white.withAlphaComponent(isEnabled ? 0.95 : 0.48).setFill()
        NSRect(x: bar.minX, y: bar.minY, width: bar.width * fraction, height: bar.height).fill()
        NSGraphicsContext.restoreGraphicsState()
    }

    override func mouseDown(with event: NSEvent) {
        guard isEnabled else { return }
        window?.makeFirstResponder(self)
        isDragging = true
        updatePosition(from: event)
        updateEmphasis()
    }
    override func mouseDragged(with event: NSEvent) {
        guard isEnabled, isDragging else { return }
        updatePosition(from: event)
    }
    override func mouseUp(with event: NSEvent) {
        guard isEnabled, isDragging else { return }
        updatePosition(from: event)
        isDragging = false
        updateEmphasis()
        onSeek(doubleValue)
    }
    private func updatePosition(from event: NSEvent) {
        guard bounds.width > 0 else { return }
        let x = convert(event.locationInWindow, from: nil).x
        doubleValue = min(max(Double(x / bounds.width), 0), 1) * maxValue
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isEnabled else { return }
        switch event.keyCode {
        case 123, 125: commit(doubleValue - 5)
        case 124, 126: commit(doubleValue + 5)
        default: super.keyDown(with: event)
        }
    }
    override func setAccessibilityValue(_ value: Any?) {
        guard isEnabled, let number = value as? NSNumber else { return }
        commit(number.doubleValue)
    }
    override func accessibilityPerformIncrement() -> Bool {
        guard isEnabled else { return false }; commit(doubleValue + 5); return true
    }
    override func accessibilityPerformDecrement() -> Bool {
        guard isEnabled else { return false }; commit(doubleValue - 5); return true
    }
    private func commit(_ value: Double) {
        guard value.isFinite else { return }
        doubleValue = min(max(value, 0), maxValue)
        needsDisplay = true
        onSeek(doubleValue)
    }
}
