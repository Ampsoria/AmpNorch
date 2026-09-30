import CoreBluetooth
import AppKit
import Combine

final class AirPodsProximityService: NSObject, ObservableObject, CBCentralManagerDelegate {
    static let shared = AirPodsProximityService()
    @Published private(set) var status = "Bluetooth case detection is off"
    @Published var enabled = UserDefaults.standard.object(forKey: "airPodsCaseDetection") as? Bool ?? (CBManager.authorization == .allowedAlways) {
        didSet { UserDefaults.standard.set(enabled, forKey: "airPodsCaseDetection"); updateScanning() }
    }
    private var central: CBCentralManager?
    private var lidTracker = AirPodsLidTracker()
    private var subscriptions = Set<AnyCancellable>()
    private var awake = true
    override init() {
        super.init()
        let notifications = NSWorkspace.shared.notificationCenter
        notifications.publisher(for: NSWorkspace.willSleepNotification).sink { [weak self] _ in
            self?.awake = false; self?.updateScanning()
        }.store(in: &subscriptions)
        notifications.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in
            self?.awake = true; self?.updateScanning()
        }.store(in: &subscriptions)
        updateScanning()
    }
    private func updateScanning() {
        guard enabled && awake else { central?.stopScan(); status = enabled ? "Paused during sleep" : "Bluetooth case detection is off"; return }
        guard let central else {
            self.central = CBCentralManager(delegate: self, queue: .main, options: [CBCentralManagerOptionShowPowerAlertKey: false]); return
        }
        switch central.state {
        case .poweredOn:
            if !central.isScanning { central.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]) }
            status = "Listening for nearby AirPods cases"
        case .unauthorized: status = "Allow Bluetooth access in System Settings → Privacy & Security"
        case .poweredOff: status = "Bluetooth is off"
        case .unsupported: status = "Bluetooth LE is unavailable"
        default: status = "Waiting for Bluetooth…"
        }
    }
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        updateScanning()
        AirPodsService.shared.startIfAuthorized()
    }
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        guard enabled, let bytes = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data,
              let packet = AirPodsAdvertisement(manufacturerData: bytes),
              lidTracker.observe(id: peripheral.identifier, packet: packet, rssi: RSSI.intValue) else { return }
        // Proximity does not prove ownership or a Classic Bluetooth connection.
        // Preserve a newer, confirmed connection card if the radios report in reverse order.
        guard NotchPresentationService.shared.activity?.kind != .headphones else { return }
        NotchPresentationService.shared.present(NotchActivity(kind: .airPodsCase,
            title: packet.modelName + " · Case open", subtitle: packet.batterySummary, symbol: packet.symbol), duration: 5)
    }
}
