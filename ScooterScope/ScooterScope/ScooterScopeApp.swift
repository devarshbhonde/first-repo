import SwiftUI

@main
struct ScooterScopeApp: App {
    @StateObject private var bluetooth = BluetoothManager()

    var body: some Scene {
        WindowGroup {
            ScannerView()
                .environmentObject(bluetooth)
        }
    }
}
