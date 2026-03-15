import SwiftUI
import SwiftData

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var exportResult: IdentifiableURL?
    @State private var exportError: String?

    private let exportService = ExportService()

    var body: some View {
        List {
            Section("Data") {
                Button {
                    Task { await exportData() }
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
        .sheet(item: $exportResult) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    @MainActor
    private func exportData() async {
        isExporting = true
        exportError = nil

        do {
            let data = try exportService.exportAll(context: context)
            let url = try exportService.exportFileURL(data: data)
            exportResult = IdentifiableURL(url: url)
        } catch {
            exportError = error.localizedDescription
        }

        isExporting = false
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
