// SharedImageLibraryView.swift
// Procedus - Unified
// Shared media library ("Teaching Files") - images shared by all fellows

import SwiftUI
import SwiftData

struct SharedImageLibraryView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \CaseMedia.createdAt, order: .reverse) private var allMedia: [CaseMedia]
    @Query(sort: \CaseEntry.createdAt, order: .reverse) private var allCases: [CaseEntry]

    @State private var searchText = ""
    @State private var selectedMedia: CaseMedia?
    @State private var filterOption: SharedMediaFilterOption = .all

    // MARK: - Computed Properties

    /// All media shared with the fellowship (Teaching Files)
    private var sharedMedia: [CaseMedia] {
        allMedia.filter { $0.isSharedWithFellowship }
    }

    private var filteredMedia: [CaseMedia] {
        var result = sharedMedia

        // Apply type filter
        switch filterOption {
        case .all:
            break
        case .images:
            result = result.filter { $0.mediaType == .image }
        case .videos:
            result = result.filter { $0.mediaType == .video }
        case .mine:
            let myId = currentUserId
            result = result.filter { $0.ownerId == myId }
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

    /// Group media by owner for display
    private var groupedByOwner: [(ownerName: String, ownerId: UUID, media: [CaseMedia])] {
        let grouped = Dictionary(grouping: filteredMedia) { $0.ownerId }
        return grouped.map { ownerId, mediaItems in
            let ownerName = mediaItems.first?.ownerName ?? "Unknown"
            return (ownerName, ownerId, mediaItems.sorted { $0.createdAt > $1.createdAt })
        }.sorted { lhs, rhs in
            // Put current user first, then alphabetical
            let myId = currentUserId
            if lhs.ownerId == myId { return true }
            if rhs.ownerId == myId { return false }
            return lhs.ownerName < rhs.ownerName
        }
    }

    /// All unique labels from shared media
    private var popularLabels: [String] {
        var labelCounts: [String: Int] = [:]
        for media in sharedMedia {
            for label in media.searchTerms {
                labelCounts[label, default: 0] += 1
            }
        }
        return labelCounts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
    }

    private var currentUserId: UUID {
        if appState.isIndividualMode {
            return getOrCreateIndividualUserId()
        }
        return appState.selectedFellowId ?? appState.currentUser?.id ?? UUID()
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search and filter bar
                searchAndFilterBar

                if sharedMedia.isEmpty {
                    emptyStateView
                } else if filteredMedia.isEmpty {
                    noResultsView
                } else {
                    mediaList
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Teaching Files")
            .sheet(item: $selectedMedia) { media in
                MediaFullDetailView(media: media, showCaseLink: false)
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
                TextField("Search by label or contributor...", text: $searchText)
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
                    ForEach(SharedMediaFilterOption.allCases) { option in
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

            // Popular labels (quick filters)
            if !popularLabels.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        Text("Popular:")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                        ForEach(popularLabels.prefix(6), id: \.self) { label in
                            Button {
                                searchText = label
                            } label: {
                                Text(label)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(10)
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

            Image(systemName: "person.2.fill")
                .font(.system(size: 60))
                .foregroundStyle(ProcedusTheme.textTertiary)

            Text("No Teaching Files Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(ProcedusTheme.textPrimary)

            Text("When fellows share images from their cases,\nthey'll appear here for everyone to learn from.")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                Label("Add images to your cases", systemImage: "1.circle.fill")
                Label("Toggle \"Share in Teaching Files\"", systemImage: "2.circle.fill")
                Label("Help build the collection", systemImage: "3.circle.fill")
            }
            .font(.subheadline)
            .foregroundStyle(ProcedusTheme.textSecondary)
            .padding()
            .background(ProcedusTheme.cardBackground)
            .cornerRadius(12)

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
                // Stats header
                statsHeader

                // Grouped by contributor
                ForEach(groupedByOwner, id: \.ownerId) { group in
                    ContributorMediaGroupView(
                        ownerName: group.ownerName,
                        isCurrentUser: group.ownerId == currentUserId,
                        media: group.media,
                        onMediaTap: { media in
                            selectedMedia = media
                        }
                    )
                }
            }
            .padding()
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        VStack(spacing: 12) {
            HStack(spacing: 24) {
                StatItem(value: "\(sharedMedia.count)", label: "Total Shared")
                StatItem(value: "\(Set(sharedMedia.map { $0.ownerId }).count)", label: "Contributors")
                StatItem(value: "\(Set(sharedMedia.flatMap { $0.searchTerms }).count)", label: "Labels")
            }

            // Contribution encouragement
            if sharedMedia.filter({ $0.ownerId == currentUserId }).isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Share your first image to help others learn!")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
                .padding(8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
    }

    // MARK: - Helpers

    private func countForFilter(_ option: SharedMediaFilterOption) -> Int {
        switch option {
        case .all: return sharedMedia.count
        case .images: return sharedMedia.filter { $0.mediaType == .image }.count
        case .videos: return sharedMedia.filter { $0.mediaType == .video }.count
        case .mine: return sharedMedia.filter { $0.ownerId == currentUserId }.count
        }
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

// MARK: - Shared Media Filter Option

enum SharedMediaFilterOption: String, CaseIterable, Identifiable {
    case all
    case images
    case videos
    case mine

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: return "All"
        case .images: return "Images"
        case .videos: return "Videos"
        case .mine: return "My Shares"
        }
    }
}

// MARK: - Contributor Media Group View

struct ContributorMediaGroupView: View {
    let ownerName: String
    let isCurrentUser: Bool
    let media: [CaseMedia]
    let onMediaTap: (CaseMedia) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Contributor header
            HStack {
                Image(systemName: "person.circle.fill")
                    .font(.title3)
                    .foregroundStyle(isCurrentUser ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(ownerName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                        if isCurrentUser {
                            Text("(You)")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.primary)
                        }
                    }
                    Text("\(media.count) contribution\(media.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Spacer()
            }

            // Media grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                ForEach(media) { item in
                    SharedMediaThumbnail(media: item)
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

// MARK: - Shared Media Thumbnail

struct SharedMediaThumbnail: View {
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

            // Labels indicator
            if !media.searchTerms.isEmpty {
                VStack {
                    HStack {
                        Text("\(media.searchTerms.count)")
                            .font(.system(size: 8, weight: .bold))
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
