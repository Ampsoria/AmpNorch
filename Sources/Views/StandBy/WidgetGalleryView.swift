import SwiftUI

public struct WidgetGalleryView: View {
    @ObservedObject var battery = BatteryService.shared
    @ObservedObject var weather = WeatherService.shared
    @ObservedObject var shazam = ShazamService.shared
    @ObservedObject var player = MusicPlayerService.shared
    
    @AppStorage("showBatteryWidget") public var showBattery: Bool = true
    @AppStorage("showWeatherWidget") public var showWeather: Bool = true
    @AppStorage("showCalendarWidget") public var showCalendar: Bool = true
    @AppStorage("showEqualizerWidget") public var showEqualizer: Bool = true
    @AppStorage("showShazamWidget") public var showShazam: Bool = true
    @State private var isCustomizing: Bool = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 8) {
            // Horizontal Bar of Active Lockscreen Widgets
            HStack(spacing: 12) {
                // Calendar Widget
                if showCalendar {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Text(currentDateShort())
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 20)
                }
                
                // Weather Widget
                if showWeather {
                    HStack(spacing: 6) {
                        Image(systemName: weather.currentWeather.symbolName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("\(weather.currentWeather.city) · \(weather.currentWeather.temperature.map { String($0) + "°" } ?? "—")")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 20)
                }
                
                // Battery Widget
                if showBattery {
                    HStack(spacing: 6) {
                        Image(systemName: battery.isCharging ? "battery.100.bolt" : "battery.100")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(battery.isCharging ? .green : .white.opacity(0.85))
                        Text("\(battery.batteryLevel)%")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 20)
                }
                
                // 6-Band Equalizer Widget
                if showEqualizer {
                    HStack(spacing: 6) {
                        Image(systemName: "waveform")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan)
                        Text(player.currentTrack?.isPlaying == true ? "Playing" : "Paused").font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .liquidGlass(cornerRadius: 20)
                }
                
                // Shazam Recognition Widget
                if showShazam {
                    Button(action: {
                        shazam.toggleListening()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: shazam.isListening ? "waveform.badge.magnifyingglass" : "shazam.logo.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(shazam.isListening ? .cyan : .blue)
                            Text(shazam.isListening ? "Listening..." : (shazam.matchResult ?? "Shazam"))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .liquidGlass(cornerRadius: 20)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // Customize Widget Gallery Button
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isCustomizing.toggle()
                    }
                }) {
                    Image(systemName: isCustomizing ? "xmark" : "slider.horizontal.3")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(6)
                        .background(Circle().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(PlainButtonStyle())
                .help("Lock Widget Gallery Settings")
            }
            
            // Customization Drawer
            if isCustomizing {
                HStack(spacing: 16) {
                    Toggle("📅 Date", isOn: $showCalendar)
                    Toggle("☀️ Weather", isOn: $showWeather)
                    Toggle("🔋 Battery", isOn: $showBattery)
                    Toggle("🎚️ Playback", isOn: $showEqualizer)
                    Toggle("🎙️ Shazam", isOn: $showShazam)
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .liquidGlass(cornerRadius: 12)
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private func currentDateShort() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, d MMM"
        return formatter.string(from: Date())
    }
}
