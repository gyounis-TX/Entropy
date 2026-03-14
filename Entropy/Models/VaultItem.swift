import Foundation
import SwiftData

enum VaultItemType: String, Codable, CaseIterable {
    case passport, driversLicense, insurance, medicalCard, socialSecurity, creditCard, other

    var displayName: String {
        switch self {
        case .passport: return "Passport"
        case .driversLicense: return "Driver's License"
        case .insurance: return "Insurance Card"
        case .medicalCard: return "Medical Card"
        case .socialSecurity: return "Social Security"
        case .creditCard: return "Credit Card"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .passport: return "airplane.circle.fill"
        case .driversLicense: return "car.fill"
        case .insurance: return "shield.fill"
        case .medicalCard: return "cross.case.fill"
        case .socialSecurity: return "person.text.rectangle.fill"
        case .creditCard: return "creditcard.fill"
        case .other: return "doc.fill"
        }
    }
}

@Model
final class VaultItem {
    var id: UUID
    var type: VaultItemType
    var label: String
    var imagesFront: Data?
    var imagesBack: Data?
    var expirationDate: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \VaultField.vaultItem)
    var fields: [VaultField]

    @Relationship(deleteRule: .cascade, inverse: \Reminder.vaultItem)
    var reminders: [Reminder]

    init(type: VaultItemType, label: String) {
        self.id = UUID()
        self.type = type
        self.label = label
        self.notes = ""
        self.createdAt = Date()
        self.updatedAt = Date()
        self.fields = []
        self.reminders = []
    }

    var isExpiringSoon: Bool {
        guard let exp = expirationDate else { return false }
        let threeMonths = Calendar.current.date(byAdding: .month, value: 3, to: Date()) ?? Date()
        return exp <= threeMonths && exp > Date()
    }

    var isExpired: Bool {
        guard let exp = expirationDate else { return false }
        return exp <= Date()
    }
}

@Model
final class VaultField {
    var id: UUID
    var key: String
    var value: String
    var sortOrder: Int

    @Relationship var vaultItem: VaultItem?

    init(key: String, value: String, sortOrder: Int = 0) {
        self.id = UUID()
        self.key = key
        self.value = value
        self.sortOrder = sortOrder
    }
}
