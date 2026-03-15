import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var exportError: String?

    private let exportService = ExportService()

    var body: some View {
        List {
            Section("Data") {
                Button {
                    exportData()
                } label: {
                    Label("Export Backup", systemImage: "square.and.arrow.up")
                }
                .disabled(isExporting)

                if isExporting {
                    ProgressView("Preparing export...")
                }

                if let error = exportError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("About") {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
        .sheet(item: $exportURL) { url in
            ShareSheet(activityItems: [url])
        }
    }

    private func exportData() {
        isExporting = true
        exportError = nil

        do {
            let data = try exportService.exportAll(context: context)
            let url = try exportService.exportFileURL(data: data)
            exportURL = url
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
