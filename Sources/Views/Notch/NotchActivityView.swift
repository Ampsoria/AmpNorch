import SwiftUI

struct NotchActivityView: View {
    let activity: NotchActivity
    let notchHeight: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        switch activity.kind {
        case .capsLock:
            capsLockBanner
        case .volume, .charging:
            levelBanner
        case .headphones, .airPodsCase:
            headphonesBanner
        case .recognition:
            detailedBanner
        }
    }

    private var levelBanner: some View {
        Button {
            NotchPresentationService.shared.dismissActivity()
        } label: {
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: activity.symbol)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(activity.kind == .charging ? Color.green : .white)
                        .frame(width: 20)
                    Text(activity.title).font(.system(size: 12, weight: .semibold))
                    Spacer(minLength: 8)
                    Text(activity.subtitle)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.75))
                }
                .lineLimit(1)
                .frame(height: 24)
                GeometryReader { geometry in
                    Capsule().fill(.white.opacity(0.15))
                        .overlay(alignment: .leading) {
                            Capsule().fill(activity.kind == .charging ? Color.green : .white)
                                .frame(width: geometry.size.width * min(max(activity.progress ?? 0, 0), 1))
                        }
                }.frame(height: 4)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, notchHeight + 6)
        .padding(.bottom, 12)
        .accessibilityLabel("\(activity.title) \(activity.subtitle)")
        .accessibilityHint("Dismiss notification")
    }

    private var headphonesBanner: some View {
        let isCase = activity.kind == .airPodsCase
        let subtitle = isCase && !activity.subtitle.hasPrefix("Nearby")
            ? "Nearby · \(activity.subtitle)" : activity.subtitle
        return Button {
            NotchPresentationService.shared.dismissActivity()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: activity.symbol)
                    .font(.system(size: 26, weight: .medium))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(activity.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1).truncationMode(.middle)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if !isCase {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        }
                        Text(subtitle).lineLimit(isCase ? 2 : 1)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: isCase ? 52 : 40)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, notchHeight + 6)
        .padding(.bottom, 10)
        .help("\(activity.title) — \(subtitle)")
        .accessibilityLabel("\(activity.title) \(subtitle)")
        .accessibilityHint("Dismiss notification")
    }

    private var capsLockBanner: some View {
        Button {
            NotchPresentationService.shared.dismissActivity()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: activity.symbol)
                    .font(.system(size: 16, weight: .medium))
                    .frame(width: 20)
                Text(activity.title).font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                Text(activity.subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
            }
            .lineLimit(1)
            .frame(height: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, notchHeight + 6)
        .padding(.bottom, 6)
        .accessibilityLabel("\(activity.title) \(activity.subtitle)")
        .accessibilityHint("Dismiss notification")
    }

    private var detailedBanner: some View {
        HStack(spacing: 17) {
            Image(systemName: activity.symbol)
                .font(.system(size: (activity.kind == .headphones || activity.kind == .airPodsCase) ? 42 : 30, weight: .medium))
                .foregroundStyle(activity.kind == .charging ? Color.green : .white)
                .frame(width: 58, height: 60)
                .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                .rotationEffect(.degrees(appeared || reduceMotion ? 0 : -12))

            VStack(alignment: .leading, spacing: 5) {
                Text(activity.title).font(.system(size: 16, weight: .semibold)).lineLimit(1)
                HStack(spacing: 5) {
                    if activity.kind == .headphones {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    }
                    Text(activity.subtitle).lineLimit(2).minimumScaleFactor(0.85)
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                if let progress = activity.progress {
                    ProgressView(value: min(max(progress, 0), 1)).tint(.white)
                        .frame(width: 180)
                }
            }
            Spacer(minLength: 0)
            Button {
                NotchPresentationService.shared.dismissActivity()
            } label: {
                Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                    .frame(width: 24, height: 24)
                    .background(.white.opacity(0.1), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.top, notchHeight + 8)
        .padding(.bottom, 18)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.65)) {
                appeared = true
            }
        }
        .accessibilityElement(children: .combine)
    }
}
