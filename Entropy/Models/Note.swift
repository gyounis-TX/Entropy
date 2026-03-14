import Foundation
import SwiftData

@Model
final class NoteCategory {
    var id: UUID
    var name: String
    var icon: String?
    var color: String?
    var sortOrder: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Note.category)
    var notes: [Note]

    init(name: String, icon: String? = nil, color: String? = nil, sortOrder: Int = 0) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.color = color
        self.sortOrder = sortOrder
        self.createdAt = Date()
        self.notes = []
    }

    var noteCount: Int { notes.count }

    static var defaultCategories: [NoteCategory] {
        [
            NoteCategory(name: "Work", icon: "briefcase.fill", color: "blue", sortOrder: 0),
            NoteCategory(name: "Tilbury", icon: "building.2.fill", color: "green", sortOrder: 1),
            NoteCategory(name: "Laguna", icon: "house.fill", color: "orange", sortOrder: 2)
        ]
    }
}

@Model
final class Note {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var tags: [String]

    @Relationship var category: NoteCategory?
    @Relationship(deleteRule: .cascade, inverse: \Attachment.note)
    var attachments: [Attachment]
    @Relationship(deleteRule: .cascade, inverse: \Reminder.note)
    var reminders: [Reminder]

    init(title: String, body: String = "", isPinned: Bool = false) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = isPinned
        self.tags = []
        self.attachments = []
        self.reminders = []
    }
}
