import AppKit
import Foundation

@main
struct NotchBehaviorTests {
    static func main() {
        var tracker = ConnectionTracker()
        tracker.seed(["existing"])
        precondition(!tracker.connect("existing"), "Startup must not announce an already-connected device")
        precondition(tracker.connect("new"), "First connection should announce")
        precondition(!tracker.connect("new"), "Duplicate callback must not announce twice")
        tracker.disconnect("new")
        precondition(tracker.connect("new"), "Reconnect must announce again")
        tracker.disconnect("existing")
        precondition(tracker.connected == ["new"], "Disconnect one device without clearing another")

        for screen in [CGRect(x: 0, y: 0, width: 1512, height: 982),
                       CGRect(x: -1920, y: 240, width: 1920, height: 1080)] {
            let compact = NotchGeometry.frame(screen: screen, notchWidth: 210, notchHeight: 32,
                                              expanded: false, activity: nil)
            let expanded = NotchGeometry.frame(screen: screen, notchWidth: 210, notchHeight: 32,
                                               expanded: true, activity: nil)
            let activity = NotchGeometry.frame(screen: screen, notchWidth: 210, notchHeight: 32,
                                               expanded: false, activity: .headphones)
            for frame in [compact, expanded, activity] {
                precondition(frame.midX == screen.midX && frame.maxY == screen.maxY,
                             "All states must anchor to the target display, including nonzero origins")
            }
            precondition(compact.width - 210 == 92, "Both wings must clear the entire hardware notch")
            precondition(activity.height >= 32 + 40, "Headphones row must fit below the camera")
            precondition(expanded.height > activity.height)
            let caseNotice = NotchGeometry.frame(screen: screen, notchWidth: 210, notchHeight: 32,
                expanded: true, activity: .airPodsCase)
            precondition(caseNotice == compact, "Case opening must use the album artwork slot, even if music was expanded")
            let caseDetails = NotchGeometry.frame(screen: screen, notchWidth: 210, notchHeight: 32,
                expanded: true, activity: .airPodsCase, activityExpanded: true)
            precondition(caseDetails.maxY == screen.maxY && caseDetails.height > caseNotice.height,
                "Only explicitly opened case details may extend below the compact notch")
        }
        let notchless = NotchGeometry.frame(screen: CGRect(x: 0, y: 0, width: 1920, height: 1080),
            notchWidth: 100, notchHeight: 0, expanded: false, activity: nil)
        precondition(notchless.height == 32)

        for symbol in ["airpods", "airpodspro", "airpodsmax", "headphones"] {
            precondition(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil,
                         "Missing headphone symbol: \(symbol)")
        }

        let state = NotchPresentationService.shared
        let first = NotchActivity(kind: .headphones, title: "First", subtitle: "Connected", symbol: "airpods")
        let second = NotchActivity(kind: .headphones, title: "Second", subtitle: "Connected", symbol: "airpodspro")
        state.present(first, duration: 0.02)
        state.isActivityExpanded = true
        state.present(second, duration: 0.15)
        precondition(!state.isActivityExpanded, "A new event must not inherit expanded case details")
        RunLoop.main.run(until: Date().addingTimeInterval(0.06))
        precondition(state.activity?.id == second.id, "An old timeout must not dismiss a new event")
        RunLoop.main.run(until: Date().addingTimeInterval(0.16))
        precondition(state.activity == nil, "Banner must dismiss automatically")
        state.present(first, duration: 0.02)
        state.dismissActivity()
        RunLoop.main.run(until: Date().addingTimeInterval(0.04))
        precondition(state.activity == nil, "Manual dismissal must cancel the timer")
        print("PASS: connection deduplication, reconnect, multi-device isolation, display geometry, SF Symbols, event replacement and dismissal")
    }
}
