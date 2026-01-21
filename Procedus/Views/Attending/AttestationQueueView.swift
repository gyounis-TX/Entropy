// AttestationQueueView.swift
// Procedus - Unified V7
// Complete Attending Attestation Workflow

import SwiftUI
import SwiftData

// MARK: - Attestation Queue View

struct AttestationQueueView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query private var allCases: [CaseEntry]
    @Query private var attendings: [Attending]
    @Query private var programs: [Program]
    @Query private var users: [User]
    @Query private var notifications: [Procedus.Notification]
    @Query private var evaluationFields: [EvaluationField]
    @Query private var facilities: [TrainingFacility]

    @AppStorage("selectedAttendingId") private var selectedAttendingIdString = ""

    @State private var showingNotifications = false
    @State private var selectedCase: CaseEntry?
    @State private var showingBulkAttestConfirm = false

    private var currentAttendingId: UUID? {
        UUID(uuidString: selectedAttendingIdString)
    }

    private var currentProgram: Program? { programs.first }

    private var evaluationsRequired: Bool {
        currentProgram?.evaluationsEnabled == true && currentProgram?.evaluationsRequired == true
    }

    private var currentAttendingName: String {
        guard let id = currentAttendingId,
              let attending = attendings.first(where: { $0.id == id }) else {
            return "Attending"
        }
        return attending.name
    }

    private var unreadNotificationCount: Int {
        guard let attendingId = currentAttendingId else { return 0 }
        return notifications.filter { !$0.isRead && ($0.attendingId == attendingId || $0.userId == attendingId) }.count
    }

    private var hasAttendingSelected: Bool {
        guard let id = currentAttendingId else { return false }
        return attendings.contains { $0.id == id && !$0.isArchived }
    }

    private var pendingCases: [CaseEntry] {
        guard let attendingId = currentAttendingId else { return [] }
        return allCases
            .filter {
                ($0.attendingId == attendingId || $0.supervisorId == attendingId) &&
                ($0.attestationStatus == .pending || $0.attestationStatus == .requested)
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning banner if no attending selected
                if !hasAttendingSelected {
                    warningBanner
                }

                // Main content
                if !hasAttendingSelected {
                    noAttendingSelectedView
                } else if pendingCases.isEmpty {
                    allCaughtUpView
                } else {
                    attestationListView
                }
            }
            .navigationTitle("Attestations")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellButton(role: .attending, badgeCount: unreadNotificationCount) {
                        showingNotifications = true
                    }
                }
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsSheet(role: .attending, userId: currentAttendingId)
            }
            .sheet(item: $selectedCase) { caseEntry in
                AttendingAttestationDetailSheet(
                    caseEntry: caseEntry,
                    attestorId: currentAttendingId,
                    users: users,
                    attendings: Array(attendings),
                    facilities: Array(facilities),
                    evaluationFields: activeEvaluationFields,
                    evaluationsEnabled: currentProgram?.evaluationsEnabled ?? false,
                    evaluationsRequired: evaluationsRequired,
                    freeTextEnabled: currentProgram?.evaluationFreeTextEnabled ?? true
                )
            }
            .alert("Attest All Cases", isPresented: $showingBulkAttestConfirm) {
                Button("Attest All") { attestAllCases() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("By confirming, you attest that you supervised the trainee during all \(pendingCases.count) procedures. This action cannot be undone.")
            }
        }
    }

    private var activeEvaluationFields: [EvaluationField] {
        evaluationFields.filter { !$0.isArchived }
    }

    // MARK: - Warning Banner

    private var warningBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text("Select your identity in Settings to view attestations")
                .font(.caption)
                .foregroundColor(.orange)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.15))
    }

    // MARK: - No Attending Selected

    private var noAttendingSelectedView: some View {
        EmptyStateView(
            icon: "person.crop.circle.badge.questionmark",
            title: "No Attending Selected",
            message: "Go to Settings and select your identity to view cases assigned to you."
        )
    }

    // MARK: - All Caught Up

    private var allCaughtUpView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal")
                .font(.system(size: 48))
                .foregroundColor(Color(UIColor.tertiaryLabel))

            Text("All Caught Up")
                .font(.headline)

            Text("No cases waiting for your attestation.")
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Attestation List

    private var attestationListView: some View {
        VStack(spacing: 0) {
            // Bulk Actions Bar
            if pendingCases.count > 0 {
                VStack(spacing: 0) {
                    // Pending count
                    HStack {
                        Text("\(pendingCases.count) pending attestation\(pendingCases.count == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    // Attest All button (hidden when evaluations required)
                    if !evaluationsRequired && pendingCases.count > 1 {
                        Button {
                            showingBulkAttestConfirm = true
                        } label: {
                            VStack(spacing: 2) {
                                Text("Attest All")
                                    .font(.headline)
                                    .fontWeight(.bold)
                                Text("I supervised these cases")
                                    .font(.caption)
                                    .opacity(0.9)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .cornerRadius(10)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    } else if evaluationsRequired && pendingCases.count > 1 {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("Bulk attestation disabled — evaluations are required")
                                .font(.caption)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
            }

            // Cases List
            List {
                ForEach(pendingCases) { caseEntry in
                    AttestationQueueCaseRow(
                        caseEntry: caseEntry,
                        users: users,
                        facilities: Array(facilities)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedCase = caseEntry
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func attestAllCases() {
        // Capture cases first - important because pendingCases is a computed property
        // that filters by status, so after we change status, they won't be in the list anymore
        let casesToAttest = pendingCases
        guard !casesToAttest.isEmpty else { return }

        let now = Date()
        let attestorId = currentAttendingId

        // Update all cases
        for caseEntry in casesToAttest {
            caseEntry.attestationStatus = .attested
            caseEntry.attestedAt = now
            caseEntry.attestorId = attestorId
        }

        // Save changes
        do {
            try modelContext.save()
        } catch {
            print("Error saving attested cases: \(error)")
            return
        }

        // Send notifications to fellows using captured array
        for caseEntry in casesToAttest {
            if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
                PushNotificationManager.shared.notifyAttestationComplete(
                    caseId: caseEntry.id,
                    status: "attested",
                    fellowId: fellowId
                )
            }
        }
    }
}

// MARK: - Attestation Queue Case Row

struct AttestationQueueCaseRow: View {
    let caseEntry: CaseEntry
    let users: [User]
    let facilities: [TrainingFacility]

    private var fellowName: String {
        users.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown Fellow"
    }

    private var facilityName: String {
        facilities.first { $0.id == caseEntry.facilityId || $0.id == caseEntry.hospitalId }?.name ?? ""
    }

    private var categoryBubbles: [ProcedureCategory] {
        var categories = Set<ProcedureCategory>()
        for tagId in caseEntry.procedureTagIds {
            if let procedure = SpecialtyPackCatalog.findProcedure(by: tagId) {
                for pack in SpecialtyPackCatalog.allPacks {
                    for packCategory in pack.categories {
                        if packCategory.procedures.contains(where: { $0.id == tagId }) {
                            categories.insert(packCategory.category)
                            break
                        }
                    }
                }
            }
        }
        return Array(categories).sorted { $0.rawValue < $1.rawValue }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fellow name and procedure count
            HStack {
                Text(fellowName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(caseEntry.procedureTagIds.count) procedure\(caseEntry.procedureTagIds.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(UIColor.tertiarySystemFill))
                    .cornerRadius(4)
            }

            // Category bubbles
            if !categoryBubbles.isEmpty {
                HStack(spacing: 6) {
                    ForEach(categoryBubbles.prefix(4), id: \.rawValue) { category in
                        CategoryBubble(category: category, size: 24)
                    }
                    if categoryBubbles.count > 4 {
                        Text("+\(categoryBubbles.count - 4)")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.tertiaryLabel))
                    }
                }
            }

            // Date range and facility
            HStack {
                Text(caseEntry.weekBucket.toWeekTimeframeLabel())
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                if !facilityName.isEmpty {
                    Text("•")
                        .foregroundColor(Color(UIColor.tertiaryLabel))
                    Text(facilityName)
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                }
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Attending Attestation Detail Sheet

struct AttendingAttestationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let caseEntry: CaseEntry
    let attestorId: UUID?
    let users: [User]
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    let evaluationFields: [EvaluationField]
    let evaluationsEnabled: Bool
    let evaluationsRequired: Bool
    let freeTextEnabled: Bool

    /// Evaluation responses keyed by field ID
    /// Values: "true"/"false" for checkboxes, "1"-"5" for ratings
    @State private var evaluationResponses: [UUID: String] = [:]
    @State private var evaluationComment = ""
    @State private var showingRejectSheet = false

    /// Active (non-archived) evaluation fields, sorted by display order
    private var activeEvaluationFields: [EvaluationField] {
        evaluationFields
            .filter { !$0.isArchived }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    private var fellowName: String {
        users.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }

    private var attendingName: String {
        attendings.first { $0.id == caseEntry.attendingId || $0.id == caseEntry.supervisorId }?.name ?? "Unknown"
    }

    private var facilityName: String {
        facilities.first { $0.id == caseEntry.facilityId || $0.id == caseEntry.hospitalId }?.name ?? "Not specified"
    }

    private var procedures: [String] {
        caseEntry.procedureTagIds.compactMap { tagId in
            SpecialtyPackCatalog.findProcedure(by: tagId)?.title ?? (tagId.hasPrefix("custom-") ? "Custom Procedure" : nil)
        }
    }

    private var canAttest: Bool {
        if evaluationsRequired {
            // Check that all required fields have valid responses
            let requiredFields = activeEvaluationFields.filter { $0.isRequired }
            for field in requiredFields {
                let value = evaluationResponses[field.id] ?? ""
                if field.fieldType == .checkbox && value != "true" { return false }
                if field.fieldType == .rating && (value.isEmpty || value == "0") { return false }
            }
            // If no required fields but evaluations required, need at least one response
            if requiredFields.isEmpty && evaluationResponses.isEmpty {
                return false
            }
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Case Summary
                    caseSummarySection

                    Divider()

                    // Procedures List
                    proceduresSection

                    // Evaluation Section (if enabled)
                    if evaluationsEnabled {
                        Divider()
                        evaluationSection
                    }

                    // Comments Section
                    Divider()
                    commentsSection

                    // Action Buttons
                    actionButtonsSection
                }
                .padding()
            }
            .navigationTitle("Case Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingRejectSheet) {
                RejectAttestationSheet(caseEntry: caseEntry, fellowName: fellowName, rejectorId: attestorId)
            }
        }
    }

    // MARK: - Case Summary

    private var caseSummarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Case Summary")
                .font(.headline)

            SummaryRow(label: "Fellow", value: fellowName)
            SummaryRow(label: "Timeframe", value: caseEntry.weekBucket.toWeekTimeframeLabel())
            SummaryRow(label: "Facility", value: facilityName)
            SummaryRow(label: "Outcome", value: caseEntry.outcome.rawValue)

            if !caseEntry.complicationIds.isEmpty {
                SummaryRow(label: "Complications", value: "\(caseEntry.complicationIds.count) reported")
            }

            if let fellowComment = caseEntry.fellowComment, !fellowComment.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fellow's Notes")
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                    Text(fellowComment)
                        .font(.subheadline)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(UIColor.tertiarySystemFill))
                        .cornerRadius(8)
                }
            }
        }
    }

    // MARK: - Procedures Section

    private var proceduresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Procedures (\(procedures.count))")
                .font(.headline)

            ForEach(procedures, id: \.self) { procedure in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text(procedure)
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - Evaluation Section

    private var evaluationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Evaluation")
                    .font(.headline)
                if evaluationsRequired {
                    Text("(Required)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }

            if activeEvaluationFields.isEmpty {
                Text("No evaluation criteria configured")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
                    .italic()
            } else {
                ForEach(activeEvaluationFields) { field in
                    EvaluationFieldInputView(
                        field: field,
                        value: Binding(
                            get: { evaluationResponses[field.id] ?? "" },
                            set: { evaluationResponses[field.id] = $0 }
                        )
                    )
                }
            }
        }
    }
}

// MARK: - Evaluation Field Input View

/// Renders different UI based on evaluation field type
struct EvaluationFieldInputView: View {
    let field: EvaluationField
    @Binding var value: String

    var body: some View {
        switch field.fieldType {
        case .checkbox:
            checkboxView
        case .rating:
            ratingView
        default:
            checkboxView  // Fallback for future field types
        }
    }

    private var checkboxView: some View {
        Button {
            value = (value == "true") ? "false" : "true"
        } label: {
            HStack(spacing: 12) {
                Image(systemName: value == "true" ? "checkmark.square.fill" : "square")
                    .foregroundColor(value == "true" ? .blue : Color(UIColor.tertiaryLabel))
                    .font(.title3)
                Text(field.title)
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.label))
                if field.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }

    private var ratingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.title)
                    .font(.subheadline)
                if field.isRequired {
                    Text("*")
                        .foregroundColor(.red)
                        .font(.subheadline)
                }
            }

            // Rating picker with descriptive labels
            Picker("Rating", selection: Binding(
                get: { Int(value) ?? 0 },
                set: { value = String($0) }
            )) {
                Text("Select rating...").tag(0)
                ForEach(1...5, id: \.self) { rating in
                    Text("\(rating) - \(ratingLabel(rating))").tag(rating)
                }
            }
            .pickerStyle(.menu)
            .tint(.blue)
            .padding(.vertical, 4)
            .padding(.horizontal, 12)
            .background(Color(UIColor.tertiarySystemFill))
            .cornerRadius(8)
        }
    }

    private func ratingLabel(_ rating: Int) -> String {
        switch rating {
        case 1: return "Needs significant improvement"
        case 2: return "Needs improvement"
        case 3: return "Meets expectations"
        case 4: return "Exceeds expectations"
        case 5: return "Exceptional"
        default: return ""
        }
    }
}

// MARK: - Attending Attestation Detail Sheet Extensions

extension AttendingAttestationDetailSheet {
    // MARK: - Comments Section

    var commentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Feedback for Fellow")
                .font(.headline)

            Text("Any feedback for the fellow. Do not include PHI.")
                .font(.caption)
                .foregroundColor(Color(UIColor.secondaryLabel))

            TextEditor(text: $evaluationComment)
                .frame(minHeight: 80)
                .padding(8)
                .background(Color(UIColor.tertiarySystemFill))
                .cornerRadius(8)
        }
    }

    // MARK: - Action Buttons

    var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                attestCase()
            } label: {
                VStack(spacing: 2) {
                    Text("Attest Case")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("I supervised this trainee during this procedure")
                        .font(.caption)
                        .opacity(0.9)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canAttest ? Color.green : Color.gray)
                .cornerRadius(10)
            }
            .disabled(!canAttest)

            Button {
                showingRejectSheet = true
            } label: {
                Text("Reject")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
            }
        }
        .padding(.top, 8)
    }

    func attestCase() {
        caseEntry.attestationStatus = .attested
        caseEntry.attestedAt = Date()
        caseEntry.attestorId = attestorId

        // Store evaluation responses in new JSON format
        var responses: [String: String] = [:]
        for (fieldId, value) in evaluationResponses {
            responses[fieldId.uuidString] = value
        }
        caseEntry.evaluationResponses = responses
        caseEntry.evaluationComment = evaluationComment.isEmpty ? nil : evaluationComment

        do {
            try modelContext.save()
        } catch {
            print("Error saving attested case: \(error)")
            return
        }

        // Notify fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            PushNotificationManager.shared.notifyAttestationComplete(
                caseId: caseEntry.id,
                status: "attested",
                fellowId: fellowId
            )
        }

        dismiss()
    }
}

// MARK: - Summary Row

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(Color(UIColor.secondaryLabel))
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

// MARK: - Reject Attestation Sheet

struct RejectAttestationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let caseEntry: CaseEntry
    let fellowName: String
    let rejectorId: UUID?

    @State private var rejectionReason = ""
    @State private var selectedReasons: Set<RejectionReason> = []

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("You are about to reject the attestation for \(fellowName)'s case from \(caseEntry.weekBucket.toWeekTimeframeLabel()).")
                        .font(.subheadline)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                } header: {
                    Text("Rejection")
                }

                Section {
                    ForEach(RejectionReason.allCases) { reason in
                        Button {
                            if selectedReasons.contains(reason) {
                                selectedReasons.remove(reason)
                            } else {
                                selectedReasons.insert(reason)
                            }
                        } label: {
                            HStack {
                                Image(systemName: selectedReasons.contains(reason) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedReasons.contains(reason) ? .blue : Color(UIColor.tertiaryLabel))
                                Text(reason.displayName)
                                    .font(.subheadline)
                                    .foregroundColor(Color(UIColor.label))
                            }
                        }
                    }
                } header: {
                    Text("Reason for Rejection")
                }

                Section {
                    TextEditor(text: $rejectionReason)
                        .frame(minHeight: 100)
                } header: {
                    Text("Additional Details")
                } footer: {
                    Text("Provide a clear reason for the rejection. This will be visible to the fellow and program administrators.")
                }
            }
            .navigationTitle("Reject Attestation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm Rejection") {
                        rejectCase()
                    }
                    .foregroundColor(.red)
                    .disabled(rejectionReason.isEmpty && selectedReasons.isEmpty)
                }
            }
        }
    }

    private func rejectCase() {
        var fullReason = selectedReasons.map { $0.displayName }.joined(separator: "; ")
        if !rejectionReason.isEmpty {
            if !fullReason.isEmpty {
                fullReason += ". "
            }
            fullReason += rejectionReason
        }

        caseEntry.attestationStatus = .rejected
        caseEntry.rejectionReason = fullReason
        caseEntry.rejectorId = rejectorId
        caseEntry.rejectedAt = Date()

        do {
            try modelContext.save()
        } catch {
            print("Error saving rejected case: \(error)")
            return
        }

        // Notify fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            PushNotificationManager.shared.notifyAttestationRejected(
                caseId: caseEntry.id,
                reason: fullReason,
                fellowId: fellowId
            )
        }

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    AttestationQueueView()
        .environment(AppState())
}
