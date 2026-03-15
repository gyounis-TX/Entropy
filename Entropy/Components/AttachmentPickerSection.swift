import SwiftUI
import PhotosUI
import SwiftData

/// A reusable section for viewing and adding attachments to any entity.
struct AttachmentPickerSection: View {
    let attachments: [Attachment]
    let onAdd: (Attachment) -> Void
    let onDelete: (Attachment) -> Void

    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        Section("Attachments") {
            if !attachments.isEmpty {
                AttachmentViewer(attachments: attachments, onDelete: onDelete)
            }

            PhotosPicker(selection: $selectedPhoto, matching: .any(of: [.images, .screenshots])) {
                Label("Add Photo", systemImage: "photo.badge.plus")
            }
            .onChange(of: selectedPhoto) {
                guard let item = selectedPhoto else { return }
                Task {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        let attachment = Attachment(
                            fileName: "Photo \(Date().formatted(date: .abbreviated, time: .shortened))",
                            data: data,
                            mimeType: "image/jpeg"
                        )
                        onAdd(attachment)
                    }
                    selectedPhoto = nil
                }
            }
        }
    }
}
