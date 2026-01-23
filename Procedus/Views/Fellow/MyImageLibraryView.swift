// MyImageLibraryView.swift
// Procedus - Unified
// Personal media library ("My Images") with search functionality

import SwiftUI
import SwiftData

struct MyImageLibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CaseMedia.createdAt, order: .reverse) private var allMedia: [CaseMedia]
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]

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
        allMedia.filter { $0.ownerId == currentUserId }
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter bar
                searchAndFilterBar

                if filteredMedia.isEmpty {
                    emptyStateView
                } else {
                    mediaList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("My Images")
            .sheet(item: $selectedMedia) { media in
                MediaFullDetailView(media: media, showCaseLink: true)
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
                TextField("Search by label...", text: $searchText)
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
                // Stats header
                statsHeader

                // Grouped by case
                ForEach(groupedByCase, id: \.caseEntry?.id) { group in
                    CaseMediaGroupView(
                        caseEntry: group.caseEntry,
                        media: group.media,
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

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 24) {
            StatItem(value: "\(myMedia.count)", label: "Total")
            StatItem(value: "\(myMedia.filter { $0.mediaType == .image }.count)", label: "Images")
            StatItem(value: "\(myMedia.filter { $0.mediaType == .video }.count)", label: "Videos")
            StatItem(value: "\(myMedia.filter { $0.isSharedWithFellowship }.count)", label: "Shared")
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
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
    let onMediaTap: (CaseMedia) -> Void
    let onDelete: (CaseMedia) -> Void

    private var caseTitle: String {
        guard let entry = caseEntry else { return "Unknown Case" }
        let procedureNames = entry.procedureTagIds.prefix(2).compactMap { tagId in
            SpecialtyPackCatalog.findProcedure(by: tagId)?.title
        }
        if procedureNames.isEmpty {
            return "Case"
        }
        return procedureNames.joined(separator: ", ")
    }

    private var caseDate: String {
        guard let entry = caseEntry else { return "" }
        return entry.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Case header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(caseTitle)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(ProcedusTheme.textPrimary)
                        .lineLimit(1)
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

// MARK: - Media Full Detail View

struct MediaFullDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let media: CaseMedia
    let showCaseLink: Bool

    @Query private var allCases: [CaseEntry]

    @State private var fullImage: UIImage?
    @State private var isEditingLabels = false
    @State private var editedLabels: [String] = []
    @State private var isShared: Bool = false

    private var linkedCase: CaseEntry? {
        allCases.first { $0.id == media.caseEntryId }
    }

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

                    // Labels section
                    labelsSection

                    // Info section
                    infoSection

                    // Case link
                    if showCaseLink, let caseEntry = linkedCase {
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
                isShared = media.isSharedWithFellowship
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
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Info")
                .font(.subheadline)
                .fontWeight(.medium)

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
                Text("Added")
                    .foregroundStyle(ProcedusTheme.textSecondary)
                Spacer()
                Text(media.createdAt.formatted(date: .abbreviated, time: .shortened))
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

            // Share toggle
            Toggle(isOn: $isShared) {
                Label("Share in Teaching Files", systemImage: "person.2.fill")
                    .font(.subheadline)
            }
            .onChange(of: isShared) { _, newValue in
                media.isSharedWithFellowship = newValue
                try? modelContext.save()
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    private func caseLinkSection(_ caseEntry: CaseEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked Case")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundStyle(ProcedusTheme.primary)
                VStack(alignment: .leading) {
                    Text(caseEntry.procedureTagIds.prefix(2).compactMap {
                        SpecialtyPackCatalog.findProcedure(by: $0)?.title
                    }.joined(separator: ", "))
                    .font(.subheadline)
                    .lineLimit(1)
                    Text(caseEntry.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
                Spacer()
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

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

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
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
        .background(ProcedusTheme.primary.opacity(0.15))
        .foregroundStyle(ProcedusTheme.primary)
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
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.15))
                .cornerRadius(12)
            }
        }
    }
}

// FlowLayout is defined in AttestationQueueView.swift
