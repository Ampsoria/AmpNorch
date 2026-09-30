import AppKit
import Combine

final class LockScreenService: ObservableObject {
    static let shared = LockScreenService()
    @Published var enabled = UserDefaults.standard.object(forKey: "lockScreenMusicEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "lockScreenMusicEnabled"); reconcile() }
    }
    @Published private(set) var isLocked = false
    @Published private(set) var status = "Ready for the next screen lock (experimental)."
    private let windows = LockScreenWindowManager()
    private var subscriptions = Set<AnyCancellable>()
    private var displayAwake = true
    private var generation = 0

    init() {
        let distributed = DistributedNotificationCenter.default()
        distributed.publisher(for: .init("com.apple.screenIsLocked"))
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.refreshAfterTransition() }
            .store(in: &subscriptions)
        distributed.publisher(for: .init("com.apple.screenIsUnlocked"))
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                guard let self else { return }
                self.generation += 1; self.isLocked = false; self.windows.hide()
                self.status = self.enabled ? "Ready for the next screen lock (experimental)." : "Off"
            }.store(in: &subscriptions)
        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            workspace.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.displayAwake = false; self?.generation += 1; self?.windows.hide()
            }.store(in: &subscriptions)
        }
        workspace.publisher(for: NSWorkspace.screensDidWakeNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.displayAwake = true; self?.refreshAfterTransition()
            }.store(in: &subscriptions)
        for name in [NSWorkspace.sessionDidResignActiveNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            workspace.publisher(for: name).receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.windows.hide(); self?.refreshAfterTransition()
            }.store(in: &subscriptions)
        }
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main).sink { [weak self] _ in
                self?.windows.hide(); self?.reconcile()
            }.store(in: &subscriptions)
        MusicPlayerService.shared.$currentTrack.map { $0 != nil }.removeDuplicates()
            .receive(on: DispatchQueue.main).sink { [weak self] _ in self?.reconcile() }
            .store(in: &subscriptions)
        reconcile()
    }

    private func refreshAfterTransition() {
        generation += 1
        let expected = generation
        // Session dictionaries can lag the notification briefly. Bounded retries,
        // not a new polling loop; never show based on a notification alone.
        for delay in [0.0, 0.2, 0.7] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.generation == expected else { return }
                self.reconcile()
            }
        }
    }

    private func reconcile() {
        let session = CGSessionCopyCurrentDictionary() as? [String: Any] ?? [:]
        isLocked = session["CGSSessionScreenIsLocked"] as? Bool == true
        let state = LockScreenVisibility(enabled: enabled, locked: isLocked,
            onConsole: session[kCGSessionOnConsoleKey as String] as? Bool == true,
            displayAwake: displayAwake, hasTrack: MusicPlayerService.shared.currentTrack != nil)
        guard state.shouldPresent else {
            windows.hide()
            status = !enabled ? "Off" : isLocked ? "Waiting for music or an active display." : "Ready for the next screen lock (experimental)."
            return
        }
        IdleTrackerService.shared.dismissStandBy()
        status = windows.show() ? "Lock Screen music panels are active." : "Lock Screen overlay unavailable on this system."
    }

    func stop() {
        generation += 1; subscriptions.removeAll(); windows.hide()
    }
}
