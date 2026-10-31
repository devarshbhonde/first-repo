import Combine
import CoreBluetooth
import Foundation

/// Scans, connects, enumerates GATT, subscribes to notifications and records every byte.
/// CBCentralManager is created with queue nil, so every delegate callback arrives on the main queue
/// and the @Published properties are only ever touched from the main thread.
final class BluetoothManager: NSObject, ObservableObject {
    @Published private(set) var state: CBManagerState = .unknown
    @Published private(set) var isScanning = false
    @Published private(set) var peripherals: [DiscoveredPeripheral] = []
    @Published private(set) var connected: CBPeripheral?
    @Published private(set) var isConnected = false
    @Published private(set) var connectionStatus = "Disconnected"
    @Published private(set) var services: [CBService] = []
    @Published private(set) var lastValues: [String: Data] = [:]
    @Published private(set) var log: [LogEntry] = []
    @Published var autoReconnect = true

    private var central: CBCentralManager!
    private var wantsConnection = false
    private let maxLogEntries = 20_000
    private let rssiRefreshInterval: TimeInterval = 0.5

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil,
                                   options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    // MARK: Scanning

    func startScan() {
        guard central.state == .poweredOn else {
            append(.info, note: "Cannot scan, Bluetooth state is \(describe(central.state))")
            return
        }
        peripherals.removeAll()
        central.scanForPeripherals(withServices: nil,
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        isScanning = true
        append(.info, note: "Scan started")
    }

    func stopScan() {
        guard isScanning else { return }
        central.stopScan()
        isScanning = false
        append(.info, note: "Scan stopped")
    }

    // MARK: Connection

    func connect(_ peripheral: CBPeripheral) {
        stopScan()
        if let current = connected, current.identifier != peripheral.identifier {
            wantsConnection = false
            central.cancelPeripheralConnection(current)
        }
        wantsConnection = true
        connected = peripheral
        services = []
        lastValues = [:]
        peripheral.delegate = self
        connectionStatus = "Connecting"
        append(.info, note: "Connecting to \(displayName(peripheral))")
        central.connect(peripheral, options: nil)
    }

    func disconnect() {
        wantsConnection = false
        guard let current = connected else { return }
        append(.info, note: "Disconnect requested")
        central.cancelPeripheralConnection(current)
    }

    // MARK: GATT actions

    func read(_ characteristic: CBCharacteristic) {
        connected?.readValue(for: characteristic)
    }

    func toggleNotify(_ characteristic: CBCharacteristic) {
        connected?.setNotifyValue(!characteristic.isNotifying, for: characteristic)
    }

    /// The one-tap action for discovery: listen to everything the scooter can push.
    func subscribeAll() {
        guard let peripheral = connected else { return }
        var count = 0
        for service in services {
            for characteristic in service.characteristics ?? []
            where characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                peripheral.setNotifyValue(true, for: characteristic)
                count += 1
            }
        }
        append(.info, note: "Subscribing to \(count) notify/indicate characteristics")
    }

    func readAllReadable() {
        guard let peripheral = connected else { return }
        for service in services {
            for characteristic in service.characteristics ?? [] where characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        }
    }

    func write(_ data: Data, to characteristic: CBCharacteristic, withResponse: Bool) {
        guard let peripheral = connected else { return }
        let type: CBCharacteristicWriteType = withResponse ? .withResponse : .withoutResponse
        peripheral.writeValue(data, for: characteristic, type: type)
        append(.tx, characteristic: characteristic.uuid.uuidString, bytes: data,
               note: withResponse ? "write with response" : "write without response")
    }

    // MARK: Log

    func addMarker(_ note: String) {
        append(.marker, note: note)
    }

    func clearLog() {
        log.removeAll()
    }

    func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var lines = [
            "# ScooterScope log",
            "# device: \(connected.map(displayName) ?? "-") \(connected?.identifier.uuidString ?? "")",
            "# columns: time direction characteristic bytes note",
            ""
        ]
        for entry in log {
            let direction = entry.direction.label.padding(toLength: 5, withPad: " ", startingAt: 0)
            let characteristic = entry.characteristic.padding(toLength: 6, withPad: " ", startingAt: 0)
            lines.append("\(formatter.string(from: entry.time)) \(direction) \(characteristic) \(entry.bytes.hexString)  \(entry.note)")
        }
        return lines.joined(separator: "\n")
    }

    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(log)
    }

    /// Writes a .txt and a .json copy of the log to the temp directory and returns both URLs for sharing.
    func writeExportFiles() throws -> [URL] {
        let stamp = Self.fileStampFormatter.string(from: Date())
        let directory = FileManager.default.temporaryDirectory
        let textURL = directory.appendingPathComponent("scooterscope-\(stamp).txt")
        let jsonURL = directory.appendingPathComponent("scooterscope-\(stamp).json")
        try exportText().write(to: textURL, atomically: true, encoding: .utf8)
        try exportJSON().write(to: jsonURL, options: .atomic)
        return [textURL, jsonURL]
    }

    private static let fileStampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()

    // MARK: Helpers

    private func append(_ direction: LogEntry.Direction, characteristic: String = "",
                        bytes: Data = Data(), note: String = "") {
        log.append(LogEntry(direction: direction, characteristic: characteristic, bytes: bytes, note: note))
        if log.count > maxLogEntries {
            log.removeFirst(log.count - maxLogEntries)
        }
    }

    func displayName(_ peripheral: CBPeripheral) -> String {
        if let name = peripheral.name, !name.isEmpty { return name }
        if let found = peripherals.first(where: { $0.id == peripheral.identifier }), !found.name.isEmpty {
            return found.name
        }
        return String(peripheral.identifier.uuidString.prefix(8))
    }

    private func describe(_ state: CBManagerState) -> String {
        switch state {
        case .poweredOn: return "on"
        case .poweredOff: return "off"
        case .resetting: return "resetting"
        case .unauthorized: return "unauthorized"
        case .unsupported: return "unsupported"
        case .unknown: return "unknown"
        @unknown default: return "unknown"
        }
    }
}

// MARK: - CBCentralManagerDelegate

extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        state = central.state
        append(.info, note: "Bluetooth is \(describe(central.state))")
        if central.state != .poweredOn {
            isScanning = false
            isConnected = false
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any], rssi RSSI: NSNumber) {
        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        let name = advertisedName ?? peripheral.name ?? ""
        let serviceUUIDs = (advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? [])
            .map(\.uuidString)
        let manufacturer = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data
        let now = Date()

        if let index = peripherals.firstIndex(where: { $0.id == peripheral.identifier }) {
            guard now.timeIntervalSince(peripherals[index].lastSeen) >= rssiRefreshInterval else { return }
            peripherals[index].rssi = RSSI.intValue
            peripherals[index].lastSeen = now
            if !name.isEmpty { peripherals[index].name = name }
            if !serviceUUIDs.isEmpty { peripherals[index].advertisedServices = serviceUUIDs }
            if manufacturer != nil { peripherals[index].manufacturerData = manufacturer }
        } else {
            peripherals.append(DiscoveredPeripheral(id: peripheral.identifier, peripheral: peripheral,
                                                    name: name, rssi: RSSI.intValue,
                                                    advertisedServices: serviceUUIDs,
                                                    manufacturerData: manufacturer, lastSeen: now))
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        isConnected = true
        connectionStatus = "Connected, discovering services"
        append(.info, note: "Connected to \(displayName(peripheral))")
        peripheral.discoverServices(nil)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        connectionStatus = "Failed: \(error?.localizedDescription ?? "unknown error")"
        append(.info, note: "Connection failed: \(error?.localizedDescription ?? "unknown error")")
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        isConnected = false
        services = []
        connectionStatus = "Disconnected"
        append(.info, note: "Disconnected \(error.map { "(\($0.localizedDescription))" } ?? "")")
        let isCurrent = peripheral.identifier == connected?.identifier
        if isCurrent && wantsConnection && autoReconnect {
            connectionStatus = "Reconnecting"
            append(.info, note: "Auto reconnecting")
            central.connect(peripheral, options: nil)
        } else if isCurrent {
            wantsConnection = false
        }
    }
}

// MARK: - CBPeripheralDelegate

extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error {
            append(.info, note: "Service discovery failed: \(error.localizedDescription)")
            return
        }
        services = peripheral.services ?? []
        connectionStatus = "Connected, \(services.count) services"
        for service in services {
            append(.info, note: "Service \(service.uuid.uuidString) \(KnownUUID.name(service.uuid) ?? "")")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error {
            append(.info, note: "Characteristic discovery failed for \(service.uuid.uuidString): \(error.localizedDescription)")
            return
        }
        for characteristic in service.characteristics ?? [] {
            let props = characteristic.properties.labels.joined(separator: ",")
            append(.info, characteristic: characteristic.uuid.uuidString,
                   note: "Characteristic in \(service.uuid.uuidString) [\(props)] \(KnownUUID.name(characteristic.uuid) ?? "")")
        }
        // Reassign so SwiftUI re-reads the characteristic lists.
        services = peripheral.services ?? []
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            append(.info, characteristic: characteristic.uuid.uuidString,
                   note: "Read/notify error: \(error.localizedDescription)")
            return
        }
        let data = characteristic.value ?? Data()
        lastValues[characteristic.uuid.uuidString] = data
        append(.rx, characteristic: characteristic.uuid.uuidString, bytes: data,
               note: characteristic.isNotifying ? "" : "read")
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            append(.info, characteristic: characteristic.uuid.uuidString,
                   note: "Notify change failed: \(error.localizedDescription)")
        } else {
            append(.info, characteristic: characteristic.uuid.uuidString,
                   note: characteristic.isNotifying ? "Subscribed" : "Unsubscribed")
        }
        services = peripheral.services ?? []
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error {
            append(.info, characteristic: characteristic.uuid.uuidString,
                   note: "Write failed: \(error.localizedDescription)")
        } else {
            append(.info, characteristic: characteristic.uuid.uuidString, note: "Write acknowledged")
        }
    }
}
