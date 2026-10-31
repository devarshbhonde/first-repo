import CoreBluetooth
import Foundation

struct LogEntry: Identifiable, Codable {
    enum Direction: String, Codable {
        case rx      // scooter -> phone (notification or read result)
        case tx      // phone -> scooter (our write)
        case info    // connection and discovery events
        case marker  // a note the user added, e.g. "pressed LOCK in official app"

        var label: String {
            switch self {
            case .rx: return "RX"
            case .tx: return "TX"
            case .info: return "INFO"
            case .marker: return "MARK"
            }
        }
    }

    let id: UUID
    let time: Date
    let direction: Direction
    /// Short characteristic UUID ("FFE1"), or "" for info and marker entries.
    let characteristic: String
    let bytes: Data
    let note: String

    init(direction: Direction, characteristic: String = "", bytes: Data = Data(), note: String = "") {
        self.id = UUID()
        self.time = Date()
        self.direction = direction
        self.characteristic = characteristic
        self.bytes = bytes
        self.note = note
    }
}

struct DiscoveredPeripheral: Identifiable {
    let id: UUID
    let peripheral: CBPeripheral
    var name: String
    var rssi: Int
    var advertisedServices: [String]
    var manufacturerData: Data?
    var lastSeen: Date
}
