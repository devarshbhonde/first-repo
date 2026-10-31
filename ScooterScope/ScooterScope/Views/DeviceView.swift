import CoreBluetooth
import SwiftUI

/// Wraps a characteristic so it can drive `.sheet(item:)`.
struct WriteTarget: Identifiable {
    let id = UUID()
    let characteristic: CBCharacteristic
}

struct DeviceView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    let peripheral: CBPeripheral
    @State private var writeTarget: WriteTarget?
    @State private var showMarker = false

    private var isCurrent: Bool {
        bluetooth.connected?.identifier == peripheral.identifier
    }

    private var isLive: Bool {
        isCurrent && bluetooth.isConnected
    }

    var body: some View {
        List {
            Section("Connection") {
                LabeledContent("Status", value: isCurrent ? bluetooth.connectionStatus : "Not connected")
                if isCurrent {
                    Button("Disconnect", role: .destructive) { bluetooth.disconnect() }
                } else {
                    Button("Connect") { bluetooth.connect(peripheral) }
                }
                Button("Subscribe to all notifications") { bluetooth.subscribeAll() }
                    .disabled(!isLive)
                Button("Read all readable values") { bluetooth.readAllReadable() }
                    .disabled(!isLive)
            }
            if isCurrent {
                ForEach(bluetooth.services, id: \.uuid) { service in
                    Section {
                        ForEach(service.characteristics ?? [], id: \.uuid) { characteristic in
                            CharacteristicRow(characteristic: characteristic, enabled: isLive) {
                                writeTarget = WriteTarget(characteristic: characteristic)
                            }
                        }
                    } header: {
                        Text(serviceTitle(service))
                    }
                }
            }
        }
        .navigationTitle(bluetooth.displayName(peripheral))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showMarker = true
                } label: {
                    Label("Marker", systemImage: "flag")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    LogView()
                } label: {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
            }
        }
        .sheet(item: $writeTarget) { target in
            WriteSheet(characteristic: target.characteristic)
        }
        .sheet(isPresented: $showMarker) {
            MarkerSheet()
        }
        .onAppear {
            if !isCurrent { bluetooth.connect(peripheral) }
        }
    }

    private func serviceTitle(_ service: CBService) -> String {
        let known = KnownUUID.name(service.uuid).map { " (\($0))" } ?? ""
        return "Service \(service.uuid.uuidString)\(known)"
    }
}

private struct CharacteristicRow: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    let characteristic: CBCharacteristic
    let enabled: Bool
    let onWrite: () -> Void

    private var properties: CBCharacteristicProperties { characteristic.properties }
    private var canNotify: Bool { properties.contains(.notify) || properties.contains(.indicate) }
    private var canWrite: Bool { properties.contains(.write) || properties.contains(.writeWithoutResponse) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(characteristic.uuid.uuidString)
                    .font(.system(.body, design: .monospaced))
                if let known = KnownUUID.name(characteristic.uuid) {
                    Text(known)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(properties.labels.joined(separator: " · ") + (characteristic.isNotifying ? " · LISTENING" : ""))
                .font(.caption)
                .foregroundStyle(characteristic.isNotifying ? Color.green : Color.secondary)
            if let value = bluetooth.lastValues[characteristic.uuid.uuidString] {
                Text(value.isEmpty ? "(empty)" : value.hexString)
                    .font(.system(.caption, design: .monospaced))
            }
            HStack {
                if properties.contains(.read) {
                    Button("Read") { bluetooth.read(characteristic) }
                }
                if canNotify {
                    Button(characteristic.isNotifying ? "Unsubscribe" : "Subscribe") {
                        bluetooth.toggleNotify(characteristic)
                    }
                }
                if canWrite {
                    Button("Write", action: onWrite)
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(!enabled)
        }
        .padding(.vertical, 2)
    }
}
