// AttendingImageLibraryView.swift
// Procedus - Unified
// Media library for attendings - view images from cases they attest

import SwiftUI
import SwiftData

// MARK: - Attending Gallery Tab Selection

enum AttendingGalleryTabSelection: String, CaseIterable {
    case myGallery = "My Gallery"
    case teaching = "Teaching Files"
}

struct AttendingImageLibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \CaseMedia.createdAt, order: .reverse) private var allMedia: [CaseMedia]
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query private var allUsers: [User]
    @Query private var attendings: [Attending]

    @State private var selectedTab: AttendingGalleryTabSelection = .myGallery
    @State private var searchText = ""
    @State private var selectedMedia: CaseMedia?
    @State private var filterOption: AttendingMediaFilterOption = .all

    // MARK: - Computed Properties

    private var currentAttendingId: UUID? {
        appState.selectedAttendingId ?? appState.currentUser?.id
    }

    /// Cases assigned to this attending for attestation
    private var myCases: [CaseEntry] {
        guard let attendingId = currentAttendingId else { return [] }
        return allCases.filter { $0.attendingId == attendingId || $0.supervisorId == attendingId }
    }

    /// Media from cases assigned to this attending
    private var myMedia: [CaseMedia] {
        let myCaseIds = Set(myCases.map { $0.id })
        return allMedia.filter { myCaseIds.contains($0.caseEntryId) }
    }

    private var filteredMedia: [CaseMedia] {
        var result = myMedia

        // Apply type filter
        switch filterOption {
        case .all:
            break
        case .images:
            result = result.filter { $0.mediaType == .image }
        case .videos:
            result = result.filter { $0.mediaType == .video }
        case .shared:
            result = result.filter { $0.isSharedWithFellowship }
        }

        // Apply search filter
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { media in
                media.searchTerms.contains { $0.lowercased().contains(lowercasedSearch) } ||
                media.ownerName.lowercased().contains(lowercasedSearch) ||
                media.fileName.lowercased().contains(lowercasedSearch)
            }
        }

        return result
    }

    private var groupedByCase: [(caseEntry: CaseEntry?, media: [CaseMedia])] {
        let grouped = Dictionary(grouping: filteredMedia) { $0.caseEntryId }
        return grouped.map { caseId, mediaItems in
            let caseEntry = allCases.first { $0.id == caseId }
            return (caseEntry, mediaItems.sorted { $0.createdAt > $1.createdAt })
        }.sorted { lhs, rhs in
            let lhsDate = lhs.media.first?.createdAt ?? Date.distantPast
            let rhsDate = rhs.media.first?.createdAt ?? Date.distantPast
            return lhsDate > rhsDate
        }
    }

    /// Count of shared media (Teaching Files)
    private var sharedMediaCount: Int {
        allMedia.filter { $0.isSharedWithFellowship }.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // My Gallery / Teaching Files toggle
                galleryTabPicker

                // Content based on selection
                if selectedTab == .teaching {
                    SharedImageLibraryContent()
                } else {
                    myGalleryContent
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(item: $selectedMedia) { media in
                AttendingMediaDetailView(media: media, users: allUsers, attendings: attendings, allCases: allCases)
            }
        }
    }

    // MARK: - Gallery Tab Picker

    private var galleryTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(AttendingGalleryTabSelection.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab == .myGallery ? "photo.fill" : "person.2.fill")
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .semibold : .regular)

                        // Show count for Teaching Files
                        if tab == .teaching && sharedMediaCount > 0 && selectedTab != .teaching {
                            Text("\(sharedMediaCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(colorScheme == .dark ? .white : ProcedusTheme.primary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(colorScheme == .dark ? Color(UIColor.tertiarySystemFill) : ProcedusTheme.primary.opacity(0.15)))
                        }
                    }
                    .foregroundStyle(selectedTab == tab ? .white : (colorScheme == .dark ? Color(UIColor.secondaryLabel) : Color(UIColor.darkGray)))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? ProcedusTheme.primary
                            : Color.clear
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .background(colorScheme == .dark ? Color(UIColor.secondarySystemBackground) : .white)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(UIColor.separator).opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - My Gallery Content

    private var myGalleryContent: some View {
        VStack(spacing: 0) {
            searchAndFilterBar

            if myMedia.isEmpty {
                emptyStateView
            } else if filteredMedia.isEmpty {
                noResultsView
            } else {
                mediaList
            }
        }
    }

    // MARK: - Search and Filter Bar

    private var searchAndFilterBar: some View {
        VStack(spacing: 12) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(ProcedusTheme.textTertiary)
                TextField("Search by label or fellow...", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ProcedusTheme.textTertiary)
                    }
                }
            }
            .padding(10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(10)

            // Filter pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AttendingMediaFilterOption.allCases) { option in
                        FilterPill(
                            title: option.displayName,
                            count: countForFilter(option),
                            isSelected: filterOption == option
                        ) {
                            withAnimation {
                                filterOption = option
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(ProcedusTheme.textTertiary)

            Text("No Case Images")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ProcedusTheme.textPrimary)

            Text("Images from cases assigned to you\nwill appear here.")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    private var noResultsView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(ProcedusTheme.textTertiary)

            Text("No Results")
                .font(.title3)
                .fontWeight(.medium)

            Text("Try a different search term or filter")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)

            Button("Clear Filters") {
                searchText = ""
                filterOption = .all
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .padding()
    }

    // MARK: - Media List

    private var mediaList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(groupedByCase, id: \.caseEntry?.id) { group in
                    AttendingCaseMediaGroupView(
                        caseEntry: group.caseEntry,
                        media: group.media,
                        users: allUsers,
                        onMediaTap: { media in
                            selectedMedia = media
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func countForFilter(_ option: AttendingMediaFilterOption) -> Int {
        switch option {
        case .all: return myMedia.count
        case .images: return myMedia.filter { $0.mediaType == .image }.count
        case .videos: return myMedia.filter { $0.mediaType == .video }.count
        case .shared: return myMedia.filter { $0.isSharedWithFellowship }.count
        }
    }
}

// MARK: - Filter Options

enum AttendingMediaFilterOption: String, CaseIterable, Identifiable {
    case all
    case images
    case videos
    case shared

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .images: return "Images"
        case .videos: return "Videos"
        case .shared: return "Teaching Files"
        }
    }
}

// MARK: - Attending Case Media Group View

struct AttendingCaseMediaGroupView: View {
    let caseEntry: CaseEntry?
    let media: [CaseMedia]
    let users: [User]
    let onMediaTap: (CaseMedia) -> Void

    private var fellowName: String {
        guard let caseEntry = caseEntry else { return "Unknown" }
        if let fellowId = caseEntry.fellowId ?? caseEntry.ownerId {
            return users.first { $0.id == fellowId }?.displayName ?? "Unknown Fellow"
        }
        return "Unknown Fellow"
    }

    private var procedureName: String {
        guard let caseEntry = caseEntry,
              let firstProcId = caseEntry.procedureTagIds.first,
              let procedure = SpecialtyPackCatalog.findProcedure(by: firstProcId) else {
            return "Case"
        }
        return procedure.title
    }

    private var caseDate: String {
        guard let caseEntry = caseEntry else { return "" }
        return caseEntry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with procedure and fellow info
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(procedureName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text("•")
                            .foregroundStyle(ProcedusTheme.textTertiary)
                        Text(fellowName)
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Text(caseDate)
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textTertiary)
                }
                Spacer()
                Text("\(media.count)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ProcedusTheme.primary.opacity(0.1))
                    .foregroundStyle(ProcedusTheme.primary)
                    .cornerRadius(8)
            }

            // Media grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(media) { item in
                    AttendingMediaThumbnailView(media: item)
                        .onTapGesture {
                            onMediaTap(item)
                        }
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Attending Media Thumbnail View

struct AttendingMediaThumbnailView: View {
    let media: CaseMedia

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: media.mediaType.systemImage)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    )
            }

            // Video indicator
            if media.mediaType == .video {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "play.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .shadow(radius: 2)
                            .padding(4)
                    }
                }
            }

            // Shared indicator
            if media.isSharedWithFellowship {
                VStack {
                    HStack {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.white)
                            .padding(3)
                            .background(ProcedusTheme.primary)
                            .cornerRadius(4)
                            .padding(4)
                        Spacer()
                    }
                    Spacer()
                }
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        if let thumbPath = media.thumbnailPath {
            thumbnail = MediaStorageService.shared.loadThumbnail(from: thumbPath)
        } else {
            thumbnail = MediaStorageService.shared.loadImage(from: media.localPath)
        }
    }
}

// MARK: - Attending Media Detail View

struct AttendingMediaDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let media: CaseMedia
    let users: [User]
    let attendings: [Attending]
    let allCases: [CaseEntry]

    @Query private var allComments: [MediaComment]

    @State private var fullImage: UIImage?
    @State private var isEditingLabels = false
    @State private var editedLabels: [String] = []
    @State private var isInfoExpanded: Bool = false
    @State private var newCommentText: String = ""
    @State private var showingSuggestedLabels: Bool = false

    private var linkedCase: CaseEntry? {
        allCases.first { $0.id == media.caseEntryId }
    }

    private var mediaComments: [MediaComment] {
        allComments.filter { $0.mediaId == media.id && !$0.isDeleted }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var currentUserId: UUID {
        appState.selectedAttendingId ?? appState.currentUser?.id ?? UUID()
    }

    private var currentUserName: String {
        appState.currentUser?.fullName ?? "Attending"
    }

    private var fellowName: String {
        guard let caseEntry = linkedCase,
              let fellowId = caseEntry.fellowId ?? caseEntry.ownerId else { return "Unknown" }
        return users.first { $0.id == fellowId }?.displayName ?? "Unknown Fellow"
    }

    private var caseDateText: String {
        if let caseDate = media.caseDate {
            return caseDate.formatted(date: .abbreviated, time: .omitted)
        }
        guard let caseEntry = linkedCase else { return "Unknown" }
        return caseEntry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    /// Suggested labels based on procedure category
    private var suggestedLabels: [String] {
        guard let caseEntry = linkedCase,
              let firstProcId = caseEntry.procedureTagIds.first else {
            return defaultSuggestedLabels
        }

        let procId = firstProcId.lowercased()
        if procId.hasPrefix("ic-") {
            return interventionalCardioLabels
        } else if procId.hasPrefix("img-") || procId.hasPrefix("echo-") || procId.hasPrefix("ct-") || procId.hasPrefix("mri-") {
            return cardiacImagingLabels
        } else if procId.hasPrefix("ep-") {
            return epLabels
        }

        return defaultSuggestedLabels
    }

    private let interventionalCardioLabels = [
        "Complication", "Interesting Case", "Rare Finding", "Teaching Example",
        "Difficult Access", "Complex Anatomy", "Acute MI", "CTO",
        "Bifurcation", "Calcified", "Dissection", "Good Outcome"
    ]

    private let cardiacImagingLabels = [
        "Rare Finding", "Teaching Example", "Classic Finding", "Artifact",
        "Cardiomyopathy", "Valvular Disease", "Pericardial", "Congenital",
        "Wall Motion", "LV Function", "RV Abnormal", "Mass/Thrombus"
    ]

    private let epLabels = [
        "Complication", "Interesting Case", "Teaching Example", "Rare Arrhythmia",
        "Ablation", "Device", "SVT", "VT", "AF Ablation",
        "Lead Extraction", "CRT Response", "Good Outcome"
    ]

    private let defaultSuggestedLabels = [
        "Teaching Example", "Interesting Case", "Rare Finding", "Complication",
        "Good Outcome", "Challenging", "Classic Finding"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Image display
                    if let image = fullImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    } else if media.mediaType == .video {
                        videoPlaceholder
                    } else {
                        ProgressView()
                            .frame(height: 200)
                    }

                    // Labels section (attendings can edit)
                    labelsSection

                    // Collapsible Info section
                    collapsibleInfoSection

                    // Comments section
                    commentsSection

                    // Case link
                    if let caseEntry = linkedCase {
                        caseLinkSection(caseEntry)
                    }
                }
                .padding()
            }
            .navigationTitle("Media Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                loadImage()
                editedLabels = media.searchTerms
            }
        }
    }

    private var videoPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "video.fill")
                .font(.system(size: 50))
                .foregroundStyle(ProcedusTheme.textSecondary)
            Text("Video")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
            if let duration = media.durationSeconds {
                Text(formatDuration(duration))
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Labels Section (Attendings can edit)

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Labels")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Button(isEditingLabels ? "Done" : "Edit") {
                    if isEditingLabels {
                        saveLabels()
                    }
                    isEditingLabels.toggle()
                    showingSuggestedLabels = false
                }
                .font(.subheadline)
            }

            if media.searchTerms.isEmpty && !isEditingLabels {
                Text("No labels added")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
                    .italic()
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(editedLabels, id: \.self) { label in
                        LabelChip(label: label, isEditing: isEditingLabels) {
                            editedLabels.removeAll { $0 == label }
                        }
                    }
                    if isEditingLabels {
                        AddLabelButton { newLabel in
                            if !newLabel.isEmpty && !editedLabels.contains(newLabel) {
                                editedLabels.append(newLabel)
                            }
                        }
                    }
                }
            }

            // Suggested labels when editing
            if isEditingLabels {
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation { showingSuggestedLabels.toggle() }
                    } label: {
                        HStack {
                            Text("Suggested Labels")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Image(systemName: showingSuggestedLabels ? "chevron.up" : "chevron.down")
                                .font(.caption2)
                                .foregroundStyle(ProcedusTheme.textTertiary)
                        }
                    }

                    if showingSuggestedLabels {
                        FlowLayout(spacing: 6) {
                            ForEach(suggestedLabels.filter { !editedLabels.contains($0) }, id: \.self) { label in
                                Button {
                                    editedLabels.append(label)
                                } label: {
                                    Text(label)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(UIColor.secondarySystemFill))
                                        .foregroundStyle(ProcedusTheme.textSecondary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Collapsible Info Section

    private var collapsibleInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation { isInfoExpanded.toggle() }
            } label: {
                HStack {
                    Text("Info")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(ProcedusTheme.textPrimary)
                    Spacer()
                    Image(systemName: isInfoExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textTertiary)
                }
                .padding()
            }

            if isInfoExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    HStack {
                        Text("Fellow")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Spacer()
                        Text(fellowName)
                            .font(.subheadline)
                    }

                    HStack {
                        Text("Type")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Spacer()
                        Label(media.mediaType.displayName, systemImage: media.mediaType.systemImage)
                            .font(.subheadline)
                    }

                    HStack {
                        Text("Size")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Spacer()
                        Text(MediaStorageService.shared.formattedFileSize(media.fileSizeBytes))
                            .font(.subheadline)
                    }

                    HStack {
                        Text("Case Date")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Spacer()
                        Text(caseDateText)
                            .font(.subheadline)
                    }

                    if media.redactionApplied {
                        HStack {
                            Text("PHI Redacted")
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                    }
                }
                .padding([.horizontal, .bottom])
            }
        }
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Comments Section

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments")
                .font(.subheadline)
                .fontWeight(.medium)

            if mediaComments.isEmpty {
                Text("No comments yet")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
                    .italic()
                    .padding(.vertical, 4)
            } else {
                ForEach(mediaComments) { comment in
                    CommentBubble(comment: comment, isOwn: comment.authorId == currentUserId)
                }
            }

            // Add comment input
            HStack(spacing: 8) {
                TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(8)
                    .lineLimit(1...3)

                Button {
                    addComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? ProcedusTheme.textTertiary
                            : ProcedusTheme.primary)
                }
                .disabled(newCommentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Linked Case Section

    private func caseLinkSection(_ caseEntry: CaseEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Linked Case")
                .font(.subheadline)
                .fontWeight(.medium)

            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .font(.caption)
                Text(caseDateText)
                    .font(.subheadline)
                Spacer()
            }

            // Fellow
            HStack {
                Image(systemName: "person.fill")
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .font(.caption)
                Text(fellowName)
                    .font(.subheadline)
                Spacer()
            }

            // Procedure bubbles
            if !caseEntry.procedureTagIds.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(caseEntry.procedureTagIds.prefix(4), id: \.self) { procId in
                        if let procedure = SpecialtyPackCatalog.findProcedure(by: procId) {
                            ProcedureBubble(procedure: procedure)
                        }
                    }
                    if caseEntry.procedureTagIds.count > 4 {
                        Text("+\(caseEntry.procedureTagIds.count - 4)")
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color(UIColor.tertiarySystemFill))
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Helper Methods

    private func loadImage() {
        if media.mediaType == .image {
            fullImage = MediaStorageService.shared.loadImage(from: media.localPath)
        } else if let thumbPath = media.thumbnailPath {
            fullImage = MediaStorageService.shared.loadThumbnail(from: thumbPath)
        }
    }

    private func saveLabels() {
        media.searchTerms = editedLabels
        try? modelContext.save()
    }

    private func addComment() {
        let text = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let comment = MediaComment(
            mediaId: media.id,
            authorId: currentUserId,
            authorName: currentUserName,
            authorRole: .attending,
            text: text
        )
        modelContext.insert(comment)
        try? modelContext.save()

        // Send notification to uploader if not self
        if media.ownerId != currentUserId {
            sendCommentNotification()
        }

        newCommentText = ""
    }

    private func sendCommentNotification() {
        let notification = Notification(
            userId: media.ownerId,
            title: "New Comment",
            message: "\(currentUserName) commented on your image",
            notificationType: "teachingFileComment"
        )
        notification.senderId = currentUserId
        notification.senderName = currentUserName
        notification.senderRole = .attending
        modelContext.insert(notification)
        try? modelContext.save()
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
