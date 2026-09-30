import Foundation
import IOKit.ps
import Combine

public class BatteryService: ObservableObject {
    public static let shared = BatteryService()
    
    @Published public var batteryLevel: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var timeRemaining: String = ""
    
    private var timer: Timer?
    
    public init() {
        updateBatteryInfo()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
        }
    }
    
    public func updateBatteryInfo() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return
        }
        
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
                continue
            }
            guard description[kIOPSTypeKey as String] as? String == kIOPSInternalBatteryType else { continue }
            
            if let current = description[kIOPSCurrentCapacityKey as String] as? Int,
               let max = description[kIOPSMaxCapacityKey as String] as? Int,
               max > 0 {
                let percentage = Int((Double(current) / Double(max)) * 100.0)
                let charging = description[kIOPSIsChargingKey as String] as? Bool ?? false
                
                DispatchQueue.main.async {
                    self.batteryLevel = percentage
                    self.isCharging = charging
                }
            }
        }
    }
}
