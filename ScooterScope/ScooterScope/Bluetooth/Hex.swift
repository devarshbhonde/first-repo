import CoreBluetooth
import Foundation

extension Data {
    /// "55 AA 03 01" style, upper case, space separated.
    var hexString: String {
        map { String(format: "%02X", $0) }.joined(separator: " ")
    }

    /// Printable ASCII with a dot for anything else.
    var asciiString: String {
        String(map { (32...126).contains($0) ? Character(UnicodeScalar($0)) : "." })
    }

    /// Accepts "55AA03", "55 aa 03", "0x55,0xAA", "55:AA:03". Returns nil on a bad digit or odd length.
    init?(hex: String) {
        let cleaned = hex
            .replacingOccurrences(of: "0x", with: "", options: .caseInsensitive)
            .filter { !$0.isWhitespace && $0 != "," && $0 != ":" }
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else { return nil }
            bytes.append(byte)
            index = next
        }
        self.init(bytes)
    }
}

extension CBCharacteristicProperties {
    var labels: [String] {
        var result: [String] = []
        if contains(.read) { result.append("read") }
        if contains(.write) { result.append("write") }
        if contains(.writeWithoutResponse) { result.append("writeNoRsp") }
        if contains(.notify) { result.append("notify") }
        if contains(.indicate) { result.append("indicate") }
        if contains(.broadcast) { result.append("broadcast") }
        if contains(.authenticatedSignedWrites) { result.append("signed") }
        if contains(.extendedProperties) { result.append("ext") }
        return result
    }
}

/// Friendly names for UUIDs that cheap scooter controllers tend to use.
enum KnownUUID {
    static func name(_ uuid: CBUUID) -> String? {
        switch uuid.uuidString.uppercased() {
        case "FFE0": return "HM-10 style UART service"
        case "FFE1": return "HM-10 style UART data"
        case "FFF0": return "Common vendor service"
        case "FFF1", "FFF2", "FFF3", "FFF4", "FFF5": return "Common vendor characteristic"
        case "FEE7": return "WeChat / common Chinese vendor service"
        case "6E400001-B5A3-F393-E0A9-E50E24DCCA9E": return "Nordic UART service"
        case "6E400002-B5A3-F393-E0A9-E50E24DCCA9E": return "Nordic UART RX (write to scooter)"
        case "6E400003-B5A3-F393-E0A9-E50E24DCCA9E": return "Nordic UART TX (notify from scooter)"
        case "180A": return "Device Information"
        case "180F": return "Battery Service"
        case "2A19": return "Battery Level"
        case "2A29": return "Manufacturer Name"
        case "2A24": return "Model Number"
        case "2A25": return "Serial Number"
        case "2A26": return "Firmware Revision"
        case "2A27": return "Hardware Revision"
        case "2A28": return "Software Revision"
        default: return nil
        }
    }
}
