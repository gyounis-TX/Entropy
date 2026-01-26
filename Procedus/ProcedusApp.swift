// ProcedusApp.swift
// Procedus - Unified
// Main app entry point with SwiftData configuration

import SwiftUI
import SwiftData

import FirebaseAuth
import FirebaseCore

@main
struct ProcedusApp: App {
    @State private var appState = AppState()
    @State private var appLockService = AppLockService()
    
    let modelContainer: ModelContainer
    
    init() {
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }

        // Minimal auth so Storage rules can require request.auth != null.
        if Auth.auth().currentUser == nil {
            Auth.auth().signInAnonymously { result, error in
                if let error {
                    print("Firebase anonymous auth failed: \(error)")
                } else {
                    print("Firebase anonymous auth uid: \(result?.user.uid ?? "unknown")")
                }
            }
        }

        let schema = Schema([
            User.self,
            CaseEntry.self,
            Program.self,
            Attending.self,
            TrainingFacility.self,
            CustomProcedure.self,
            CustomCategory.self,
            CustomAccessSite.self,
            CustomComplication.self,
            CustomProcedureDetail.self,
            Attestation.self,
            EvaluationField.self,
            ProgramEvaluationSettings.self,
            Notification.self,
            AuditEntry.self,
            FellowProcedureGroup.self,
            Badge.self,
            BadgeEarned.self,
            CaseMedia.self,
            SearchTermSuggestion.self,
            MediaComment.self,
            DutyHoursEntry.self,
            DutyHoursShift.self,
            DutyHoursViolation.self,
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            
            let context = modelContainer.mainContext
            AuditService.shared.configure(with: context)
            NotificationManager.shared.configure(with: context)
            UserDeletionService.shared.configure(with: context)
            SearchTermService.shared.configure(with: context)

            // Run evaluation system migration
            EvaluationMigrationService.migrateIfNeeded(context: context)
            
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .environment(appLockService)
                .modelContainer(modelContainer)
        }
    }
}
