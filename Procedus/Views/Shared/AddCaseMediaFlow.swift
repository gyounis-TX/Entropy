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
    case videoConfirmNoPHI(videoURL: URL)
    case videoRedaction(videoURL: URL, regions: [DetectedTextRegion])
    case videoLabels(videoURL: URL, wasRedacted: Bool)
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
    @State private var showingError = false
    @State private var searchTerms: [String] = []
    @State private var isSharedWithFellowship = false
    @State private var mediaComment: String = ""

    @Query private var allCases: [CaseEntry]

    private var procedureCategory: String? {
        guard let caseEntry = allCases.first(where: { $0.id == caseId }),
              let firstProcId = caseEntry.procedureTagIds.first else {
            return nil
        }
        // Determine category from procedure ID prefix
        if firstProcId.hasPrefix("ic-") {
            if firstProcId.contains("pci") {
                return "coronary"
            } else if firstProcId.contains("struct") || firstProcId.contains("tavr") || firstProcId.contains("teer") {
                return "structural"
            }
            return "coronary"
        } else if firstProcId.hasPrefix("ep-") {
            return "ep"
        } else if firstProcId.hasPrefix("ci-") {
            if firstProcId.contains("echo") {
                return "echo"
            }
            return "imaging"
        }
        return nil
    }

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
                    onRedactAndSave: { processedImage in
                        flowState = .labels(image: processedImage, wasRedacted: true)
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
                    comment: $mediaComment,
                    procedureCategory: procedureCategory,
                    onSave: {
                        saveImage(image, wasRedacted: wasRedacted)
                    },
                    onCancel: {
                        dismiss()
                    }
                )

            case .videoConfirmNoPHI(let videoURL):
                VideoNoPHIConfirmationView(
                    videoURL: videoURL,
                    onConfirm: {
                        flowState = .videoLabels(videoURL: videoURL, wasRedacted: false)
                    },
                    onCancel: {
                        try? FileManager.default.removeItem(at: videoURL)
                        dismiss()
                    }
                )

            case .videoRedaction(let videoURL, let regions):
                VideoRedactionView(
                    videoURL: videoURL,
                    detectedTextRegions: regions,
                    onComplete: { redactedURL in
                        flowState = .videoLabels(videoURL: redactedURL, wasRedacted: true)
                    },
                    onCancel: {
                        // Clean up temp video file
                        try? FileManager.default.removeItem(at: videoURL)
                        dismiss()
                    }
                )

            case .videoLabels(let videoURL, let wasRedacted):
                VideoLabelsView(
                    videoURL: videoURL,
                    searchTerms: $searchTerms,
                    isSharedWithFellowship: $isSharedWithFellowship,
                    comment: $mediaComment,
                    procedureCategory: procedureCategory,
                    onSave: {
                        Task {
                            await saveVideo(videoURL, wasRedacted: wasRedacted)
                        }
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
                showingError = false
                flowState = .picker
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
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
            // Video has PHI - show redaction UI
            flowState = .videoRedaction(videoURL: videoURL, regions: result.regions)
        } else {
            // No PHI detected - still require confirmation
            flowState = .videoConfirmNoPHI(videoURL: videoURL)
        }
    }

    // MARK: - Save Image

    private func saveImage(_ image: UIImage, wasRedacted: Bool) {
        guard let saveResult = MediaStorageService.shared.saveImage(image, forCaseId: caseId) else {
            errorMessage = "Failed to save image"
            showingError = true
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
        caseMedia.comment = mediaComment.isEmpty ? nil : mediaComment
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
            showingError = true
        }
    }

    // MARK: - Save Video

    @MainActor
    private func saveVideo(_ videoURL: URL, wasRedacted: Bool = false) async {
        guard let saveResult = await MediaStorageService.shared.saveVideo(from: videoURL, forCaseId: caseId) else {
            errorMessage = "Failed to save video"
            showingError = true
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
        caseMedia.comment = mediaComment.isEmpty ? nil : mediaComment
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
            showingError = true
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
    @State private var isInitialized = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text("Drag corners to adjust crop area")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .padding()

                GeometryReader { geometry in
                    let aspectRatio = image.size.width / image.size.height
                    let containerAspect = geometry.size.width / geometry.size.height

                    let displaySize: CGSize = {
                        if aspectRatio > containerAspect {
                            return CGSize(
                                width: geometry.size.width,
                                height: geometry.size.width / aspectRatio
                            )
                        } else {
                            return CGSize(
                                width: geometry.size.height * aspectRatio,
                                height: geometry.size.height
                            )
                        }
                    }()

                    ZStack {
                        // Image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: displaySize.width, height: displaySize.height)

                        // Crop overlay
                        CropOverlay(
                            cropRect: $cropRect,
                            bounds: displaySize
                        )
                        .frame(width: displaySize.width, height: displaySize.height)
                    }
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear {
                        if !isInitialized {
                            imageSize = displaySize
                            // Start with full image selected, with small inset
                            let inset: CGFloat = 20
                            cropRect = CGRect(
                                x: inset,
                                y: inset,
                                width: displaySize.width - inset * 2,
                                height: displaySize.height - inset * 2
                            )
                            isInitialized = true
                        }
                    }
                    .onChange(of: geometry.size) { _, newSize in
                        // Recalculate on rotation
                        let newAspectRatio = image.size.width / image.size.height
                        let newContainerAspect = newSize.width / newSize.height

                        let newDisplaySize: CGSize
                        if newAspectRatio > newContainerAspect {
                            newDisplaySize = CGSize(
                                width: newSize.width,
                                height: newSize.width / newAspectRatio
                            )
                        } else {
                            newDisplaySize = CGSize(
                                width: newSize.height * newAspectRatio,
                                height: newSize.height
                            )
                        }

                        // Scale crop rect proportionally
                        let scaleX = newDisplaySize.width / imageSize.width
                        let scaleY = newDisplaySize.height / imageSize.height
                        cropRect = CGRect(
                            x: cropRect.origin.x * scaleX,
                            y: cropRect.origin.y * scaleY,
                            width: cropRect.width * scaleX,
                            height: cropRect.height * scaleY
                        )
                        imageSize = newDisplaySize
                    }
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
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func performCrop() {
        guard imageSize.width > 0 && imageSize.height > 0 else {
            onCancel()
            return
        }

        // Convert crop rect to image coordinates
        let scaleX = image.size.width / imageSize.width
        let scaleY = image.size.height / imageSize.height

        let scaledCropRect = CGRect(
            x: cropRect.origin.x * scaleX,
            y: cropRect.origin.y * scaleY,
            width: cropRect.width * scaleX,
            height: cropRect.height * scaleY
        )

        // Ensure crop rect is within bounds
        let clampedRect = scaledCropRect.intersection(CGRect(origin: .zero, size: image.size))

        guard clampedRect.width > 0, clampedRect.height > 0,
              let cgImage = image.cgImage?.cropping(to: clampedRect) else {
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

    // Track the initial rect when drag starts
    @State private var initialCropRect: CGRect = .zero
    @State private var isDraggingHandle = false

    enum CropHandle: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
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

            // Grid lines (rule of thirds)
            Path { path in
                let third = cropRect.width / 3
                path.move(to: CGPoint(x: cropRect.minX + third, y: cropRect.minY))
                path.addLine(to: CGPoint(x: cropRect.minX + third, y: cropRect.maxY))
                path.move(to: CGPoint(x: cropRect.minX + third * 2, y: cropRect.minY))
                path.addLine(to: CGPoint(x: cropRect.minX + third * 2, y: cropRect.maxY))

                let thirdH = cropRect.height / 3
                path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + thirdH))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + thirdH))
                path.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + thirdH * 2))
                path.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + thirdH * 2))
            }
            .stroke(Color.white.opacity(0.5), lineWidth: 1)

            // Corner handles
            ForEach(CropHandle.allCases, id: \.self) { handle in
                cornerHandle(for: handle)
            }

            // Move gesture on crop area (center)
            Rectangle()
                .fill(Color.clear)
                .frame(width: max(0, cropRect.width - 60), height: max(0, cropRect.height - 60))
                .position(x: cropRect.midX, y: cropRect.midY)
                .gesture(moveGesture)
        }
        .frame(width: bounds.width, height: bounds.height)
    }

    @ViewBuilder
    private func cornerHandle(for handle: CropHandle) -> some View {
        // Only show handles when cropRect has valid dimensions
        if cropRect.width > 0 && cropRect.height > 0 {
            Circle()
                .fill(Color.white)
                .frame(width: 32, height: 32)
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 2)
                .position(handlePosition(for: handle))
                .contentShape(Rectangle().size(width: 60, height: 60))  // Larger touch target
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if !isDraggingHandle {
                                initialCropRect = cropRect
                                isDraggingHandle = true
                            }
                            updateCropRect(for: handle, translation: value.translation)
                        }
                        .onEnded { _ in
                            isDraggingHandle = false
                        }
                )
        }
    }

    private var moveGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDraggingHandle {
                    if initialCropRect == .zero {
                        initialCropRect = cropRect
                    }
                    let newX = max(0, min(bounds.width - initialCropRect.width, initialCropRect.origin.x + value.translation.width))
                    let newY = max(0, min(bounds.height - initialCropRect.height, initialCropRect.origin.y + value.translation.height))
                    cropRect = CGRect(x: newX, y: newY, width: initialCropRect.width, height: initialCropRect.height)
                }
            }
            .onEnded { _ in
                initialCropRect = cropRect
            }
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
        }
    }

    private func updateCropRect(for handle: CropHandle, translation: CGSize) {
        let minSize: CGFloat = 50

        switch handle {
        case .topLeft:
            let newX = max(0, initialCropRect.minX + translation.width)
            let newY = max(0, initialCropRect.minY + translation.height)
            let newWidth = initialCropRect.maxX - newX
            let newHeight = initialCropRect.maxY - newY
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: newX, y: newY, width: newWidth, height: newHeight)
            }
        case .topRight:
            let newWidth = min(bounds.width - initialCropRect.minX, initialCropRect.width + translation.width)
            let newY = max(0, initialCropRect.minY + translation.height)
            let newHeight = initialCropRect.maxY - newY
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: initialCropRect.minX, y: newY, width: newWidth, height: newHeight)
            }
        case .bottomLeft:
            let newX = max(0, initialCropRect.minX + translation.width)
            let newWidth = initialCropRect.maxX - newX
            let newHeight = min(bounds.height - initialCropRect.minY, initialCropRect.height + translation.height)
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: newX, y: initialCropRect.minY, width: newWidth, height: newHeight)
            }
        case .bottomRight:
            let newWidth = min(bounds.width - initialCropRect.minX, initialCropRect.width + translation.width)
            let newHeight = min(bounds.height - initialCropRect.minY, initialCropRect.height + translation.height)
            if newWidth >= minSize && newHeight >= minSize {
                cropRect = CGRect(x: initialCropRect.minX, y: initialCropRect.minY, width: newWidth, height: newHeight)
            }
        }
    }
}

// MARK: - Media Labels View

struct MediaLabelsView: View {
    let image: UIImage
    @Binding var searchTerms: [String]
    @Binding var isSharedWithFellowship: Bool
    @Binding var comment: String
    let procedureCategory: String?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var newTerm = ""
    @State private var phiConfirmed = false
    @Query private var suggestions: [SearchTermSuggestion]

    // Common labels organized by procedure category
    private static let commonLabels: [String: [String]] = [
        "coronary": ["Great Result", "Coronary Anomaly", "CTO", "Bifurcation", "Calcified", "Thrombus", "Dissection", "Perforation"],
        "structural": ["TAVR", "MitraClip", "LAAO", "PFO Closure", "ASD Closure", "Paravalvular Leak"],
        "ep": ["Interesting Case", "Rare Arrhythmia", "Complex Ablation", "Device Implant", "Lead Extraction"],
        "echo": ["Teaching Case", "Rare Finding", "Great Image", "Pathology", "Pre-Procedure", "Post-Procedure"],
        "general": ["Teaching Case", "Rare Finding", "Great Result", "Complication", "Before/After", "Technique"]
    ]

    private var quickLabels: [String] {
        if let category = procedureCategory?.lowercased() {
            if category.contains("coronary") || category.contains("pci") || category.contains("cath") {
                return Self.commonLabels["coronary"] ?? Self.commonLabels["general"]!
            } else if category.contains("structural") || category.contains("tavr") || category.contains("valve") {
                return Self.commonLabels["structural"] ?? Self.commonLabels["general"]!
            } else if category.contains("ep") || category.contains("ablation") || category.contains("device") {
                return Self.commonLabels["ep"] ?? Self.commonLabels["general"]!
            } else if category.contains("echo") || category.contains("imaging") {
                return Self.commonLabels["echo"] ?? Self.commonLabels["general"]!
            }
        }
        return Self.commonLabels["general"]!
    }

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

                    // Labels section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Labels")
                            .font(.headline)

                        // Quick label buttons
                        Text("Quick Labels")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(quickLabels.filter { !searchTerms.contains($0) }, id: \.self) { label in
                                Button {
                                    searchTerms.append(label)
                                } label: {
                                    Text(label)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        // Current terms
                        if !searchTerms.isEmpty {
                            Text("Selected")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)

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

                        // Add custom term
                        HStack {
                            TextField("Add custom label...", text: $newTerm)
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

                        // Suggestions from history
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

                    // Comments section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comments")
                            .font(.headline)

                        TextEditor(text: $comment)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)

                        Text("Add notes about this image for yourself and others")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
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

                    // PHI Attestation
                    VStack(spacing: 12) {
                        Button {
                            phiConfirmed.toggle()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: phiConfirmed ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundStyle(phiConfirmed ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                                Text("I confirm all Protected Health Information (PHI) has been removed or redacted from this image.")
                                    .font(.caption)
                                    .foregroundStyle(ProcedusTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
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
                    .disabled(!phiConfirmed)
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
    @Binding var comment: String
    let procedureCategory: String?
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var newTerm = ""
    @State private var thumbnailImage: UIImage?
    @State private var phiConfirmed = false

    // Common labels (same as MediaLabelsView)
    private static let commonLabels: [String: [String]] = [
        "coronary": ["Great Result", "Coronary Anomaly", "CTO", "Bifurcation", "Calcified", "Thrombus", "Dissection", "Perforation"],
        "structural": ["TAVR", "MitraClip", "LAAO", "PFO Closure", "ASD Closure", "Paravalvular Leak"],
        "ep": ["Interesting Case", "Rare Arrhythmia", "Complex Ablation", "Device Implant", "Lead Extraction"],
        "echo": ["Teaching Case", "Rare Finding", "Great Image", "Pathology", "Pre-Procedure", "Post-Procedure"],
        "general": ["Teaching Case", "Rare Finding", "Great Result", "Complication", "Before/After", "Technique"]
    ]

    private var quickLabels: [String] {
        if let category = procedureCategory?.lowercased() {
            if category.contains("coronary") || category.contains("pci") || category.contains("cath") {
                return Self.commonLabels["coronary"] ?? Self.commonLabels["general"]!
            } else if category.contains("structural") || category.contains("tavr") || category.contains("valve") {
                return Self.commonLabels["structural"] ?? Self.commonLabels["general"]!
            } else if category.contains("ep") || category.contains("ablation") || category.contains("device") {
                return Self.commonLabels["ep"] ?? Self.commonLabels["general"]!
            } else if category.contains("echo") || category.contains("imaging") {
                return Self.commonLabels["echo"] ?? Self.commonLabels["general"]!
            }
        }
        return Self.commonLabels["general"]!
    }

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

                    // Labels section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Labels")
                            .font(.headline)

                        // Quick label buttons
                        Text("Quick Labels")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textSecondary)

                        FlowLayout(spacing: 8) {
                            ForEach(quickLabels.filter { !searchTerms.contains($0) }, id: \.self) { label in
                                Button {
                                    searchTerms.append(label)
                                } label: {
                                    Text(label)
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.1))
                                        .foregroundStyle(.blue)
                                        .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Divider()

                        if !searchTerms.isEmpty {
                            Text("Selected")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)

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
                            TextField("Add custom label...", text: $newTerm)
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

                    // Comments section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Comments")
                            .font(.headline)

                        TextEditor(text: $comment)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(8)

                        Text("Add notes about this video for yourself and others")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textTertiary)
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

                    // PHI Attestation
                    VStack(spacing: 12) {
                        Button {
                            phiConfirmed.toggle()
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: phiConfirmed ? "checkmark.square.fill" : "square")
                                    .font(.title2)
                                    .foregroundStyle(phiConfirmed ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                                Text("I confirm all Protected Health Information (PHI) has been removed or redacted from this video.")
                                    .font(.caption)
                                    .foregroundStyle(ProcedusTheme.textPrimary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
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
                    .disabled(!phiConfirmed)
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

    private func generateThumbnail() async {
        let url = videoURL
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)
            var actualTime = CMTime.zero
            guard let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: &actualTime) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }.value
        if let image {
            thumbnailImage = image
        }
    }
}

// MARK: - Video No PHI Confirmation View

struct VideoNoPHIConfirmationView: View {
    let videoURL: URL
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var isConfirmed = false
    @State private var thumbnailImage: UIImage?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Success indicator
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)

                    Text("No Text Detected")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Our scan didn't find any text in this video.")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

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
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white.opacity(0.8))
                            )
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .cornerRadius(12)
                            .overlay(
                                ProgressView()
                            )
                    }
                }

                Spacer()

                // Confirmation checkbox
                VStack(spacing: 16) {
                    Button {
                        isConfirmed.toggle()
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: isConfirmed ? "checkmark.square.fill" : "square")
                                .font(.title2)
                                .foregroundStyle(isConfirmed ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                            Text("I confirm this video does not contain any Protected Health Information (PHI), including patient names, dates of birth, or other identifying information.")
                                .font(.subheadline)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onConfirm()
                    } label: {
                        Text("Save Video")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isConfirmed ? ProcedusTheme.primary : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!isConfirmed)
                }
                .padding()
                .background(ProcedusTheme.cardBackground)
                .cornerRadius(16)
            }
            .padding()
            .navigationTitle("Confirm No PHI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .task {
                await generateThumbnail()
            }
        }
    }

    private func generateThumbnail() async {
        let url = videoURL
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)
            var actualTime = CMTime.zero
            guard let cgImage = try? imageGenerator.copyCGImage(at: .zero, actualTime: &actualTime) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }.value
        if let image {
            thumbnailImage = image
        }
    }
}

// Note: FlowLayout is defined in AttestationQueueView.swift and reused here
