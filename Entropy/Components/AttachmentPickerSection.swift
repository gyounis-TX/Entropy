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
                        let mimeType = Self.detectImageMIMEType(from: data)
                        let attachment = Attachment(
                            fileName: "Photo \(Date().formatted(date: .abbreviated, time: .shortened))",
                            data: data,
                            mimeType: mimeType
                        )
                        onAdd(attachment)
                    }
                    selectedPhoto = nil
                }
            }
        }
    }

    /// Detect the image MIME type from the data header bytes.
    private static func detectImageMIMEType(from data: Data) -> String {
        guard data.count >= 12 else { return "image/jpeg" }

        let bytes = [UInt8](data.prefix(12))

        // JPEG: starts with FF D8
        if bytes[0] == 0xFF && bytes[1] == 0xD8 {
            return "image/jpeg"
        }

        // PNG: starts with 89 50 4E 47
        if bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 {
            return "image/png"
        }

        // HEIC: look for "ftyp" marker at offset 4
        if data.count >= 12 {
            let ftypRange = data[4..<8]
            if String(data: ftypRange, encoding: .ascii) == "ftyp" {
                return "image/heic"
            }
        }

        // GIF: starts with GIF8
        if bytes[0] == 0x47 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x38 {
            return "image/gif"
        }

        // WebP: starts with RIFF....WEBP
        if bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
           data.count >= 12 && bytes[8] == 0x57 && bytes[9] == 0x45 && bytes[10] == 0x42 && bytes[11] == 0x50 {
            return "image/webp"
        }

        return "image/jpeg"
    }
}
