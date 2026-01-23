// CaseMediaSection.swift
// Procedus - Unified
// Reusable media attachment section for case entry forms

import SwiftUI
import SwiftData

struct CaseMediaSection: View {
    let caseId: UUID
    let ownerId: UUID
    let ownerName: String

    @Environment(\.modelContext) private var modelContext

    @Query private var allMedia: [CaseMedia]

    @State private var showingAddMedia = false
    @State private var selectedMedia: CaseMedia?

    private var caseMedia: [CaseMedia] {
        allMedia.filter { $0.caseEntryId == caseId }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Media", systemImage: "photo.on.rectangle.angled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(ProcedusTheme.textPrimary)

                Spacer()

                Button {
                    showingAddMedia = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.primary)
                }
            }

            if caseMedia.isEmpty {
                emptyStateView
            } else {
                mediaGrid
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
        .cornerRadius(12)
        .sheet(isPresented: $showingAddMedia) {
            AddCaseMediaFlow(
                caseId: caseId,
                ownerId: ownerId,
                ownerName: ownerName
            ) { _ in
                // Media added callback - could show a toast
            }
        }
        .sheet(item: $selectedMedia) { media in
            MediaDetailView(media: media)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        Button {
            showingAddMedia = true
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(ProcedusTheme.textSecondary)

                Text("Tap to add images or videos")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 80)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Media Grid

    private var mediaGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(caseMedia) { media in
                MediaThumbnailView(media: media)
                    .onTapGesture {
                        selectedMedia = media
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            deleteMedia(media)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }

            // Add more button
            Button {
                showingAddMedia = true
            } label: {
                VStack {
                    Image(systemName: "plus")
                        .font(.title2)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
                .frame(width: 80, height: 80)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Delete Media

    private func deleteMedia(_ media: CaseMedia) {
        // Delete files
        MediaStorageService.shared.deleteMedia(
            localPath: media.localPath,
            thumbnailPath: media.thumbnailPath
        )

        // Delete record
        modelContext.delete(media)
        try? modelContext.save()
    }
}

// MARK: - Media Thumbnail View

struct MediaThumbnailView: View {
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

            // Redaction indicator
            if media.redactionApplied {
                VStack {
                    HStack {
                        Image(systemName: "rectangle.inset.filled")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.red.opacity(0.8))
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
            // Try loading main image as thumbnail
            thumbnail = MediaStorageService.shared.loadImage(from: media.localPath)
        }
    }
}

// MARK: - Media Detail View

struct MediaDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let media: CaseMedia

    @State private var fullImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack {
                if let image = fullImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else if media.mediaType == .video {
                    videoPlaceholder
                } else {
                    ProgressView()
                }

                // Media info
                VStack(alignment: .leading, spacing: 8) {
                    if !media.searchTerms.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(media.searchTerms, id: \.self) { term in
                                    Text(term)
                                        .font(.caption)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ProcedusTheme.primary.opacity(0.15))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }

                    HStack {
                        Label(media.mediaType.displayName, systemImage: media.mediaType.systemImage)
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)

                        Spacer()

                        Text(MediaStorageService.shared.formattedFileSize(media.fileSizeBytes))
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                    }

                    if media.redactionApplied {
                        Label("PHI Redacted", systemImage: "rectangle.inset.filled")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if media.isSharedWithFellowship {
                        Label("Shared in Teaching Files", systemImage: "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.primary)
                    }
                }
                .padding()
                .background(ProcedusTheme.cardBackground)
            }
            .navigationTitle("Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadFullImage()
            }
        }
    }

    private var videoPlaceholder: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.fill")
                .font(.system(size: 60))
                .foregroundStyle(ProcedusTheme.textSecondary)

            if let duration = media.durationSeconds {
                Text(formatDuration(duration))
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)
            }

            Text("Video playback coming soon")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textTertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray.opacity(0.1))
    }

    private func loadFullImage() {
        if media.mediaType == .image {
            fullImage = MediaStorageService.shared.loadImage(from: media.localPath)
        } else if let thumbPath = media.thumbnailPath {
            fullImage = MediaStorageService.shared.loadThumbnail(from: thumbPath)
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Case Row Media Indicator

/// Small camera icon to show in case log rows when a case has media
struct CaseMediaIndicator: View {
    let caseId: UUID

    @Query private var allMedia: [CaseMedia]

    private var hasMedia: Bool {
        allMedia.contains { $0.caseEntryId == caseId }
    }

    var body: some View {
        if hasMedia {
            Image(systemName: "camera.fill")
                .font(.caption2)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }
}
