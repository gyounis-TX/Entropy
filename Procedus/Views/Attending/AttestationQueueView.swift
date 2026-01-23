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
    @State private var selectedFellowFilter: UUID? = nil  // nil = All Fellows

    private var currentAttendingId: UUID? {
        UUID(uuidString: selectedAttendingIdString)
    }

    private var currentProgram: Program? { programs.first }

    private var evaluationsRequired: Bool {
        currentProgram?.evaluationsEnabled == true && currentProgram?.evaluationsRequired == true
    }

    private var currentAttending: Attending? {
        guard let id = currentAttendingId else { return nil }
        return attendings.first { $0.id == id }
    }

    private var currentAttendingName: String {
        currentAttending?.name ?? "Attending"
    }

    /// Get all IDs that could be associated with this attending (Attending.id, Attending.userId, or matching User.id)
    private var attendingRelatedIds: Set<UUID> {
        guard let attendingId = currentAttendingId else { return [] }
        var ids: Set<UUID> = [attendingId]
        // Add the linked User ID if it exists
        if let linkedUserId = currentAttending?.userId {
            ids.insert(linkedUserId)
        }
        // Also find any User with role == .attending whose name matches (fallback)
        if let attending = currentAttending {
            if let matchingUser = users.first(where: { $0.role == .attending && "\($0.firstName) \($0.lastName)" == attending.name }) {
                ids.insert(matchingUser.id)
            }
        }
        return ids
    }

    private var unreadNotificationCount: Int {
        guard !attendingRelatedIds.isEmpty else { return 0 }
        // Count unread notifications for any related ID
        let notificationCount = notifications.filter { notification in
            !notification.isRead && !notification.isCleared &&
            (attendingRelatedIds.contains(notification.userId) ||
             (notification.attendingId != nil && attendingRelatedIds.contains(notification.attendingId!)))
        }.count
        // Also count pending attestations as a badge indicator
        let pendingAttestationCount = pendingCases.count
        // Return the higher of the two to ensure badge shows when attestations are waiting
        return max(notificationCount, pendingAttestationCount)
    }

    private var hasAttendingSelected: Bool {
        guard let id = currentAttendingId else { return false }
        return attendings.contains { $0.id == id && !$0.isArchived }
    }

    private var pendingCases: [CaseEntry] {
        guard let attendingId = currentAttendingId else { return [] }
        var cases = allCases
            .filter {
                ($0.attendingId == attendingId || $0.supervisorId == attendingId) &&
                ($0.attestationStatus == .pending || $0.attestationStatus == .requested)
            }

        // Apply fellow filter if selected
        if let fellowId = selectedFellowFilter {
            cases = cases.filter { $0.fellowId == fellowId || $0.ownerId == fellowId }
        }

        return cases.sorted { $0.createdAt > $1.createdAt }
    }

    /// Unique fellows who have pending cases
    private var fellowsWithPendingCases: [User] {
        guard let attendingId = currentAttendingId else { return [] }
        let allPending = allCases.filter {
            ($0.attendingId == attendingId || $0.supervisorId == attendingId) &&
            ($0.attestationStatus == .pending || $0.attestationStatus == .requested)
        }
        let fellowIds = Set(allPending.compactMap { $0.fellowId ?? $0.ownerId })
        return users.filter { fellowIds.contains($0.id) }.sorted { $0.displayName < $1.displayName }
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
            // Header with count and fellow filter
            VStack(spacing: 8) {
                // Fellow filter picker
                if fellowsWithPendingCases.count > 1 {
                    HStack {
                        Text("Filter by Fellow:")
                            .font(.caption)
                            .foregroundColor(Color(UIColor.secondaryLabel))

                        Picker("Fellow", selection: $selectedFellowFilter) {
                            Text("All Fellows").tag(nil as UUID?)
                            ForEach(fellowsWithPendingCases) { fellow in
                                Text(fellow.displayName).tag(fellow.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.blue)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // Pending count
                HStack {
                    Text("\(pendingCases.count) pending attestation\(pendingCases.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()

                    // Attest All button (only when no evaluations required)
                    if !evaluationsRequired && pendingCases.count > 1 {
                        Button {
                            showingBulkAttestConfirm = true
                        } label: {
                            Text("Attest All")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green)
                                .cornerRadius(6)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)

                // Quick ratings hint (when evaluations required)
                if evaluationsRequired {
                    HStack {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("Tap a rating number to rate all competencies, or tap card for full review")
                            .font(.caption2)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))

            // Cases List - Unified card design
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(pendingCases) { caseEntry in
                        UnifiedAttestationCard(
                            caseEntry: caseEntry,
                            users: users,
                            facilities: Array(facilities),
                            evaluationFields: activeEvaluationFields,
                            evaluationsRequired: evaluationsRequired,
                            onQuickRate: { rating in
                                quickRateAllFields(caseEntry, rating: rating)
                            },
                            onTap: {
                                selectedCase = caseEntry
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }

    /// Quick rate all fields with the same rating and attest
    /// rating of 0 means no evaluations, just attest
    private func quickRateAllFields(_ caseEntry: CaseEntry, rating: Int) {
        if rating == 0 {
            // No evaluations, just attest
            quickAttestCase(caseEntry, responses: [:])
        } else {
            // Set all rating fields to the same rating
            let ratingFields = activeEvaluationFields.filter { $0.fieldType == .rating }
            var responses: [UUID: String] = [:]
            for field in ratingFields {
                responses[field.id] = String(rating)
            }
            quickAttestCase(caseEntry, responses: responses)
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

    private func quickAttestCase(_ caseEntry: CaseEntry, responses: [UUID: String]) {
        let now = Date()
        let attestorId = currentAttendingId

        // Save evaluation responses
        caseEntry.evaluationResponses = responses.reduce(into: [String: String]()) { result, pair in
            result[pair.key.uuidString] = pair.value
        }

        // Attest the case
        caseEntry.attestationStatus = .attested
        caseEntry.attestedAt = now
        caseEntry.attestorId = attestorId

        do {
            try modelContext.save()
        } catch {
            print("Error saving quick-attested case: \(error)")
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
    }
}

// MARK: - Unified Attestation Card

struct UnifiedAttestationCard: View {
    let caseEntry: CaseEntry
    let users: [User]
    let facilities: [TrainingFacility]
    let evaluationFields: [EvaluationField]
    let evaluationsRequired: Bool
    let onQuickRate: (Int) -> Void
    let onTap: () -> Void

    private var fellowName: String {
        users.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown Fellow"
    }

    private var facilityName: String {
        facilities.first { $0.id == caseEntry.facilityId || $0.id == caseEntry.hospitalId }?.name ?? ""
    }

    private var procedureNames: [String] {
        caseEntry.procedureTagIds.compactMap { tagId in
            SpecialtyPackCatalog.findProcedure(by: tagId)?.title
        }
    }

    private var hasRatingFields: Bool {
        evaluationFields.contains { $0.fieldType == .rating }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Row 1: Fellow name, date, and quick rate buttons
            HStack(alignment: .center, spacing: 8) {
                // Fellow info
                VStack(alignment: .leading, spacing: 2) {
                    Text(fellowName)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    HStack(spacing: 4) {
                        Text(caseEntry.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(Color(UIColor.secondaryLabel))

                        if !facilityName.isEmpty {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                            Text(facilityName)
                                .font(.caption2)
                                .foregroundColor(Color(UIColor.secondaryLabel))
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                // Quick rate buttons (only when evaluations required)
                if evaluationsRequired && hasRatingFields {
                    HStack(spacing: 4) {
                        ForEach(1...5, id: \.self) { rating in
                            QuickRateButton(rating: rating) {
                                onQuickRate(rating)
                            }
                        }
                    }
                } else if !evaluationsRequired {
                    // Simple attest checkmark when no evaluations
                    Button {
                        onQuickRate(0)  // 0 signals no rating needed
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                    }
                }
            }

            // Row 2: Procedure bubbles
            if !procedureNames.isEmpty {
                FlowLayout(spacing: 4) {
                    ForEach(procedureNames.prefix(5), id: \.self) { name in
                        Text(name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                    }
                    if procedureNames.count > 5 {
                        Text("+\(procedureNames.count - 5)")
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(UIColor.tertiarySystemFill))
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .cornerRadius(12)
                    }
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Quick Rate Button

struct QuickRateButton: View {
    let rating: Int
    let onTap: () -> Void

    private var color: Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return Color(red: 0.4, green: 0.7, blue: 0.2)
        case 5: return .green
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text("\(rating)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout for Procedure Bubbles

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }
            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Quick Rate Case Row (Legacy - keeping for reference)

struct QuickRateCaseRow: View {
    let caseEntry: CaseEntry
    let users: [User]
    let evaluationFields: [EvaluationField]
    let onAttest: ([UUID: String]) -> Void
    let onTap: () -> Void

    @State private var ratings: [UUID: String] = [:]

    private var fellowName: String {
        users.first { $0.id == caseEntry.fellowId || $0.id == caseEntry.ownerId }?.displayName ?? "Unknown"
    }

    private var ratingFields: [EvaluationField] {
        evaluationFields.filter { $0.fieldType == .rating }.sorted { $0.displayOrder < $1.displayOrder }
    }

    private var canAttest: Bool {
        // Check all required rating fields have values
        for field in ratingFields {
            if field.isRequired {
                let value = ratings[field.id] ?? ""
                if value.isEmpty || value == "0" { return false }
            }
        }
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Fellow name row with tap gesture for full review
            HStack {
                Text(fellowName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("•")
                    .foregroundColor(Color(UIColor.tertiaryLabel))

                Text("\(caseEntry.procedureTagIds.count) proc")
                    .font(.caption)
                    .foregroundColor(Color(UIColor.secondaryLabel))

                Spacer()

                // Attest button (enabled when ratings complete)
                Button {
                    onAttest(ratings)
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(canAttest ? .green : Color(UIColor.tertiaryLabel))
                }
                .disabled(!canAttest)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onTap()
            }

            // Compact rating boxes for each rating field
            if !ratingFields.isEmpty {
                Text("Quick Evaluate")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(UIColor.secondaryLabel))

                ForEach(ratingFields.prefix(2)) { field in
                    HStack(spacing: 4) {
                        Text(field.title)
                            .font(.caption2)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                            .lineLimit(1)
                            .frame(width: 80, alignment: .leading)

                        // Compact rating boxes
                        HStack(spacing: 4) {
                            ForEach(1...5, id: \.self) { rating in
                                CompactRatingBox(
                                    rating: rating,
                                    isSelected: Int(ratings[field.id] ?? "") == rating,
                                    onTap: { ratings[field.id] = String(rating) }
                                )
                            }
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(UIColor.tertiarySystemGroupedBackground))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }
}

// MARK: - Compact Rating Box

struct CompactRatingBox: View {
    let rating: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var color: Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return Color(red: 0.4, green: 0.7, blue: 0.2)
        case 5: return .green
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text("\(rating)")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? color : Color(UIColor.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(color, lineWidth: isSelected ? 0 : 1.5)
                )
        }
        .buttonStyle(.plain)
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
            if SpecialtyPackCatalog.findProcedure(by: tagId) != nil {
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
    @AppStorage("badgesEnabled") private var badgesEnabled = true

    let caseEntry: CaseEntry
    let attestorId: UUID?
    let users: [User]
    let attendings: [Attending]
    let facilities: [TrainingFacility]
    let evaluationFields: [EvaluationField]
    let evaluationsEnabled: Bool
    let evaluationsRequired: Bool
    let freeTextEnabled: Bool

    @Query private var allCaseMedia: [CaseMedia]

    /// Evaluation responses keyed by field ID
    /// Values: "true"/"false" for checkboxes, "1"-"5" for ratings
    @State private var evaluationResponses: [UUID: String] = [:]
    @State private var evaluationComment = ""
    @State private var showingRejectSheet = false
    @State private var selectedMedia: CaseMedia?

    /// Media attached to this case
    private var caseMediaItems: [CaseMedia] {
        allCaseMedia.filter { $0.caseEntryId == caseEntry.id }
    }

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

                    // Media Section (if case has media)
                    if !caseMediaItems.isEmpty {
                        Divider()
                        mediaSection
                    }

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
                RejectAttestationSheet(
                    caseEntry: caseEntry,
                    fellowName: fellowName,
                    rejectorId: attestorId,
                    onRejectionComplete: { dismiss() }
                )
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

    // MARK: - Media Section

    private var mediaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Media (\(caseMediaItems.count))")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(caseMediaItems) { media in
                        AttestationMediaThumbnail(media: media)
                            .onTapGesture {
                                selectedMedia = media
                            }
                    }
                }
            }
        }
        .sheet(item: $selectedMedia) { media in
            AttestationMediaDetailView(media: media)
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
    @State private var isDescriptionExpanded = false

    private var hasDescription: Bool {
        field.descriptionText != nil && !field.descriptionText!.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            switch field.fieldType {
            case .checkbox:
                checkboxView
            case .rating:
                ratingView
            default:
                checkboxView  // Fallback for future field types
            }

            // Expandable description
            if hasDescription {
                if isDescriptionExpanded {
                    Text(field.descriptionText!)
                        .font(.caption)
                        .foregroundColor(Color(UIColor.secondaryLabel))
                        .padding(.leading, field.fieldType == .checkbox ? 36 : 0)
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isDescriptionExpanded)
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

                // Info button for description
                if hasDescription {
                    Button {
                        isDescriptionExpanded.toggle()
                    } label: {
                        Image(systemName: isDescriptionExpanded ? "chevron.up.circle.fill" : "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
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

                // Info button for description
                if hasDescription {
                    Button {
                        isDescriptionExpanded.toggle()
                    } label: {
                        Image(systemName: isDescriptionExpanded ? "chevron.up.circle.fill" : "info.circle")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Rating boxes (1-5) with color gradient
            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { rating in
                    RatingBox(
                        rating: rating,
                        isSelected: Int(value) == rating,
                        onTap: { value = String(rating) }
                    )
                }
            }

            // Show selected rating label
            if let selectedRating = Int(value), selectedRating > 0 {
                Text(ratingLabel(selectedRating))
                    .font(.caption)
                    .foregroundColor(ratingColor(selectedRating))
                    .transition(.opacity)
            }
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

    private func ratingColor(_ rating: Int) -> Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return Color(red: 0.4, green: 0.7, blue: 0.2)  // Light green
        case 5: return .green
        default: return .gray
        }
    }
}

// MARK: - Rating Box Component

/// A tappable colored box for 1-5 ratings
struct RatingBox: View {
    let rating: Int
    let isSelected: Bool
    let onTap: () -> Void

    private var color: Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return Color(red: 0.4, green: 0.7, blue: 0.2)
        case 5: return .green
        default: return .gray
        }
    }

    var body: some View {
        Button(action: onTap) {
            Text("\(rating)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(isSelected ? .white : color)
                .frame(width: 44, height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? color : Color(UIColor.tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(color, lineWidth: isSelected ? 0 : 2)
                )
        }
        .buttonStyle(.plain)
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

    /// Message explaining why attestation is blocked
    private var attestationBlockedMessage: String? {
        guard evaluationsRequired else { return nil }
        let requiredFields = activeEvaluationFields.filter { $0.isRequired }
        var missingCount = 0
        for field in requiredFields {
            let value = evaluationResponses[field.id] ?? ""
            if field.fieldType == .checkbox && value != "true" { missingCount += 1 }
            if field.fieldType == .rating && (value.isEmpty || value == "0") { missingCount += 1 }
        }
        if missingCount > 0 {
            return "Complete \(missingCount) required evaluation\(missingCount == 1 ? "" : "s")"
        }
        return nil
    }

    var actionButtonsSection: some View {
        VStack(spacing: 12) {
            Button {
                attestCase()
            } label: {
                VStack(spacing: 2) {
                    if canAttest {
                        Text("Attest Case")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("I supervised this trainee during this procedure")
                            .font(.caption)
                            .opacity(0.9)
                    } else if let message = attestationBlockedMessage {
                        Text(message)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Evaluations required by program administrator")
                            .font(.caption)
                            .opacity(0.9)
                    } else {
                        Text("Attest Case")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("I supervised this trainee during this procedure")
                            .font(.caption)
                            .opacity(0.9)
                    }
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

            // Check and award badges
            checkAndAwardBadges(for: fellowId)
        }

        dismiss()
    }

    private func checkAndAwardBadges(for fellowId: UUID) {
        // Skip badge checking if badges are disabled
        guard badgesEnabled else { return }

        // Fetch all cases for this fellow
        let casesDescriptor = FetchDescriptor<CaseEntry>()
        guard let allCases = try? modelContext.fetch(casesDescriptor) else { return }

        // Fetch existing badges for this fellow
        let badgesDescriptor = FetchDescriptor<BadgeEarned>(
            predicate: #Predicate<BadgeEarned> { $0.fellowId == fellowId }
        )
        let existingBadges = (try? modelContext.fetch(badgesDescriptor)) ?? []

        // Check and award new badges
        let newBadges = BadgeService.shared.checkAndAwardBadges(
            for: fellowId,
            attestedCase: caseEntry,
            allCases: allCases,
            existingBadges: existingBadges,
            modelContext: modelContext
        )

        // Create notifications for earned badges
        for earned in newBadges {
            if let badge = BadgeCatalog.badge(withId: earned.badgeId) {
                let notification = Procedus.Notification(
                    userId: fellowId,
                    title: "Achievement Unlocked!",
                    message: "You earned the \"\(badge.title)\" badge!",
                    notificationType: NotificationType.badgeEarned.rawValue,
                    caseId: nil
                )
                modelContext.insert(notification)
            }
        }

        if !newBadges.isEmpty {
            try? modelContext.save()
        }
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
    var onRejectionComplete: (() -> Void)? = nil

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

        // Create database notification for the fellow
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            let notification = Procedus.Notification(
                userId: fellowId,
                title: "Case Rejected",
                message: "Your case was rejected. Reason: \(fullReason.prefix(200))",
                notificationType: NotificationType.caseRejected.rawValue,
                caseId: caseEntry.id
            )
            modelContext.insert(notification)
        }

        do {
            try modelContext.save()
        } catch {
            print("Error saving rejected case: \(error)")
            return
        }

        // Also send local push notification
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            PushNotificationManager.shared.notifyAttestationRejected(
                caseId: caseEntry.id,
                reason: fullReason,
                fellowId: fellowId
            )
        }

        dismiss()
        // Call completion handler to dismiss parent sheet too
        onRejectionComplete?()
    }
}

// MARK: - Attestation Media Thumbnail

struct AttestationMediaThumbnail: View {
    let media: CaseMedia

    private var thumbnailImage: UIImage? {
        if let thumbnailPath = media.thumbnailPath {
            return UIImage(contentsOfFile: thumbnailPath)
        }
        return UIImage(contentsOfFile: media.localPath)
    }

    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.tertiarySystemFill))
                    .frame(width: 80, height: 80)
                    .overlay {
                        Image(systemName: media.mediaType == .video ? "video.fill" : "photo")
                            .font(.title2)
                            .foregroundColor(Color(UIColor.secondaryLabel))
                    }
            }

            // Video indicator
            if media.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding(4)
                    }
                }
            }
        }
        .frame(width: 80, height: 80)
    }
}

// MARK: - Attestation Media Detail View

struct AttestationMediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let media: CaseMedia

    private var fullImage: UIImage? {
        UIImage(contentsOfFile: media.localPath)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "photo")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Unable to load media")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Preview

#Preview {
    AttestationQueueView()
        .environment(AppState())
}
