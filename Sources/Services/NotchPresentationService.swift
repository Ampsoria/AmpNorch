import AppKit
import Combine

final class NotchPresentationService: ObservableObject {
    static let shared = NotchPresentationService()
    @Published var isExpanded = false
    @Published var isActivityExpanded = false
    @Published private(set) var activity: NotchActivity?
    @Published var notchWidth: CGFloat = 185
    @Published var notchHeight: CGFloat = 32
    @Published var glassStyle = NotchGlassStyle(rawValue: UserDefaults.standard.string(forKey: "notchGlassStyle") ?? "clear") ?? .clear {
        didSet { UserDefaults.standard.set(glassStyle.rawValue, forKey: "notchGlassStyle") }
    }
    private var dismissal: DispatchWorkItem?

    func present(_ activity: NotchActivity, duration: TimeInterval = 4) {
        dismissal?.cancel()
        isActivityExpanded = false
        self.activity = activity
        let id = activity.id
        let task = DispatchWorkItem { [weak self] in
            guard self?.activity?.id == id else { return }
            self?.activity = nil
            self?.isActivityExpanded = false
        }
        dismissal = task
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: task)
    }

    func dismissActivity() {
        dismissal?.cancel()
        activity = nil
        isActivityExpanded = false
    }

}
