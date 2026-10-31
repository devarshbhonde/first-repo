import CoreBluetooth
import SwiftUI

struct WriteSheet: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    let characteristic: CBCharacteristic
    @State private var hex = ""
    @State private var withResponse: Bool
    @State private var error: String?

    init(characteristic: CBCharacteristic) {
        self.characteristic = characteristic
        _withResponse = State(initialValue: characteristic.properties.contains(.write))
    }

    private var supportsBoth: Bool {
        characteristic.properties.contains(.write) && characteristic.properties.contains(.writeWithoutResponse)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Characteristic") {
                    Text(characteristic.uuid.uuidString)
                        .font(.system(.body, design: .monospaced))
                }
                Section("Bytes (hex)") {
                    TextField("55 AA 03 01 ...", text: $hex)
                        .font(.system(.body, design: .monospaced))
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    if let parsed = Data(hex: hex), !parsed.isEmpty {
                        Text("\(parsed.count) bytes: \(parsed.hexString)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let error {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
                Section {
                    Toggle("Write with response", isOn: $withResponse)
                        .disabled(!supportsBoth)
                }
                Section {
                    Text("Only send bytes you have seen the official app send, or that you understand from the decompiled app. Unknown writes can change scooter settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") { send() }
                        .disabled(hex.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func send() {
        guard let data = Data(hex: hex), !data.isEmpty else {
            error = "Not valid hex. Use pairs like 55 AA 03."
            return
        }
        bluetooth.write(data, to: characteristic, withResponse: withResponse)
        dismiss()
    }
}

struct MarkerSheet: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    private let presets = [
        "Official app: LOCK",
        "Official app: UNLOCK",
        "Official app: speed mode changed",
        "Official app: lights toggled",
        "Official app: cruise toggled",
        "Scooter: throttle pressed",
        "Scooter: brake pressed",
        "Scooter: standing still",
        "Scooter: headlight button",
        "Charger plugged in",
        "Charger unplugged"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Custom note") {
                    TextField("What just happened?", text: $note)
                    Button("Add marker") { add(note) }
                        .disabled(note.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                Section("Presets") {
                    ForEach(presets, id: \.self) { preset in
                        Button(preset) { add(preset) }
                    }
                }
            }
            .navigationTitle("Add marker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func add(_ text: String) {
        bluetooth.addMarker(text)
        dismiss()
    }
}
