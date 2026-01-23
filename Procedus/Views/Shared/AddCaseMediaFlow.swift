// AddCaseMediaFlow.swift
// Procedus - Unified
// Coordinator view managing the full media flow: Picker → Detection → Review → Save

import SwiftUI
import SwiftData
import AVFoundation
import CoreMedia

/// Flow states for media addition
enum MediaFlowState {
    case picker
    case scanning
    case reviewPHI(image: UIImage, regions: [DetectedTextRegion])
    case confirmNoPHI(image: UIImage)
    case crop(image: UIImage)
    case labels(image: UIImage, wasRedacted: Bool)
    case videoLabels(videoURL: URL)
}

struct AddCaseMediaFlow: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let caseId: UUID
    let ownerId: UUID
    let ownerName: String
    let onMediaAdded: (CaseMedia) -> Void

    @State private var flowState: MediaFlowState = .picker
    @State private var errorMessage: String?
    @State private var searchTerms: [String] = []
    @State private var isSharedWithFellowship = false

    var body: some View {
        Group {
            switch flowState {
            case .picker:
                MediaPickerView { result in
                    handleMediaSelected(result)
                }

            case .scanning:
                scanningView

            case .reviewPHI(let image, let regions):
                PHIDetectionReviewView(
                    originalImage: image,
                    detectedRegions: regions,
                    onRedactAndSave: { redactedImage in
                        flowState = .labels(image: redactedImage, wasRedacted: true)
                    },
                    onCropInstead: {
                        flowState = .crop(image: image)
                    },
                    onCancel: {
                        dismiss()
                    }
                )

            case .confirmNoPHI(let image):
                NoPHIConfirmationView(
                    image: image,
                    onConfirm: {
                        flowState = .labels(image: image, wasRedacted: false)
                    },
                    onCancel: {
                        dismiss()
                    }
                )

            case .crop(let image):
                ImageCropView(
                    image: image,
                    onCropComplete: { croppedImage in
                        // Re-scan cropped image
                        Task {
                            await scanImage(croppedImage)
                        }
                    },
                    onCancel: {
                        flowState = .picker
                    }
                )

            case .labels(let image, let wasRedacted):
                MediaLabelsView(
                    image: image,
                    searchTerms: $searchTerms,
                    isSharedWithFellowship: $isSharedWithFellowship,
                    onSave: {
                        saveImage(image, wasRedacted: wasRedacted)
                    },
                    onCancel: {
                        dismiss()
                    }
                )

            case .videoLabels(let videoURL):
                VideoLabelsView(
                    videoURL: videoURL,
                    searchTerms: $searchTerms,
                    isSharedWithFellowship: $isSharedWithFellowship,
                    onSave: {
                        Task {
                            await saveVideo(videoURL)
                        }
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
                flowState = .picker
            }
        } message: {
            if let error = errorMessage {
                Text(error)
            }
        }
    }

    // MARK: - Scanning View

    private var scanningView: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(2)

            Text("Scanning for PHI...")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            Text("Checking image for text that may contain Protected Health Information")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }

    // MARK: - Handle Media Selected

    private func handleMediaSelected(_ result: MediaPickerResult) {
        if result.isImage, let image = result.image {
            Task {
                await scanImage(image)
            }
        } else if result.isVideo, let videoURL = result.videoURL {
            // For videos, scan frames for PHI
            Task {
                await scanVideo(videoURL)
            }
        }
    }

    // MARK: - Scan Image

    @MainActor
    private func scanImage(_ image: UIImage) async {
        flowState = .scanning

        let result = await TextDetectionService.shared.detectText(in: image)

        if result.textWasDetected {
            flowState = .reviewPHI(image: image, regions: result.regions)
        } else {
            flowState = .confirmNoPHI(image: image)
        }
    }

    // MARK: - Scan Video

    @MainActor
    private func scanVideo(_ videoURL: URL) async {
        flowState = .scanning

        let result = await TextDetectionService.shared.detectText(inVideo: videoURL)

        if result.textWasDetected {
            // For videos with PHI, we can't easily redact - show error
            errorMessage = "Video contains text that may include PHI. Please remove the text before uploading, or use an image instead."
            try? FileManager.default.removeItem(at: videoURL)
        } else {
            // No PHI detected, proceed to labels
            flowState = .videoLabels(videoURL: videoURL)
        }
    }

    // MARK: - Save Image

    private func saveImage(_ image: UIImage, wasRedacted: Bool) {
        guard let saveResult = MediaStorageService.shared.saveImage(image, forCaseId: caseId) else {
            errorMessage = "Failed to save image"
            return
        }

        // Create CaseMedia record
        let caseMedia = CaseMedia(
            caseEntryId: caseId,
            ownerId: ownerId,
            ownerName: ownerName,
            mediaType: .image,
            fileName: (saveResult.localPath as NSString).lastPathComponent,
            localPath: saveResult.localPath
        )

        caseMedia.thumbnailPath = saveResult.thumbnailPath
        caseMedia.fileSizeBytes = saveResult.fileSize
        caseMedia.width = saveResult.width
        caseMedia.height = saveResult.height
        caseMedia.contentHash = saveResult.contentHash
        caseMedia.searchTerms = searchTerms
        caseMedia.isSharedWithFellowship = isSharedWithFellowship
        caseMedia.textDetectionRan = true
        caseMedia.textWasDetected = wasRedacted
        caseMedia.userConfirmedNoPHI = !wasRedacted
        caseMedia.userConfirmedAt = Date()
        caseMedia.redactionApplied = wasRedacted

        modelContext.insert(caseMedia)

        do {
            try modelContext.save()
            onMediaAdded(caseMedia)
            dismiss()
        } catch {
            errorMessage = "Failed to save media record: \(error.localizedDescription)"
        }
    }

    // MARK: - Save Video

    @MainActor
    private func saveVideo(_ videoURL: URL) async {
        guard let saveResult = await MediaStorageService.shared.saveVideo(from: videoURL, forCaseId: caseId) else {
            errorMessage = "Failed to save video"
            return
        }

        // Clean up temp file
        try? FileManager.default.removeItem(at: videoURL)

        // Create CaseMedia record
        let caseMedia = CaseMedia(
            caseEntryId: caseId,
            ownerId: ownerId,
            ownerName: ownerName,
            mediaType: .video,
            fileName: (saveResult.localPath as NSString).lastPathComponent,
            localPath: saveResult.localPath
        )

        caseMedia.thumbnailPath = saveResult.thumbnailPath
        caseMedia.fileSizeBytes = saveResult.fileSize
        caseMedia.width = saveResult.width
        caseMedia.height = saveResult.height
        caseMedia.durationSeconds = saveResult.duration
        caseMedia.contentHash = saveResult.contentHash
        caseMedia.searchTerms = searchTerms
        caseMedia.isSharedWithFellowship = isSharedWithFellowship
        caseMedia.textDetectionRan = true
        caseMedia.textWasDetected = false
        caseMedia.userConfirmedNoPHI = true
        caseMedia.userConfirmedAt = Date()

        modelContext.insert(caseMedia)

        do {
            try modelContext.save()
            onMediaAdded(caseMedia)
            dismiss()
        } catch {
            errorMessage = "Failed to save media record: \(error.localizedDescription)"
        }
    }
}

// MARK: - Image Crop View

struct ImageCropView: View {
    let image: UIImage
    let onCropComplete: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var cropRect = CGRect.zero
    @State private var imageSize = CGSize.zero

    var body: some View {
        NavigationStack {
            VStack {
                Text("Crop to remove text areas")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .padding()

                GeometryReader { geometry in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                        .onAppear {
                            let aspectRatio = image.size.width / image.size.height
                            let containerAspect = geometry.size.width / geometry.size.height

                            if aspectRatio > containerAspect {
                                imageSize = CGSize(
                                    width: geometry.size.width,
                                    height: geometry.size.width / aspectRatio
                                )
                            } else {
                                imageSize = CGSize(
                                    width: geometry.size.height * aspectRatio,
                                    height: geometry.size.height
                                )
                            }
                            cropRect = CGRect(origin: .zero, size: imageSize)
                        }
                        .overlay(
                            CropOverlay(
                                cropRect: $cropRect,
                                bounds: imageSize
                            )
                        )
                }
                .padding()
            }
            .navigationTitle("Crop Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        performCrop()
                    }
                }
            }
        }
    }

    private func performCrop() {
        // Convert crop rect to image coordinates
        let scaleX = image.size.width / imageSize.width
        let scaleY = image.size.height / imageSize.height

        let scaledCropRect = CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        guard let cgImage = image.cgImage?.cropping(to: scaledCropRect) else {
            onCancel()
            return
        }

        let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        onCropComplete(croppedImage)
    }
}

// MARK: - Crop Overlay

struct CropOverlay: View {
    @Binding var cropRect: CGRect
    let bounds: CGSize

    @GestureState private var dragOffset = CGSize.zero
    @State private var activeHandle: CropHandle?

    enum CropHandle {
        case topLeft, topRight, bottomLeft, bottomRight, move
    }

    var body: some View {
        ZStack {
            // Dimmed area outside crop
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .overlay(
                            Rectangle()
                                .frame(width: cropRect.width, height: cropRect.height)
                                .position(
                                    x: cropRect.midX,
                                    y: cropRect.midY
                                )
                                .blendMode(.destinationOut)
                        )
                )

            // Crop border
            Rectangle()
                .stroke(Color.white, lineWidth: 2)
                .frame(width: cropRect.width, height: cropRect.height)
                .position(x: cropRect.midX, y: cropRect.midY)

            // Corner handles
            ForEach([CropHandle.topLeft, .topRight, .bottomLeft, .bottomRight], id: \.self) { handle in
                Circle()
                    .fill(Color.white)
                    .frame(width: 20, height: 20)
                    .position(handlePosition(for: handle))
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                updateCropRect(for: handle, translation: value.translation)
                            }
                    )
            }
        }
        .frame(width: bounds.width, height: bounds.height)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Move entire crop rect
                    var newRect = cropRect
                    newRect.origin.x = max(0, min(bounds.width - cropRect.width, cropRect.origin.x + value.translation.width))
                    newRect.origin.y = max(0, min(bounds.height - cropRect.height, cropRect.origin.y + value.translation.height))
                    cropRect = newRect
                }
        )
    }

    private func handlePosition(for handle: CropHandle) -> CGPoint {
        switch handle {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        case .move:
            return cropRect.origin
        }
    }

    private func updateCropRect(for handle: CropHandle, translation: CGSize) {
        let minSize: CGFloat = 50

        switch handle {
        case .topLeft:
            let newX = max(0, cropRect.minX + translation.width)
            let newY = max(0, cropRect.minY + translation.height)
            let newWidth = cropRect.maxX - newX
            let newHeight = cropRect.maxY - newY
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
            }
        case .topRight:
            let newWidth = min(bounds.width - cropRect.minX, cropRect.width + translation.width)
            let newY = max(0, cropRect.minY + translation.height)
            let newHeight = cropRect.maxY - newY
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: cropRect.minX, y: newY, width: newWidth, height: newHeight)
            }
        case .bottomLeft:
            let newX = max(0, cropRect.minX + translation.width)
            let newWidth = cropRect.maxX - newX
            let newHeight = min(bounds.height - cropRect.minY, cropRect.height + translation.height)
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: newX, y: cropRect.minY, width: newWidth, height: newHeight)
            }
        case .bottomRight:
            let newWidth = min(bounds.width - cropRect.minX, cropRect.width + translation.width)
            let newHeight = min(bounds.height - cropRect.minY, cropRect.height + translation.height)
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: cropRect.minX, y: cropRect.minY, width: newWidth, height: newHeight)
            }
        case .move:
            break
        }
    }
}

// MARK: - Media Labels View

struct MediaLabelsView: View {
    let image: UIImage
    @Binding var searchTerms: [String]
    @Binding var isSharedWithFellowship: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var newTerm = ""
    @Query private var suggestions: [SearchTermSuggestion]

    private var filteredSuggestions: [SearchTermSuggestion] {
        guard !newTerm.isEmpty else { return [] }
        let lowercasedTerm = newTerm.lowercased()
        return suggestions
            .filter { $0.term.contains(lowercasedTerm) && !searchTerms.contains($0.displayText) }
            .sorted { $0.usageCount > $1.usageCount }
            .prefix(5)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(12)

                    // Search terms
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Labels")
                            .font(.headline)

                        // Current terms
                        if !searchTerms.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(searchTerms, id: \.self) { term in
                                    HStack(spacing: 4) {
                                        Text(term)
                                            .font(.caption)
                                        Button {
                                            searchTerms.removeAll { $0 == term }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ProcedusTheme.primary.opacity(0.15))
                                    .cornerRadius(16)
                                }
                            }
                        }

                        // Add new term
                        HStack {
                            TextField("Add label...", text: $newTerm)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addTerm()
                                }

                            Button {
                                addTerm()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(ProcedusTheme.primary)
                            }
                            .disabled(newTerm.isEmpty)
                        }

                        // Suggestions
                        if !filteredSuggestions.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filteredSuggestions, id: \.term) { suggestion in
                                        Button {
                                            searchTerms.append(suggestion.displayText)
                                            newTerm = ""
                                        } label: {
                                            Text(suggestion.displayText)
                                                .font(.caption)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 6)
                                                .background(Color.gray.opacity(0.15))
                                                .cornerRadius(16)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                    .background(ProcedusTheme.cardBackground)
                    .cornerRadius(12)

                    // Share toggle
                    Toggle(isOn: $isSharedWithFellowship) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share with Fellowship")
                                .font(.subheadline)
                            Text("Add to Teaching Files library")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                        }
                    }
                    .padding()
                    .background(ProcedusTheme.cardBackground)
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
        }
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !searchTerms.contains(trimmed) else { return }
        searchTerms.append(trimmed)
        newTerm = ""
    }
}

// MARK: - Video Labels View

struct VideoLabelsView: View {
    let videoURL: URL
    @Binding var searchTerms: [String]
    @Binding var isSharedWithFellowship: Bool
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var newTerm = ""
    @State private var thumbnailImage: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Video thumbnail preview
                    Group {
                        if let thumbnail = thumbnailImage {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 200)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundStyle(.white.opacity(0.8))
                                )
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .cornerRadius(12)
                                .overlay(
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(.gray)
                                )
                        }
                    }

                    // Search terms (same as MediaLabelsView)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Labels")
                            .font(.headline)

                        if !searchTerms.isEmpty {
                            FlowLayout(spacing: 8) {
                                ForEach(searchTerms, id: \.self) { term in
                                    HStack(spacing: 4) {
                                        Text(term)
                                            .font(.caption)
                                        Button {
                                            searchTerms.removeAll { $0 == term }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.caption)
                                        }
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ProcedusTheme.primary.opacity(0.15))
                                    .cornerRadius(16)
                                }
                            }
                        }

                        HStack {
                            TextField("Add label...", text: $newTerm)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    addTerm()
                                }

                            Button {
                                addTerm()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(ProcedusTheme.primary)
                            }
                            .disabled(newTerm.isEmpty)
                        }
                    }
                    .padding()
                    .background(ProcedusTheme.cardBackground)
                    .cornerRadius(12)

                    // Share toggle
                    Toggle(isOn: $isSharedWithFellowship) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Share with Fellowship")
                                .font(.subheadline)
                            Text("Add to Teaching Files library")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                        }
                    }
                    .padding()
                    .background(ProcedusTheme.cardBackground)
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Add Labels")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                    }
                }
            }
            .task {
                await generateThumbnail()
            }
        }
    }

    private func addTerm() {
        let trimmed = newTerm.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !searchTerms.contains(trimmed) else { return }
        searchTerms.append(trimmed)
        newTerm = ""
    }

    @MainActor
    private func generateThumbnail() async {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try await imageGenerator.image(at: CMTime.zero).image
            thumbnailImage = UIImage(cgImage: cgImage)
        } catch {
            print("Failed to generate video thumbnail: \(error)")
        }
    }
}

// Note: FlowLayout is defined in AttestationQueueView.swift and reused here
