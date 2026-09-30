import SwiftUI
import AppKit

public struct NotchContainerView: View {
    @ObservedObject private var presentation = NotchPresentationService.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoverTask: DispatchWorkItem?
    @State private var isHovering = false

    public init() {}

    public var body: some View {
        Group {
            if let activity = presentation.activity {
                if activity.kind == .airPodsCase && !presentation.isActivityExpanded {
                    CompactAirPodsCaseView(activity: activity, notchWidth: presentation.notchWidth)
                        .id(activity.id)
                        .frame(height: max(32, presentation.notchHeight))
                        .transition(.opacity)
                } else {
                    NotchActivityView(activity: activity, notchHeight: presentation.notchHeight)
                        .id(activity.id)
                        .transition(.opacity.combined(with: .offset(y: reduceMotion ? 0 : -8)))
                }
            } else if presentation.isExpanded {
                ExpandedNotchView(notchHeight: presentation.notchHeight)
                    .transition(.opacity)
            } else {
                CompactNotchView(notchWidth: presentation.notchWidth)
                    .frame(height: max(32, presentation.notchHeight))
                    .contentShape(Rectangle())
                    .onTapGesture { presentation.isExpanded = true }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("Expand AmpNotch")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .preferredColorScheme(.dark)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.85), value: presentation.activity?.id)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.85), value: presentation.isExpanded)
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.85), value: presentation.isActivityExpanded)
        .onHover { hovering in
            isHovering = hovering
            hoverTask?.cancel()
            guard presentation.activity == nil else { return }
            let task = DispatchWorkItem {
                guard presentation.activity == nil else { return }
                presentation.isExpanded = hovering
            }
            hoverTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + (hovering ? 0.18 : 0.55), execute: task)
        }
        .onChange(of: presentation.activity?.id) { id in
            if id == nil && !isHovering {
                presentation.isExpanded = false
            }
        }
        .contextMenu {
            Button("Settings…") { SettingsWindowManager.shared.show() }
            Menu("Notch Appearance") {
                ForEach(NotchGlassStyle.allCases, id: \.rawValue) { style in
                    Button {
                        presentation.glassStyle = style
                    } label: {
                        if presentation.glassStyle == style { Label(style.title, systemImage: "checkmark") }
                        else { Text(style.title) }
                    }
                }
            }
            Button("Collapse") { presentation.isExpanded = false }
            Divider()
            Button("Quit AmpNotch") { NSApp.terminate(nil) }
        }
        .simultaneousGesture(DragGesture(minimumDistance: 28).onEnded { gesture in
            guard gesture.startLocation.y <= max(32, presentation.notchHeight) + 8 else { return }
            if gesture.translation.height < -28 {
                presentation.dismissActivity()
                presentation.isExpanded = false
            } else if gesture.translation.height > 28 {
                if presentation.activity?.kind == .airPodsCase { presentation.isActivityExpanded = true }
                else { presentation.isExpanded = true }
            } else if abs(gesture.translation.width) > 50 && presentation.activity == nil {
                if gesture.translation.width < 0 { MusicPlayerService.shared.nextTrack() }
                else { MusicPlayerService.shared.previousTrack() }
            }
        })
        .onDisappear { hoverTask?.cancel() }
    }
}
