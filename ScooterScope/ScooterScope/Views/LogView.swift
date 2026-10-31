import SwiftUI
import UIKit

struct LogView: View {
    @EnvironmentObject private var bluetooth: BluetoothManager
    @State private var showASCII = false
    @State private var share: ShareItems?
    @State private var exportError: String?
    @State private var showMarker = false

    var body: some View {
        List(bluetooth.log.reversed()) { entry in
            LogRow(entry: entry, showASCII: showASCII)
        }
        .listStyle(.plain)
        .navigationTitle("Log (\(bluetooth.log.count))")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Toggle("Show ASCII", isOn: $showASCII)
                    Button {
                        showMarker = true
                    } label: {
                        Label("Add marker", systemImage: "flag")
                    }
                    Button {
                        export()
                    } label: {
                        Label("Export .txt and .json", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        bluetooth.clearLog()
                    } label: {
                        Label("Clear log", systemImage: "trash")
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(item: $share) { items in
            ActivityView(items: items.urls)
        }
        .sheet(isPresented: $showMarker) {
            MarkerSheet()
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
    }

    private func export() {
        do {
            share = ShareItems(urls: try bluetooth.writeExportFiles())
        } catch {
            exportError = error.localizedDescription
        }
    }
}

private struct ShareItems: Identifiable {
    let id = UUID()
    let urls: [URL]
}

private struct LogRow: View {
    let entry: LogEntry
    let showASCII: Bool

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(Self.timeFormatter.string(from: entry.time))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Text(entry.direction.label)
                    .font(.caption2.bold())
                    .foregroundStyle(color)
                if !entry.characteristic.isEmpty {
                    Text(entry.characteristic)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
                if !entry.bytes.isEmpty {
                    Text("\(entry.bytes.count) B")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if !entry.bytes.isEmpty {
                Text(showASCII ? entry.bytes.asciiString : entry.bytes.hexString)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
            }
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(.footnote)
                    .foregroundStyle(entry.direction == .marker ? Color.primary : Color.secondary)
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(entry.direction == .marker ? Color.yellow.opacity(0.15) : nil)
    }

    private var color: Color {
        switch entry.direction {
        case .rx: return .blue
        case .tx: return .orange
        case .info: return .secondary
        case .marker: return .yellow
        }
    }
}

/// Minimal share sheet so the exported files can go to Files, AirDrop, Mail, or Messages.
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
