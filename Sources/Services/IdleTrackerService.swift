import AppKit
import Combine

public final class IdleTrackerService: ObservableObject {
    public static let shared = IdleTrackerService()
    @Published public var idleThreshold: TimeInterval = UserDefaults.standard.object(forKey: "idleThreshold") as? Double ?? 0 {
        didSet { UserDefaults.standard.set(idleThreshold, forKey: "idleThreshold") }
    }
    @Published public private(set) var isStandByPresented = false
    private var timer: Timer?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var automatic = false
    private var subscriptions = Set<AnyCancellable>()
    public init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            guard let self, self.idleThreshold > 0, !self.isStandByPresented,
                  MusicPlayerService.shared.currentTrack?.isPlaying == true else { return }
            let idle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .init(rawValue: ~0)!)
            if idle >= self.idleThreshold { self.present(automatic: true) }
        }
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.sessionDidResignActiveNotification)
            .sink { [weak self] _ in self?.dismissStandBy() }.store(in: &subscriptions)
    }
    public func triggerStandByNow() { present(automatic: false) }
    private func present(automatic: Bool) {
        guard !isStandByPresented, !LockScreenService.shared.isLocked else { return }
        self.automatic = automatic; isStandByPresented = true
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .mouseMoved]) { [weak self] event in
            guard let self else { return event }
            if event.keyCode == 53 && event.type == .keyDown { self.dismissStandBy(); return nil }
            if self.automatic && event.type == .mouseMoved { self.dismissStandBy() }
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .keyDown, .mouseMoved]) { [weak self] event in
            if event.type != .mouseMoved || self?.automatic == true { self?.dismissStandBy() }
        }
        StandByWindowManager.shared.show()
    }
    public func dismissStandBy() {
        guard isStandByPresented else { return }
        isStandByPresented = false
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }; localMonitor = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }; globalMonitor = nil
        StandByWindowManager.shared.hide()
    }
}
