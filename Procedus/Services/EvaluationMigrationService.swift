// EvaluationMigrationService.swift
// Procedus - Unified
// Handles one-time migration of evaluation data to new format

import Foundation
import SwiftData

/// Handles migration of evaluation system data:
/// 1. Migrates Program.evaluationItems to EvaluationField objects
/// 2. Migrates CaseEntry.evaluationChecks to evaluationResponsesJson
/// 3. Sets default fieldTypeRaw for existing EvaluationField records
enum EvaluationMigrationService {
    private static let migrationKey = "evaluationSystemV2MigrationComplete"

    /// Run migration if not already completed
    static func migrateIfNeeded(context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: migrationKey) else {
            return
        }

        do {
            // Step 1: Ensure all existing EvaluationField records have fieldTypeRaw set
            migrateEvaluationFieldTypes(context: context)

            // Step 2: Migrate Program.evaluationItems to EvaluationField objects
            migrateProgramEvaluationItems(context: context)

            // Step 3: Migrate CaseEntry.evaluationChecks to evaluationResponsesJson
            migrateCaseEvaluations(context: context)

            try context.save()
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("[EvaluationMigration] Migration completed successfully")
        } catch {
            print("[EvaluationMigration] Migration failed: \(error)")
        }
    }

    /// Set fieldTypeRaw to "checkbox" for any existing EvaluationField records that don't have it set
    private static func migrateEvaluationFieldTypes(context: ModelContext) {
        let descriptor = FetchDescriptor<EvaluationField>()
        guard let fields = try? context.fetch(descriptor) else { return }

        for field in fields {
            // If fieldTypeRaw is nil or empty, set to checkbox (existing behavior)
            if field.fieldTypeRaw.isEmpty {
                field.fieldTypeRaw = EvaluationFieldType.checkbox.rawValue
            }
        }
    }

    /// Migrate Program.evaluationItems strings to EvaluationField objects
    private static func migrateProgramEvaluationItems(context: ModelContext) {
        let programDescriptor = FetchDescriptor<Program>()
        guard let programs = try? context.fetch(programDescriptor) else { return }

        let fieldDescriptor = FetchDescriptor<EvaluationField>()
        let existingFields = (try? context.fetch(fieldDescriptor)) ?? []

        for program in programs {
            for (index, item) in program.evaluationItems.enumerated() {
                // Check if field already exists for this program and title
                let alreadyExists = existingFields.contains { field in
                    field.title == item && field.programId == program.id
                }

                if !alreadyExists {
                    let field = EvaluationField(
                        title: item,
                        fieldType: .checkbox,
                        isRequired: false,
                        displayOrder: index,
                        programId: program.id,
                        isDefault: true
                    )
                    context.insert(field)
                }
            }

            // Clear the old array after migration
            if !program.evaluationItems.isEmpty {
                program.evaluationItems = []
            }
        }
    }

    /// Migrate CaseEntry.evaluationChecks to evaluationResponsesJson
    private static func migrateCaseEvaluations(context: ModelContext) {
        let caseDescriptor = FetchDescriptor<CaseEntry>()
        guard let cases = try? context.fetch(caseDescriptor) else { return }

        let fieldDescriptor = FetchDescriptor<EvaluationField>()
        let fields = (try? context.fetch(fieldDescriptor)) ?? []

        for caseEntry in cases {
            // Skip if already migrated (has evaluationResponsesJson set)
            if caseEntry.evaluationResponsesJson != nil && !caseEntry.evaluationResponsesJson!.isEmpty {
                continue
            }

            // Skip if no old data to migrate
            guard !caseEntry.evaluationChecks.isEmpty else { continue }

            var responses: [String: String] = [:]

            for check in caseEntry.evaluationChecks {
                // Handle InstitutionalViews format: "uuid:value"
                if check.contains(":") {
                    let parts = check.split(separator: ":", maxSplits: 1)
                    if parts.count == 2 {
                        let fieldIdStr = String(parts[0])
                        let value = String(parts[1])
                        responses[fieldIdStr] = value
                    }
                } else {
                    // Handle AttestationQueueView format: plain title strings
                    // Find matching field by title and mark as checked
                    if let field = fields.first(where: { $0.title == check }) {
                        responses[field.id.uuidString] = "true"
                    } else {
                        // If no matching field, store with title as key (fallback)
                        // This preserves data even if field was deleted
                        responses[check] = "true"
                    }
                }
            }

            // Set the new JSON format
            caseEntry.evaluationResponses = responses

            // Clear old format
            caseEntry.evaluationChecks = []
        }
    }

    /// Force re-run migration (for debugging/testing)
    static func resetMigration() {
        UserDefaults.standard.removeObject(forKey: migrationKey)
    }
}
