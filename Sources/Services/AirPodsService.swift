import Foundation
import IOBluetooth
import CoreBluetooth
import AppKit
import Combine

/// Connection events from macOS, not a simulated lid-open event or a BLE proximity guess.
final class AirPodsService: NSObject {
    static let shared = AirPodsService()
    private var connectionNotification: IOBluetoothUserNotification?
    private var disconnectionNotifications: [String: IOBluetoothUserNotification] = [:]
    private var tracker = ConnectionTracker()
    private var reconciliationTimer: Timer?
    private var activation: AnyCancellable?

    override init() {
        super.init()
        startIfAuthorized()
        activation = NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.startIfAuthorized() }
    }

    func startIfAuthorized() {
        guard CBManager.authorization == .allowedAlways, connectionNotification == nil else { return }
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        tracker.seed(Set(paired.filter { $0.isConnected() }.compactMap(\.addressString)))
        for device in paired where device.isConnected() { watchDisconnect(device) }
        connectionNotification = IOBluetoothDevice.register(forConnectNotifications: self,
                                                            selector: #selector(connected(_:device:)))
        // Reconcile missed callbacks after sleep/Bluetooth power changes. No active discovery.
        reconciliationTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.reconcile()
        }
        reconciliationTimer?.tolerance = 1
    }

    private func symbol(for device: IOBluetoothDevice) -> String? {
        let name = (device.name ?? "").lowercased()
        if name.contains("airpods") {
            return name.contains("max") ? "airpodsmax" : name.contains("pro") ? "airpodspro" : "airpods"
        }
        // Renamed headsets still receive a connection HUD without inventing their model.
        if device.deviceClassMajor == 4 && [1, 2, 6].contains(Int(device.deviceClassMinor)) {
            return "headphones"
        }
        return nil
    }

    @objc private func connected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.async { [weak self] in self?.handleConnection(device) }
    }

    private func handleConnection(_ device: IOBluetoothDevice) {
        guard device.isConnected(), let address = device.addressString else { return }
        watchDisconnect(device)
        guard tracker.connect(address), let symbol = symbol(for: device) else { return }
        NotchPresentationService.shared.present(NotchActivity(kind: .headphones,
            title: device.name ?? "Headphones", subtitle: "Connected", symbol: symbol))
    }

    private func watchDisconnect(_ device: IOBluetoothDevice) {
        guard let address = device.addressString, disconnectionNotifications[address] == nil else { return }
        disconnectionNotifications[address] = device.register(forDisconnectNotification: self,
                                                              selector: #selector(disconnected(_:device:)))
    }

    @objc private func disconnected(_ notification: IOBluetoothUserNotification, device: IOBluetoothDevice) {
        DispatchQueue.main.async { [weak self] in
            guard let self, let address = device.addressString else { return }
            self.tracker.disconnect(address)
            self.disconnectionNotifications.removeValue(forKey: address)?.unregister()
        }
    }

    private func reconcile() {
        let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] ?? []
        let addresses = Set(paired.filter { $0.isConnected() }.compactMap(\.addressString))
        for address in tracker.connected.subtracting(addresses) {
            tracker.disconnect(address)
            disconnectionNotifications.removeValue(forKey: address)?.unregister()
        }
        for device in paired where device.isConnected() { handleConnection(device) }
    }

    deinit {
        reconciliationTimer?.invalidate()
        connectionNotification?.unregister()
        disconnectionNotifications.values.forEach { $0.unregister() }
    }
}
