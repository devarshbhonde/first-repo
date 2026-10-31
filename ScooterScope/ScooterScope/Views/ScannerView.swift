import CoreBluetooth
import SwiftUI

struct ScannerView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @State private var filter = ""

    private var filtered: [DiscoveredPeripheral] {
        let list = filter.isEmpty
            ? bluetooth.peripherals
            : bluetooth.peripherals.filter { $0.name.localizedCaseInsensitiveContains(filter) }
        return list.sorted { $0.rssi > $1.rssi }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Bluetooth", value: stateText)
                    Toggle("Auto reconnect", isOn: $bluetooth.autoReconnect)
                    if let connected = bluetooth.connected {
                        NavigationLink {
                            DeviceView(peripheral: connected)
                        } label: {
                            LabeledContent("Current device", value: bluetooth.displayName(connected))
                        }
                    }
                }
                Section("Nearby devices (\(filtered.count))") {
                    if filtered.isEmpty {
                        Text(bluetooth.isScanning ? "Listening for advertisements" : "Tap Scan, then turn the scooter on.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(filtered) { device in
                        NavigationLink {
                            DeviceView(peripheral: device.peripheral)
                        } label: {
                            PeripheralRow(device: device)
                        }
                    }
                }
            }
            .searchable(text: $filter, prompt: "Filter by name")
            .navigationTitle("ScooterScope")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        LogView()
                    } label: {
                        Label("Log", systemImage: "list.bullet.rectangle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(bluetooth.isScanning ? "Stop" : "Scan") {
                        if bluetooth.isScanning { bluetooth.stopScan() } else { bluetooth.startScan() }
                    }
                    .disabled(bluetooth.state != .poweredOn)
                }
            }
        }
    }

    private var stateText: String {
        switch bluetooth.state {
        case .poweredOn: return bluetooth.isScanning ? "Scanning" : "Ready"
        case .poweredOff: return "Off"
        case .unauthorized: return "Not authorized (check Settings)"
        case .unsupported: return "Unsupported"
        case .resetting: return "Resetting"
        case .unknown: return "Starting"
        @unknown default: return "Unknown"
        }
    }
}

private struct PeripheralRow: View {
    let device: DiscoveredPeripheral

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(device.name.isEmpty ? "(no name)" : device.name)
                    .font(.headline)
                Spacer()
                Text("\(device.rssi) dBm")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(signalColor)
            }
            Text(device.id.uuidString)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
            if !device.advertisedServices.isEmpty {
                Text("Services: " + device.advertisedServices.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let manufacturer = device.manufacturerData, !manufacturer.isEmpty {
                Text("Mfr: " + manufacturer.hexString)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var signalColor: Color {
        if device.rssi > -60 { return .green }
        if device.rssi > -80 { return .orange }
        return .red
    }
}
