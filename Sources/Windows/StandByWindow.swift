import SwiftUI
import AppKit

public class StandByWindowManager: ObservableObject {
    public static let shared = StandByWindowManager()
    
    private var window: NSPanel?
    
    public init() {}
    
    public func show() {
        guard let screen = NSScreen.main else { return }
        
        if window == nil {
            let panel = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.alphaValue = 0.0
            
            let hosting = NSHostingView(rootView: StandByFullscreenView())
            hosting.frame = screen.frame
            hosting.autoresizingMask = [.width, .height]
            panel.contentView = hosting
            
            self.window = panel
        }
        
        guard let panel = self.window else { return }
        panel.setFrame(screen.frame, display: true)
        panel.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.4
            panel.animator().alphaValue = 1.0
        }
    }
    
    public func hide() {
        guard let panel = self.window else { return }
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.25
            panel.animator().alphaValue = 0.0
        }, completionHandler: {
            panel.orderOut(nil)
        })
    }
}
