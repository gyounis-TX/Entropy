// InstitutionalViews.swift
// Procedus - Unified
// Institutional mode views - CORRECTED for ProcedusPro parity

import SwiftUI
import SwiftData

// MARK: - Fellow Log View (Institutional)

struct FellowLogView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query(filter: #Predicate<Attending> { !$0.isArchived }) private var attendings: [Attending]
    @Query(filter: #Predicate<TrainingFacility> { !$0.isArchived }) private var facilities: [TrainingFacility]
    
    @AppStorage("selectedFellowId") private var selectedFellowIdString = ""
    
    @State private var selectedWeek: String = ""
    @State private var showingAddCase = false
    @State private var caseToEdit: CaseEntry?
    @State private var showingNotifications = false
    
    private var fellowId: UUID? { UUID(uuidString: selectedFellowIdString) }
    private var myCases: [CaseEntry] {
        guard let id = fellowId else { return [] }
        return allCases.filter { $0.ownerId == id }
    }
    private var casesForSelectedWeek: [CaseEntry] {
        myCases.filter { $0.weekBucket == selectedWeek }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if fellowId == nil {
                    EmptyStateView(icon: "person.crop.circle.badge.questionmark", title: "No Fellow Selected", message: "Go to Settings and select your identity.")
                } else {
                    weekSelector
                    if casesForSelectedWeek.isEmpty {
                        EmptyStateView(icon: "list.clipboard", title: "No Cases", message: "No cases for this week.", actionTitle: "Add Case", action: { showingAddCase = true })
                    } else {
                        caseList
                    }
                }
            }
            .background(ProcedusTheme.background)
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NotificationBellButton(role: .fellow, badgeCount: 0) { showingNotifications = true }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAddCase = true } label: { Image(systemName: "plus").fontWeight(.semibold) }
                        .disabled(fellowId == nil)
                }
            }
            .sheet(isPresented: $showingAddCase) { AddEditCaseView(weekBucket: selectedWeek) }
            .sheet(item: $caseToEdit) { c in AddEditCaseView(existingCase: c) }
            .onAppear {
                if selectedWeek.isEmpty { selectedWeek = CaseEntry.makeWeekBucket(for: Date()) }
            }
        }
    }
    
    private var weekSelector: some View {
        HStack {
            Button { navigateWeek(-1) } label: { Image(systemName: "chevron.left").foregroundStyle(ProcedusTheme.primary) }
            Spacer()
            Text(selectedWeek.toWeekTimeframeLabel()).font(.subheadline)
            Spacer()
            Button { navigateWeek(1) } label: { Image(systemName: "chevron.right").foregroundStyle(ProcedusTheme.primary) }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
    }
    
    private func navigateWeek(_ delta: Int) {
        let cal = Calendar(identifier: .iso8601)
        let parts = selectedWeek.split(separator: "-W")
        guard parts.count == 2, let y = Int(parts[0]), let w = Int(parts[1]) else { return }
        var dc = DateComponents(); dc.yearForWeekOfYear = y; dc.weekOfYear = w; dc.weekday = 2
        guard let d = cal.date(from: dc), let nd = cal.date(byAdding: .weekOfYear, value: delta, to: d) else { return }
        selectedWeek = CaseEntry.makeWeekBucket(for: nd)
    }
    
    private var caseList: some View {
        List {
            ForEach(casesForSelectedWeek) { caseEntry in
                InstitutionalCaseRow(caseEntry: caseEntry, attendings: Array(attendings), facilities: Array(facilities))
                    .onTapGesture { caseToEdit = caseEntry }
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Institutional Case Row

struct InstitutionalCaseRow: View {
    let caseEntry: CaseEntry
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            let tags = caseEntry.procedureTagIds.compactMap { SpecialtyPackCatalog.findProcedure(by: $0)?.title }
            Text(tags.prefix(3).joined(separator: ", ")).font(.subheadline).fontWeight(.medium)
            if tags.count > 3 { Text("+\(tags.count - 3) more").font(.caption).foregroundStyle(ProcedusTheme.textSecondary) }
            
            HStack {
                if let a = attendings.first(where: { $0.id == caseEntry.supervisorId }) {
                    Label(a.name, systemImage: "person").font(.caption).foregroundStyle(ProcedusTheme.textSecondary)
                }
                Spacer()
                AttestationStatusBadge(status: caseEntry.attestationStatus)
                
                // Show "Proxy" indicator per spec
                if caseEntry.isProxyAttestation {
                    Text("Proxy").font(.caption2).foregroundStyle(.orange)
                }
            }
            
            // Show rejection reason if rejected (per spec: visually flagged)
            if caseEntry.attestationStatus == .rejected {
                if let reason = caseEntry.rejectionReason, !reason.isEmpty {
                    Text("Reason: \(reason)")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.error)
                        .padding(.top, 2)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Attestation Case Row

struct AttestationCaseRow: View {
    let caseEntry: CaseEntry
    let users: [User]
    let facilities: [TrainingFacility]
    
    private var fellowName: String {
        // Per spec: display LAST NAME ONLY
        users.first { $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(fellowName).font(.subheadline).fontWeight(.medium)
            
            let tags = caseEntry.procedureTagIds.compactMap { SpecialtyPackCatalog.findProcedure(by: $0)?.title }
            Text("\(tags.count) procedure(s)").font(.caption).foregroundStyle(ProcedusTheme.textSecondary)
            
            Text(caseEntry.weekBucket.toWeekTimeframeLabel()).font(.caption).foregroundStyle(ProcedusTheme.textTertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Attestation Detail Sheet (CORRECTED)

struct AttestationDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState
    
    let caseEntry: CaseEntry
    let users: [User]
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    let evaluationFields: [EvaluationField]
    let evaluationMode: EvaluationMode
    
    @State private var comment = ""
    @State private var showingRejectSheet = false
    @State private var evaluationResponses: [UUID: String] = [:]
    
    private var fellowName: String {
        users.first { $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }
    
    private var facilityName: String {
        guard let id = caseEntry.hospitalId else { return "N/A" }
        return facilities.first { $0.id == id }?.name ?? "Unknown"
    }
    
    private var canAttest: Bool {
        if evaluationMode == .mandatory {
            // All required fields must be completed
            let requiredFields = evaluationFields.filter { $0.isRequired }
            for field in requiredFields {
                guard let response = evaluationResponses[field.id], !response.isEmpty else {
                    return false
                }
            }
        }
        return true
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Case Details
                Section("Case Details") {
                    LabeledContent("Fellow", value: fellowName)
                    LabeledContent("Week", value: caseEntry.weekBucket.toWeekTimeframeLabel())
                    LabeledContent("Facility", value: facilityName)
                    LabeledContent("Outcome", value: caseEntry.outcome.rawValue)
                }
                
                // Procedures
                Section("Procedures (\(caseEntry.procedureTagIds.count))") {
                    ForEach(caseEntry.procedureTagIds, id: \.self) { tagId in
                        Text(SpecialtyPackCatalog.findProcedure(by: tagId)?.title ?? tagId)
                            .font(.subheadline)
                    }
                }
                
                // Complications
                if !caseEntry.complicationIds.isEmpty {
                    Section("Complications") {
                        ForEach(caseEntry.complicationIds, id: \.self) { compId in
                            Text(compId).font(.subheadline).foregroundStyle(ProcedusTheme.warning)
                        }
                    }
                }
                
                // Evaluation Fields (per spec 7.2)
                if evaluationMode != .disabled && !evaluationFields.isEmpty {
                    Section {
                        ForEach(evaluationFields.sorted { $0.displayOrder < $1.displayOrder }) { field in
                            EvaluationFieldView(
                                field: field,
                                response: Binding(
                                    get: { evaluationResponses[field.id] ?? "" },
                                    set: { evaluationResponses[field.id] = $0 }
                                )
                            )
                        }
                    } header: {
                        HStack {
                            Text("Evaluation")
                            if evaluationMode == .mandatory {
                                Text("*").foregroundStyle(ProcedusTheme.error)
                            }
                        }
                        .font(.caption)
                    } footer: {
                        if evaluationMode == .mandatory {
                            Text("Required fields must be completed before attesting.")
                                .font(.caption2)
                        }
                    }
                }
                
                // Comment (always optional per spec)
                Section("Comment (Optional)") {
                    TextField("Add a comment...", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                // Actions
                Section {
                    HStack(spacing: 16) {
                        Button {
                            showingRejectSheet = true
                        } label: {
                            Text("Reject")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(ProcedusTheme.error.opacity(0.15))
                                .foregroundStyle(ProcedusTheme.error)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            attest()
                        } label: {
                            Text("Attest")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(canAttest ? ProcedusTheme.success : ProcedusTheme.textTertiary)
                                .foregroundStyle(.white)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canAttest)
                    }
                }
            }
            .navigationTitle("Review Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showingRejectSheet) {
                RejectionSheet(caseEntry: caseEntry, comment: comment, onReject: { dismiss() })
            }
        }
    }
    
    private func attest() {
        guard let attestorId = UUID(uuidString: UserDefaults.standard.string(forKey: "selectedAttendingId") ?? "") else { return }

        // Save evaluation responses using new JSON format
        caseEntry.evaluationResponses = evaluationResponses.reduce(into: [String: String]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }

        // Attest the case
        caseEntry.attestationStatus = .attested
        caseEntry.attestedAt = Date()
        caseEntry.attestorId = attestorId
        caseEntry.attestationComment = comment.isEmpty ? nil : comment

        try? modelContext.save()

        PushNotificationManager.shared.notifyAttestationComplete(caseId: caseEntry.id, status: "attested", fellowId: caseEntry.ownerId ?? UUID())
        dismiss()
    }
}

// MARK: - Evaluation Field View

struct EvaluationFieldView: View {
    let field: EvaluationField
    @Binding var response: String

    var body: some View {
        switch field.fieldType {
        case .checkbox:
            checkboxView
        case .rating:
            ratingView
        default:
            checkboxView
        }
    }

    private var checkboxView: some View {
        Toggle(isOn: Binding(
            get: { response == "true" },
            set: { response = $0 ? "true" : "false" }
        )) {
            HStack {
                Text(field.title)
                    .font(.subheadline)
                if field.isRequired {
                    Text("*").foregroundStyle(ProcedusTheme.error)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: ProcedusTheme.primary))
    }

    private var ratingView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(field.title)
                    .font(.subheadline)
                if field.isRequired {
                    Text("*").foregroundStyle(ProcedusTheme.error)
                }
            }

            Picker("Rating", selection: Binding(
                get: { response.isEmpty ? 0 : (Int(response) ?? 0) },
                set: { response = $0 == 0 ? "" : String($0) }
            )) {
                Text("Not rated").tag(0)
                ForEach(1...5, id: \.self) { rating in
                    Text(ratingLabel(for: rating)).tag(rating)
                }
            }
            .pickerStyle(.menu)
            .tint(ProcedusTheme.primary)
        }
    }

    private func ratingLabel(for rating: Int) -> String {
        switch rating {
        case 1: return "1 - Needs significant improvement"
        case 2: return "2 - Needs improvement"
        case 3: return "3 - Meets expectations"
        case 4: return "4 - Exceeds expectations"
        case 5: return "5 - Exceptional"
        default: return "\(rating)"
        }
    }
}

// MARK: - Rejection Sheet (CORRECTED - Checkbox + Free Text per spec)

struct RejectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let caseEntry: CaseEntry
    let comment: String
    let onReject: () -> Void
    
    @State private var selectedReasons: Set<RejectionReason> = []
    @State private var otherReason = ""
    
    private var canReject: Bool {
        !selectedReasons.isEmpty || !otherReason.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Checkbox reasons per spec 7.3
                Section("Select Reason(s)") {
                    ForEach(RejectionReason.allCases) { reason in
                        if reason != .other {
                            Toggle(isOn: Binding(
                                get: { selectedReasons.contains(reason) },
                                set: { isSelected in
                                    if isSelected { selectedReasons.insert(reason) }
                                    else { selectedReasons.remove(reason) }
                                }
                            )) {
                                Text(reason.rawValue)
                                    .font(.subheadline)
                            }
                            .toggleStyle(ClinicalCheckboxToggleStyle())
                        }
                    }
                }
                
                // Free text option per spec
                Section("Other Reason") {
                    TextField("Specify other reason...", text: $otherReason, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section {
                    Button {
                        reject()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reject Case")
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(canReject ? ProcedusTheme.error : ProcedusTheme.textTertiary)
                    .disabled(!canReject)
                }
            }
            .navigationTitle("Reject Case")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    
    private func reject() {
        guard let attestorId = UUID(uuidString: UserDefaults.standard.string(forKey: "selectedAttendingId") ?? "") else { return }

        // Build rejection reason string
        var fullReason = selectedReasons.map { $0.displayName }.joined(separator: "; ")
        if !otherReason.isEmpty {
            if !fullReason.isEmpty { fullReason += ". " }
            fullReason += otherReason
        }

        // Reject the case
        caseEntry.attestationStatus = .rejected
        caseEntry.rejectionReason = fullReason
        caseEntry.attestorId = attestorId
        caseEntry.attestationComment = comment.isEmpty ? nil : comment

        try? modelContext.save()

        // Notify Fellow per spec: "Fellow must be notified"
        PushNotificationManager.shared.notifyAttestationComplete(caseId: caseEntry.id, status: "rejected", fellowId: caseEntry.ownerId ?? UUID())

        dismiss()
        onReject()
    }
}

// MARK: - Admin Case Detail View

struct AdminCaseDetailView: View {
    let caseEntry: CaseEntry
    
    @Query private var users: [User]
    @Query private var attendings: [Attending]
    @Query private var facilities: [TrainingFacility]
    
    private var fellowName: String {
        users.first { $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }
    
    private var attendingName: String {
        guard let id = caseEntry.supervisorId else { return "N/A" }
        return attendings.first { $0.id == id }?.name ?? "Unknown"
    }
    
    private var facilityName: String {
        guard let id = caseEntry.hospitalId else { return "N/A" }
        return facilities.first { $0.id == id }?.name ?? "Unknown"
    }
    
    private var attestorName: String {
        guard let id = caseEntry.attestorId else { return "N/A" }
        return users.first { $0.id == id }?.displayName ?? "Unknown"
    }
    
    private var proxyAttestorName: String? {
        guard let id = caseEntry.proxyAttestorId else { return nil }
        return users.first { $0.id == id }?.displayName
    }
    
    var body: some View {
        Form {
            Section("Case Info") {
                LabeledContent("Fellow", value: fellowName)
                LabeledContent("Attending", value: attendingName)
                LabeledContent("Facility", value: facilityName)
                LabeledContent("Week", value: caseEntry.weekBucket.toWeekTimeframeLabel())
                LabeledContent("Outcome", value: caseEntry.outcome.rawValue)
                
                HStack {
                    Text("Status")
                    Spacer()
                    AttestationStatusBadge(status: caseEntry.attestationStatus)
                }
            }
            
            // Show proxy attestation info per spec
            if caseEntry.isProxyAttestation {
                Section("Proxy Attestation") {
                    LabeledContent("Original Attending", value: attestorName)
                    if let proxyName = proxyAttestorName {
                        LabeledContent("Proxy Attested By", value: proxyName)
                    }
                    if let date = caseEntry.attestedAt {
                        LabeledContent("Date", value: date.formatted(date: .abbreviated, time: .shortened))
                    }
                }
            }
            
            Section("Procedures (\(caseEntry.procedureTagIds.count))") {
                ForEach(caseEntry.procedureTagIds, id: \.self) { tagId in
                    Text(SpecialtyPackCatalog.findProcedure(by: tagId)?.title ?? tagId)
                        .font(.subheadline)
                }
            }
            
            if !caseEntry.accessSiteIds.isEmpty {
                Section("Access Sites") {
                    Text(caseEntry.accessSiteIds.joined(separator: ", "))
                        .font(.subheadline)
                }
            }
            
            if !caseEntry.complicationIds.isEmpty {
                Section("Complications") {
                    ForEach(caseEntry.complicationIds, id: \.self) { compId in
                        Text(compId).font(.subheadline).foregroundStyle(ProcedusTheme.warning)
                    }
                }
            }
            
            // Show rejection details
            if caseEntry.attestationStatus == .rejected {
                Section("Rejection Details") {
                    if let reason = caseEntry.rejectionReason, !reason.isEmpty {
                        Text(reason)
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.error)
                    } else {
                        Text("No reason provided")
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
            }
            
            // Show evaluation responses (supports both new and legacy format)
            if !caseEntry.evaluationResponses.isEmpty || !caseEntry.evaluationChecks.isEmpty {
                Section("Evaluation") {
                    // New format: evaluationResponses dictionary
                    ForEach(Array(caseEntry.evaluationResponses.keys.sorted()), id: \.self) { fieldId in
                        if let value = caseEntry.evaluationResponses[fieldId] {
                            EvaluationResponseDisplayRow(fieldId: fieldId, value: value)
                        }
                    }
                    // Legacy format: evaluationChecks array
                    ForEach(caseEntry.evaluationChecks, id: \.self) { check in
                        Text("• \(check)")
                            .font(.subheadline)
                    }
                }
            }
        }
        .navigationTitle("Case Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Evaluation Response Display Row

struct EvaluationResponseDisplayRow: View {
    @Query private var evaluationFields: [EvaluationField]
    let fieldId: String
    let value: String

    private var field: EvaluationField? {
        if let uuid = UUID(uuidString: fieldId) {
            return evaluationFields.first { $0.id == uuid }
        }
        return nil
    }

    var body: some View {
        HStack {
            if let field = field {
                Text(field.title)
                    .font(.subheadline)
                Spacer()
                if field.fieldType == .rating, let rating = Int(value) {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .foregroundColor(star <= rating ? .orange : Color(UIColor.tertiaryLabel))
                                .font(.caption)
                        }
                    }
                } else {
                    Image(systemName: value == "true" ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(value == "true" ? .green : Color(UIColor.tertiaryLabel))
                }
            } else {
                // Fallback for unknown field ID
                Text("• \(fieldId): \(value)")
                    .font(.subheadline)
                    .foregroundColor(Color(UIColor.secondaryLabel))
            }
        }
    }
}
