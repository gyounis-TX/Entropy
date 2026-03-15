import Foundation
import SwiftData

@Model
final class Attachment {
    var id: UUID
    var fileName: String
    @Attribute(.externalStorage) var data: Data
    var mimeType: String
    var createdAt: Date

    @Relationship var flight: Flight?
    @Relationship var accommodation: Accommodation?
    @Relationship var note: Note?
    @Relationship var trip: Trip?

    init(fileName: String, data: Data, mimeType: String) {
        self.id = UUID()
        self.fileName = fileName
        self.data = data
        self.mimeType = mimeType
        self.createdAt = Date()
    }

    var isImage: Bool {
        mimeType.hasPrefix("image/")
    }

    var isPDF: Bool {
        mimeType == "application/pdf"
    }
}
