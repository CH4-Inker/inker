import Foundation
import CoreBluetooth
import Combine

/// BLE control link to the ESP32. Separate from the A2DP audio link (that one
/// is system-managed once paired in Settings) — this is an app-managed BLE
/// GATT connection used only to send short `$...#` command frames when the
/// user controls playback.
///
/// The watch is the BLE central; the ESP32 advertises `serviceUUID` with a
/// single writable characteristic. Sends are fire-and-forget (write without
/// response); if not connected, they're dropped.
@MainActor
final class ESP32Link: NSObject, ObservableObject {

    static let shared = ESP32Link()

    // Must match the UUIDs in the ESP32 firmware.
    static let serviceUUID        = CBUUID(string: "0000A100-0000-1000-8000-00805F9B34FB")
    static let characteristicUUID = CBUUID(string: "0000A101-0000-1000-8000-00805F9B34FB")

    @Published private(set) var isConnected = false

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeChar: CBCharacteristic?

    private func log(_ m: String) { print("📡 [ESP32Link] \(m)") }

    private override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    /// Wrap a payload as `$payload#` and write it to the ESP32.
    func send(_ payload: String) {
        guard let peripheral, let writeChar, isConnected else {
            log("drop '\(payload)' (not connected)")
            return
        }
        let frame = "$\(payload)#"
        guard let data = frame.data(using: .utf8) else { return }
        peripheral.writeValue(data, for: writeChar, type: .withoutResponse)
        log("sent \(frame)")
    }

    private func startScan() {
        guard central.state == .poweredOn else { return }
        log("scanning for service \(Self.serviceUUID)")
        central.scanForPeripherals(withServices: [Self.serviceUUID])
    }
}

// MARK: - CBCentralManagerDelegate
extension ESP32Link: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn: self.startScan()
            default:
                self.isConnected = false
                self.log("central state \(central.state.rawValue)")
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDiscover peripheral: CBPeripheral,
                                    advertisementData: [String: Any],
                                    rssi RSSI: NSNumber) {
        Task { @MainActor in
            self.log("found peripheral, connecting")
            self.central.stopScan()
            self.peripheral = peripheral
            peripheral.delegate = self
            self.central.connect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.log("connected, discovering services")
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didDisconnectPeripheral peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in
            self.isConnected = false
            self.writeChar = nil
            self.log("disconnected, rescanning")
            self.startScan()
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager,
                                    didFailToConnect peripheral: CBPeripheral,
                                    error: Error?) {
        Task { @MainActor in self.startScan() }
    }
}

// MARK: - CBPeripheralDelegate
extension ESP32Link: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else { return }
            peripheral.discoverCharacteristics([Self.characteristicUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral,
                                didDiscoverCharacteristicsFor service: CBService,
                                error: Error?) {
        Task { @MainActor in
            guard let char = service.characteristics?.first(where: { $0.uuid == Self.characteristicUUID }) else { return }
            self.writeChar = char
            self.isConnected = true
            self.log("ready — characteristic found")
        }
    }
}
