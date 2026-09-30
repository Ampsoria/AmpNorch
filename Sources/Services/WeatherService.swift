import Foundation
import Combine

struct WeatherCity: Identifiable {
    let id: String
    let latitude: Double
    let longitude: Double
    static let choices = [WeatherCity(id: "Bangkok", latitude: 13.7563, longitude: 100.5018),
        WeatherCity(id: "Chiang Mai", latitude: 18.7883, longitude: 98.9853),
        WeatherCity(id: "Phuket", latitude: 7.8804, longitude: 98.3923),
        WeatherCity(id: "Tokyo", latitude: 35.6762, longitude: 139.6503),
        WeatherCity(id: "London", latitude: 51.5072, longitude: -0.1276),
        WeatherCity(id: "New York", latitude: 40.7128, longitude: -74.006)]
}
public struct WeatherInfo: Equatable {
    public var temperature: Int?
    public var condition: String
    public var symbolName: String
    public var city: String
}
public final class WeatherService: ObservableObject {
    public static let shared = WeatherService()
    @Published public private(set) var currentWeather = WeatherInfo(temperature: nil, condition: "Loading weather…", symbolName: "cloud", city: "Bangkok")
    @Published var city = UserDefaults.standard.string(forKey: "weatherCity") ?? "Bangkok" {
        didSet { UserDefaults.standard.set(city, forKey: "weatherCity"); fetchWeather() }
    }
    private var timer: Timer?
    private var request: URLSessionDataTask?
    public init() {
        fetchWeather()
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in self?.fetchWeather() }
        timer?.tolerance = 30
    }
    public func fetchWeather() {
        request?.cancel()
        guard let choice = WeatherCity.choices.first(where: { $0.id == city }) else { return }
        currentWeather = WeatherInfo(temperature: nil, condition: "Loading weather…", symbolName: "cloud", city: city)
        let url = URL(string: "https://api.open-meteo.com/v1/forecast?latitude=\(choice.latitude)&longitude=\(choice.longitude)&current_weather=true")!
        request = URLSession.shared.dataTask(with: URLRequest(url: url, timeoutInterval: 10)) { [weak self] data, response, _ in
            var result = WeatherInfo(temperature: nil, condition: "Weather unavailable", symbolName: "cloud", city: choice.id)
            if (response as? HTTPURLResponse)?.statusCode == 200, let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let current = json["current_weather"] as? [String: Any],
               let temp = current["temperature"] as? Double, temp.isFinite, let code = current["weathercode"] as? Int {
                result.temperature = Int(round(temp))
                let night = (current["is_day"] as? Int) == 0
                switch code {
                case 0: result.condition = "Clear"; result.symbolName = night ? "moon.stars.fill" : "sun.max.fill"
                case 1,2: result.condition = "Partly cloudy"; result.symbolName = night ? "cloud.moon.fill" : "cloud.sun.fill"
                case 3: result.condition = "Overcast"; result.symbolName = "cloud.fill"
                case 45,48: result.condition = "Fog"; result.symbolName = "cloud.fog.fill"
                case 51...67,80...82: result.condition = "Rain"; result.symbolName = "cloud.rain.fill"
                case 71...77,85,86: result.condition = "Snow"; result.symbolName = "cloud.snow.fill"
                case 95...99: result.condition = "Thunderstorm"; result.symbolName = "cloud.bolt.rain.fill"
                default: result.condition = "Weather"; result.symbolName = "cloud"
                }
            }
            DispatchQueue.main.async { if self?.city == choice.id { self?.currentWeather = result } }
        }
        request?.resume()
    }
}
