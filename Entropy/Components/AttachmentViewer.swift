import SwiftUI
import UIKit

/// Displays a list of attachments with thumbnails and allows viewing/removing.
struct AttachmentViewer: View {
    let attachments: [Attachment]
    var onDelete: ((Attachment) -> Void)?

    var body: some View {
        if attachments.isEmpty {
            Label("No attachments", systemImage: "paperclip")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(attachments) { attachment in
                        attachmentThumbnail(attachment)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentThumbnail(_ attachment: Attachment) -> some View {
        VStack(spacing: 4) {
            if attachment.mimeType.hasPrefix("image/"),
               let uiImage = UIImage(data: attachment.data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemFill))
                    .frame(width: 60, height: 60)
                    .overlay {
                        Image(systemName: iconForMimeType(attachment.mimeType))
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
            }

            Text(attachment.fileName)
                .font(.caption2)
                .lineLimit(1)
                .frame(width: 60)
        }
        .contextMenu {
            if let onDelete {
                Button("Remove", role: .destructive) {
                    onDelete(attachment)
                }
            }
        }
    }

    private func iconForMimeType(_ mime: String) -> String {
        if mime.hasPrefix("image/") { return "photo" }
        if mime == "application/pdf" { return "doc.fill" }
        return "doc"
    }
}
