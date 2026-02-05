// MyImageLibraryView.swift
// Procedus - Unified
// Personal media library ("My Images") with search functionality

import SwiftUI
import SwiftData
import AVKit

// MARK: - Gallery Tab Selection

enum GalleryTabSelection: String, CaseIterable {
    case myGallery = "My Gallery"
    case teaching = "Teaching Files"
}

struct MyImageLibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \CaseMedia.createdAt, order: .reverse) private var allMedia: [CaseMedia]
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]
    @Query private var attendings: [Attending]

    @State private var selectedTab: GalleryTabSelection = .myGallery
    @State private var searchText = ""
    @State private var selectedMedia: CaseMedia?
    @State private var showingMediaDetail = false
    @State private var filterOption: MediaFilterOption = .all

    // MARK: - Computed Properties

    private var currentUserId: UUID {
        if appState.isIndividualMode {
            return getOrCreateIndividualUserId()
        }
        return appState.selectedFellowId ?? appState.currentUser?.id ?? UUID()
    }

    private var myMedia: [CaseMedia] {
        // Show media where either:
        // 1. ownerId matches current user (direct ownership)
        // 2. caseEntryId belongs to a case owned by current user (case ownership)
        let myCaseIds = Set(allCases.filter {
            $0.ownerId == currentUserId || $0.fellowId == currentUserId
        }.map { $0.id })

        return allMedia.filter { media in
            media.ownerId == currentUserId || myCaseIds.contains(media.caseEntryId)
        }
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

        // Apply search filter (title and labels are searchable)
        if !searchText.isEmpty {
            let lowercasedSearch = searchText.lowercased()
            result = result.filter { media in
                media.title.lowercased().contains(lowercasedSearch) ||
                media.searchTerms.contains { $0.lowercased().contains(lowercasedSearch) } ||
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
            .navigationTitle(selectedTab == .teaching ? "Teaching Files" : "My Gallery")
            .navigationBarHidden(true) // Hide nav bar - unified top bar is in FellowContentWrapper
            .sheet(item: $selectedMedia) { media in
                MediaFullDetailView(media: media, showCaseLink: true)
            }
        }
    }

    // MARK: - Gallery Tab Picker

    private var galleryTabPicker: some View {
        HStack(spacing: 0) {
            ForEach(GalleryTabSelection.allCases, id: \.self) { tab in
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
            // Search and filter bar
            searchAndFilterBar

            if filteredMedia.isEmpty {
                emptyStateView
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
                TextField("Search by title or label...", text: $searchText)
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
                    ForEach(MediaFilterOption.allCases) { option in
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

            Text("No Images Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ProcedusTheme.textPrimary)

            Text("Images you add to your cases will appear here.\nEdit a case to add media.")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Media List

    private var mediaList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Grouped by case
                ForEach(groupedByCase, id: \.caseEntry?.id) { group in
                    CaseMediaGroupView(
                        caseEntry: group.caseEntry,
                        media: group.media,
                        attendings: Array(attendings),
                        onMediaTap: { media in
                            selectedMedia = media
                        },
                        onDelete: { media in
                            deleteMedia(media)
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Helpers

    private func countForFilter(_ option: MediaFilterOption) -> Int {
        switch option {
        case .all: return myMedia.count
        case .images: return myMedia.filter { $0.mediaType == .image }.count
        case .videos: return myMedia.filter { $0.mediaType == .video }.count
        case .shared: return myMedia.filter { $0.isSharedWithFellowship }.count
        }
    }

    private func deleteMedia(_ media: CaseMedia) {
        MediaStorageService.shared.deleteMedia(
            localPath: media.localPath,
            thumbnailPath: media.thumbnailPath
        )
        modelContext.delete(media)
        try? modelContext.save()
    }

    private func getOrCreateIndividualUserId() -> UUID {
        let key = "individualUserUUID"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }
}

// MARK: - Media Filter Option

enum MediaFilterOption: String, CaseIterable, Identifiable {
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
        case .shared: return "Shared"
        }
    }
}

// MARK: - Filter Pill

struct FilterPill: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(isSelected ? .semibold : .regular)
                Text("(\(count))")
                    .font(.caption)
            }
            .foregroundStyle(isSelected ? .white : ProcedusTheme.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? ProcedusTheme.primary : Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }
}

// MARK: - Stat Item

struct StatItem: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(ProcedusTheme.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }
}

// MARK: - Case Media Group View

struct CaseMediaGroupView: View {
    let caseEntry: CaseEntry?
    let media: [CaseMedia]
    var attendings: [Attending] = []
    let onMediaTap: (CaseMedia) -> Void
    let onDelete: (CaseMedia) -> Void

    private var procedureName: String {
        guard let entry = caseEntry,
              let firstProcId = entry.procedureTagIds.first,
              let procedure = SpecialtyPackCatalog.findProcedure(by: firstProcId) else {
            return "Case"
        }
        return procedure.title
    }

    private var attendingName: String? {
        guard let entry = caseEntry,
              let attendingId = entry.attendingId else { return nil }
        return attendings.first { $0.id == attendingId }?.name
    }

    private var caseDate: String {
        guard let entry = caseEntry else { return "" }
        let weekLabel = entry.weekBucket.toWeekTimeframeLabel()
        if weekLabel != entry.weekBucket {
            return weekLabel
        }
        return entry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Case header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(procedureName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                            .lineLimit(1)
                        if let attending = attendingName {
                            Text("•")
                                .foregroundStyle(ProcedusTheme.textTertiary)
                            Text(attending)
                                .font(.subheadline)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Text(caseDate)
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
                Spacer()
                Text("\(media.count) item\(media.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
            }

            // Media grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(media) { item in
                    MediaGridThumbnail(media: item)
                        .onTapGesture {
                            onMediaTap(item)
                        }
                        .contextMenu {
                            if item.isSharedWithFellowship {
                                Label("Shared in Teaching Files", systemImage: "person.2.fill")
                            }
                            Button(role: .destructive) {
                                onDelete(item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }
}

// MARK: - Media Grid Thumbnail

struct MediaGridThumbnail: View {
    let media: CaseMedia

    @State private var thumbnail: UIImage?

    var body: some View {
        VStack(spacing: 4) {
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

            // Title under thumbnail
            if !media.title.isEmpty {
                Text(media.title)
                    .font(.system(size: 10))
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .lineLimit(1)
                    .frame(width: 80)
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

// MARK: - Media Full Detail View

struct MediaFullDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(AppState.self) private var appState

    let media: CaseMedia
    let showCaseLink: Bool
    var isTeachingFiles: Bool = false

    @Query private var allCases: [CaseEntry]
    @Query private var allComments: [MediaComment]
    @Query private var allAttendings: [Attending]
    @Query private var allUsers: [User]

    @State private var fullImage: UIImage?
    @State private var player: AVPlayer?
    @State private var isEditingLabels = false
    @State private var editedLabels: [String] = []
    @State private var isShared: Bool = false
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
        if appState.isIndividualMode {
            return getOrCreateIndividualUserId()
        }
        if appState.userRole == .attending {
            return appState.selectedAttendingId ?? appState.currentUser?.id ?? UUID()
        }
        return appState.selectedFellowId ?? appState.currentUser?.id ?? UUID()
    }

    private var currentUserName: String {
        if appState.userRole == .attending {
            if let attendingId = appState.selectedAttendingId,
               let attending = allAttendings.first(where: { $0.id == attendingId }) {
                return attending.fullName
            }
            return appState.currentUser?.fullName ?? "Attending"
        }
        return appState.currentUser?.fullName ?? "Unknown"
    }

    private var currentUserRole: UserRole {
        appState.userRole
    }

    /// Only fellows can edit labels - not attendings
    private var canEditLabels: Bool {
        currentUserRole == .fellow
    }

    /// Only the owner (fellow) can toggle share status
    private var canToggleShare: Bool {
        currentUserRole == .fellow && media.ownerId == currentUserId
    }

    /// Check if current user is the media owner
    private var isOwner: Bool {
        media.ownerId == currentUserId
    }

    /// Get case date display — show the week range the fellow input, not the exact date
    private var caseDateText: String {
        guard let caseEntry = linkedCase else { return "Unknown" }
        let weekLabel = caseEntry.weekBucket.toWeekTimeframeLabel()
        // If weekBucket conversion succeeds (contains "–"), use it; otherwise fall back
        if weekLabel != caseEntry.weekBucket {
            return weekLabel
        }
        return caseEntry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    /// Get attending name for the case
    private var attendingName: String? {
        guard let caseEntry = linkedCase,
              let attendingId = caseEntry.attendingId else { return nil }
        return allAttendings.first { $0.id == attendingId }?.fullName
    }

    /// Get fellow name for the case
    private var fellowName: String? {
        guard let caseEntry = linkedCase,
              let fellowId = caseEntry.fellowId else { return nil }
        return allUsers.first { $0.id == fellowId }?.fullName
    }

    /// Suggested labels based on procedure category (determined by procedure ID prefix)
    private var suggestedLabels: [String] {
        guard let caseEntry = linkedCase,
              let firstProcId = caseEntry.procedureTagIds.first else {
            return defaultSuggestedLabels
        }

        // Determine category by procedure ID prefix
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
        "Bifurcation", "Calcified", "Dissection", "Perforation",
        "No Reflow", "Good Outcome", "Challenging"
    ]

    private let cardiacImagingLabels = [
        "Rare Finding", "Teaching Example", "Classic Finding", "Artifact",
        "Cardiomyopathy", "Valvular Disease", "Pericardial", "Congenital",
        "Wall Motion", "LV Function", "RV Abnormal", "Mass/Thrombus",
        "Strain Pattern", "Diastolic Dysfunction", "Good Image Quality"
    ]

    private let epLabels = [
        "Complication", "Interesting Case", "Teaching Example", "Rare Arrhythmia",
        "Ablation", "Device", "SVT", "VT", "AF Ablation",
        "Lead Extraction", "CRT Response", "Mapping", "Access Issue",
        "Good Outcome", "Challenging"
    ]

    private let defaultSuggestedLabels = [
        "Teaching Example", "Interesting Case", "Rare Finding", "Complication",
        "Good Outcome", "Challenging", "Classic Finding", "Artifact"
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
                    } else if media.mediaType == .video, let player = player {
                        VideoPlayer(player: player)
                            .aspectRatio(
                                (media.width != nil && media.height != nil)
                                    ? CGFloat(media.width!) / CGFloat(media.height!) : 16.0 / 9.0,
                                contentMode: .fit
                            )
                            .cornerRadius(12)
                    } else if media.mediaType == .video {
                        ProgressView()
                            .frame(height: 200)
                    } else {
                        ProgressView()
                            .frame(height: 200)
                    }

                    // Title
                    if !media.title.isEmpty {
                        Text(media.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Labels section (only for fellows)
                    if canEditLabels {
                        labelsSection
                    } else {
                        viewOnlyLabelsSection
                    }

                    // Comments section (visible in Teaching Files or when there are comments)
                    if isTeachingFiles || !mediaComments.isEmpty {
                        commentsSection
                    }

                    // Collapsible Info section (includes linked case)
                    collapsibleInfoSection
                }
                .padding()
            }
            .navigationTitle("Media Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        player?.pause()
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadImage()
                if media.mediaType == .video {
                    let url = MediaStorageService.shared.fullURL(for: media.localPath)
                    player = AVPlayer(url: url)
                }
                editedLabels = media.searchTerms
                isShared = media.isSharedWithFellowship
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
        }
    }

    // MARK: - Labels Section (Editable for Fellows)

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Labels")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if isOwner {
                    Button(isEditingLabels ? "Done" : "Edit") {
                        if isEditingLabels {
                            saveLabels()
                        }
                        isEditingLabels.toggle()
                        showingSuggestedLabels = false
                    }
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.accent)
                }
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

            // Share toggle (only for owner fellows)
            if canToggleShare {
                Divider()
                    .padding(.vertical, 4)
                Toggle(isOn: $isShared) {
                    Label("Share in Teaching Files", systemImage: "person.2.fill")
                        .font(.subheadline)
                }
                .onChange(of: isShared) { _, newValue in
                    media.isSharedWithFellowship = newValue
                    try? modelContext.save()
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - View-Only Labels (for Attendings)

    private var viewOnlyLabelsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Labels")
                .font(.subheadline)
                .fontWeight(.medium)

            if media.searchTerms.isEmpty {
                Text("No labels")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
                    .italic()
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(media.searchTerms, id: \.self) { label in
                        LabelChip(label: label, isEditing: false) {}
                    }
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Collapsible Info Section

    private var collapsibleInfoSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header (always visible, tappable)
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

            // Expanded content
            if isInfoExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()

                    // Uploader (in Teaching Files)
                    if isTeachingFiles {
                        HStack {
                            Text("Uploaded by")
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Spacer()
                            Text(media.ownerName)
                                .font(.subheadline)
                        }
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

                    // Show case date range instead of date added
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

                    // Cloud Upload Status
                    HStack {
                        Text("Cloud Status")
                            .foregroundStyle(ProcedusTheme.textSecondary)
                        Spacer()
                        Label(media.uploadStatus.displayName, systemImage: media.uploadStatus.iconName)
                            .font(.subheadline)
                            .foregroundStyle(media.uploadStatus.color)
                    }

                    if media.uploadStatus == .failed, let errorMsg = media.lastUploadError {
                        HStack(alignment: .top) {
                            Text("Error")
                                .foregroundStyle(ProcedusTheme.textSecondary)
                            Spacer()
                            Text(errorMsg)
                                .font(.caption)
                                .foregroundStyle(.red)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    // Linked Case info (merged into Info section)
                    if showCaseLink, let caseEntry = linkedCase {
                        Divider()
                            .padding(.vertical, 4)

                        Text("Linked Case")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(ProcedusTheme.textSecondary)

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundStyle(ProcedusTheme.textSecondary)
                                .font(.caption)
                            Text(caseDateText)
                                .font(.subheadline)
                            Spacer()
                        }

                        if let fellow = fellowName {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(ProcedusTheme.textSecondary)
                                    .font(.caption)
                                Text(fellow)
                                    .font(.subheadline)
                                Text("(Fellow)")
                                    .font(.caption)
                                    .foregroundStyle(ProcedusTheme.textTertiary)
                                Spacer()
                            }
                        }

                        if let attending = attendingName {
                            HStack {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(ProcedusTheme.textSecondary)
                                    .font(.caption)
                                Text(attending)
                                    .font(.subheadline)
                                Text("(Attending)")
                                    .font(.caption)
                                    .foregroundStyle(ProcedusTheme.textTertiary)
                                Spacer()
                            }
                        }

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

    // MARK: - Helper Methods

    private func loadImage() {
        if media.mediaType == .image {
            fullImage = MediaStorageService.shared.loadImage(from: media.localPath)
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
            authorRole: currentUserRole,
            text: text
        )
        modelContext.insert(comment)
        try? modelContext.save()

        // Send notification to media owner if not self
        if media.ownerId != currentUserId {
            sendCommentNotification(toUserId: media.ownerId, commentText: text, isOwnerNotification: true)
        }

        // Send notification to all previous unique commenters (excluding self and media owner)
        let previousCommenters = Set(
            mediaComments
                .map { $0.authorId }
                .filter { $0 != currentUserId && $0 != media.ownerId }
        )
        for commenterId in previousCommenters {
            sendCommentNotification(toUserId: commenterId, commentText: text, isOwnerNotification: false)
        }

        newCommentText = ""
    }

    private func sendCommentNotification(toUserId: UUID, commentText: String, isOwnerNotification: Bool) {
        let title = isOwnerNotification ? "Comment on Your Teaching File" : "New Reply on Teaching File"
        let message = isOwnerNotification
            ? "\(currentUserName) commented on your case:\n\(commentText)"
            : "\(currentUserName) replied to a discussion you joined:\n\(commentText)"
        let notification = Notification(
            userId: toUserId,
            title: title,
            message: message,
            notificationType: NotificationType.teachingFileComment.rawValue
        )
        notification.senderId = currentUserId
        notification.senderName = currentUserName
        notification.senderRole = currentUserRole
        modelContext.insert(notification)
        try? modelContext.save()
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private func getOrCreateIndividualUserId() -> UUID {
        let key = "individualUserUUID"
        if let uuidString = UserDefaults.standard.string(forKey: key),
           let uuid = UUID(uuidString: uuidString) {
            return uuid
        }
        let newUUID = UUID()
        UserDefaults.standard.set(newUUID.uuidString, forKey: key)
        return newUUID
    }
}

// MARK: - Comment Bubble

struct CommentBubble: View {
    let comment: MediaComment
    let isOwn: Bool

    var body: some View {
        VStack(alignment: isOwn ? .trailing : .leading, spacing: 4) {
            Text(comment.text)
                .font(.subheadline)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isOwn ? ProcedusTheme.primary.opacity(0.15) : Color(UIColor.secondarySystemFill))
                .cornerRadius(12)

            HStack(spacing: 4) {
                Text(comment.authorName)
                    .font(.caption2)
                    .fontWeight(.medium)
                if comment.authorRole == .attending {
                    Text("• Attending")
                        .font(.caption2)
                        .foregroundStyle(ProcedusTheme.textTertiary)
                }
            }
            .foregroundStyle(ProcedusTheme.textSecondary)

            Text(comment.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(ProcedusTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: isOwn ? .trailing : .leading)
    }
}

// MARK: - Procedure Bubble

struct ProcedureBubble: View {
    let procedure: ProcedureTag

    var body: some View {
        Text(procedure.title)
            .font(.caption2)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(procedureColor.opacity(0.15))
            .foregroundStyle(procedureColor)
            .cornerRadius(8)
    }

    private var procedureColor: Color {
        let procId = procedure.id.lowercased()
        if procId.hasPrefix("ic-") {
            return .red
        } else if procId.hasPrefix("img-") || procId.hasPrefix("echo-") || procId.hasPrefix("ct-") || procId.hasPrefix("mri-") {
            return .blue
        } else if procId.hasPrefix("ep-") {
            return .purple
        } else if procId.hasPrefix("gi-") {
            return .orange
        }
        return ProcedusTheme.primary
    }
}

// MARK: - Label Chip

struct LabelChip: View {
    let label: String
    let isEditing: Bool
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            if isEditing {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(UIColor.tertiarySystemFill))
        .foregroundStyle(ProcedusTheme.textPrimary)
        .cornerRadius(12)
    }
}

// MARK: - Add Label Button

struct AddLabelButton: View {
    let onAdd: (String) -> Void

    @State private var isAdding = false
    @State private var newLabel = ""

    var body: some View {
        if isAdding {
            HStack(spacing: 4) {
                TextField("Label", text: $newLabel)
                    .font(.caption)
                    .textFieldStyle(.plain)
                    .frame(width: 80)
                Button {
                    onAdd(newLabel.trimmingCharacters(in: .whitespaces))
                    newLabel = ""
                    isAdding = false
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.gray.opacity(0.15))
            .cornerRadius(12)
        } else {
            Button {
                isAdding = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption)
                    Text("Add")
                        .font(.caption)
                }
                .foregroundStyle(ProcedusTheme.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
}

// FlowLayout is defined in AttestationQueueView.swift
