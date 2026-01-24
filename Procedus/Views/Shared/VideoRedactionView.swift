// VideoRedactionView.swift
// Procedus - Unified
// UI for drawing and applying redaction regions to videos

import SwiftUI
import AVKit

struct VideoRedactionView: View {
    let videoURL: URL
    let detectedTextRegions: [DetectedTextRegion]  // Pre-detected regions to suggest
    let onComplete: (URL) -> Void  // Returns redacted video URL
    let onCancel: () -> Void

    @State private var thumbnail: UIImage?
    @State private var videoSize: CGSize = .zero
    @State private var displaySize: CGSize = .zero
    @State private var redactionRegions: [VideoRedactionRegion] = []
    @State private var isDrawing = false
    @State private var currentDrawRect: CGRect = .zero
    @State private var drawStartPoint: CGPoint = .zero
    @State private var isExporting = false
    @State private var exportProgress: Float = 0
    @State private var showingPreview = false
    @State private var previewImage: UIImage?
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var currentTime: CMTime = .zero
    @State private var videoDuration: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions header
                instructionsHeader

                // Video frame with redaction drawing
                GeometryReader { geometry in
                    videoFrameView(containerSize: geometry.size)
                }
                .padding()

                // Timeline scrubber
                if videoDuration > 0 {
                    timelineScrubber
                }

                // Action buttons
                actionButtons
            }
            .navigationTitle("Redact Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .disabled(isExporting)
                }
            }
            .task {
                await loadVideoInfo()
            }
            .sheet(isPresented: $showingPreview) {
                redactionPreviewSheet
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .overlay {
                if isExporting {
                    exportingOverlay
                }
            }
        }
    }

    // MARK: - Instructions Header

    private var instructionsHeader: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "hand.draw.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Draw Redaction Areas")
                        .font(.headline)
                    Text("Drag to draw rectangles over PHI. These will be blacked out in the entire video.")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }

                Spacer()
            }

            if !detectedTextRegions.isEmpty {
                Button {
                    addSuggestedRegions()
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Add \(detectedTextRegions.count) detected region(s)")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(ProcedusTheme.primary.opacity(0.1))
                    .foregroundStyle(ProcedusTheme.primary)
                    .cornerRadius(16)
                }
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
    }

    // MARK: - Video Frame View

    private func videoFrameView(containerSize: CGSize) -> some View {
        ZStack {
            if let thumbnail = thumbnail {
                let aspectRatio = thumbnail.size.width / thumbnail.size.height
                let containerAspect = containerSize.width / containerSize.height

                let size: CGSize = {
                    if aspectRatio > containerAspect {
                        return CGSize(
                            width: containerSize.width,
                            height: containerSize.width / aspectRatio
                        )
                    } else {
                        return CGSize(
                            width: containerSize.height * aspectRatio,
                            height: containerSize.height
                        )
                    }
                }()

                ZStack {
                    // Video thumbnail
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: size.width, height: size.height)

                    // Existing redaction regions
                    ForEach(redactionRegions) { region in
                        redactionRectView(region: region, displaySize: size)
                    }

                    // Currently drawing rect
                    if isDrawing {
                        Rectangle()
                            .fill(Color.red.opacity(0.3))
                            .stroke(Color.red, lineWidth: 2)
                            .frame(
                                width: currentDrawRect.width,
                                height: currentDrawRect.height
                            )
                            .position(
                                x: currentDrawRect.midX,
                                y: currentDrawRect.midY
                            )
                    }
                }
                .frame(width: size.width, height: size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 5)
                        .onChanged { value in
                            handleDragChanged(value: value, displaySize: size)
                        }
                        .onEnded { value in
                            handleDragEnded(value: value, displaySize: size)
                        }
                )
                .onAppear {
                    displaySize = size
                }
            } else {
                ProgressView("Loading video...")
            }
        }
        .frame(width: containerSize.width, height: containerSize.height)
    }

    private func redactionRectView(region: VideoRedactionRegion, displaySize: CGSize) -> some View {
        let rect = CGRect(
            x: region.rect.origin.x * displaySize.width,
            y: region.rect.origin.y * displaySize.height,
            width: region.rect.width * displaySize.width,
            height: region.rect.height * displaySize.height
        )

        return ZStack {
            Rectangle()
                .fill(Color.black)
                .frame(width: rect.width, height: rect.height)

            // Delete button
            Button {
                redactionRegions.removeAll { $0.id == region.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .background(Circle().fill(Color.red))
            }
            .offset(x: rect.width / 2 - 12, y: -rect.height / 2 + 12)
        }
        .position(x: rect.midX, y: rect.midY)
    }

    // MARK: - Timeline Scrubber

    private var timelineScrubber: some View {
        VStack(spacing: 8) {
            Text("Scrub to check different frames")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)

            HStack {
                Text(formatTime(currentTime.seconds))
                    .font(.caption)
                    .monospacedDigit()

                Slider(
                    value: Binding(
                        get: { currentTime.seconds },
                        set: { newValue in
                            currentTime = CMTime(seconds: newValue, preferredTimescale: 600)
                            Task {
                                thumbnail = await VideoRedactionService.shared.getThumbnail(
                                    from: videoURL,
                                    at: currentTime
                                )
                            }
                        }
                    ),
                    in: 0...videoDuration
                )

                Text(formatTime(videoDuration))
                    .font(.caption)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Region count
            if !redactionRegions.isEmpty {
                HStack {
                    Text("\(redactionRegions.count) redaction region(s)")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    Spacer()

                    Button("Clear All") {
                        redactionRegions.removeAll()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }

            // Preview button
            Button {
                Task {
                    await generatePreview()
                }
            } label: {
                HStack {
                    Image(systemName: "eye")
                    Text("Preview Redaction")
                }
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(ProcedusTheme.primary.opacity(0.1))
                .cornerRadius(12)
            }
            .disabled(redactionRegions.isEmpty)

            // Apply button
            Button {
                Task {
                    await applyRedaction()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                    Text("Apply Redaction & Save")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(redactionRegions.isEmpty ? Color.gray : Color.red)
                .cornerRadius(12)
            }
            .disabled(redactionRegions.isEmpty)
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
    }

    // MARK: - Preview Sheet

    private var redactionPreviewSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Redaction Preview")
                    .font(.headline)

                if let preview = previewImage {
                    Image(uiImage: preview)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                }

                Text("Black areas will be permanently redacted in the exported video.")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingPreview = false
                    }
                }
            }
        }
    }

    // MARK: - Exporting Overlay

    private var exportingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView(value: Double(exportProgress))
                    .progressViewStyle(.circular)
                    .scaleEffect(2)

                Text("Exporting Redacted Video...")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("\(Int(exportProgress * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
            .padding(40)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
        }
    }

    // MARK: - Helpers

    private func loadVideoInfo() async {
        thumbnail = await VideoRedactionService.shared.getThumbnail(from: videoURL)
        videoSize = await VideoRedactionService.shared.getVideoDimensions(from: videoURL) ?? .zero
        videoDuration = await VideoRedactionService.shared.getVideoDuration(from: videoURL) ?? 0
    }

    private func handleDragChanged(value: DragGesture.Value, displaySize: CGSize) {
        if !isDrawing {
            isDrawing = true
            drawStartPoint = value.startLocation
        }

        let minX = min(drawStartPoint.x, value.location.x)
        let minY = min(drawStartPoint.y, value.location.y)
        let width = abs(value.location.x - drawStartPoint.x)
        let height = abs(value.location.y - drawStartPoint.y)

        currentDrawRect = CGRect(x: minX, y: minY, width: width, height: height)
    }

    private func handleDragEnded(value: DragGesture.Value, displaySize: CGSize) {
        isDrawing = false

        // Only add if rectangle is large enough
        guard currentDrawRect.width > 20 && currentDrawRect.height > 20 else {
            currentDrawRect = .zero
            return
        }

        // Convert to normalized coordinates
        let normalizedRect = CGRect(
            x: currentDrawRect.origin.x / displaySize.width,
            y: currentDrawRect.origin.y / displaySize.height,
            width: currentDrawRect.width / displaySize.width,
            height: currentDrawRect.height / displaySize.height
        )

        // Clamp to valid range
        let clampedRect = CGRect(
            x: max(0, min(1 - normalizedRect.width, normalizedRect.origin.x)),
            y: max(0, min(1 - normalizedRect.height, normalizedRect.origin.y)),
            width: min(normalizedRect.width, 1),
            height: min(normalizedRect.height, 1)
        )

        redactionRegions.append(VideoRedactionRegion(rect: clampedRect))
        currentDrawRect = .zero
    }

    private func addSuggestedRegions() {
        for region in detectedTextRegions {
            // Convert from Vision coordinates (bottom-left origin) to UIKit (top-left origin)
            let uikitRect = CGRect(
                x: region.boundingBox.origin.x,
                y: 1 - region.boundingBox.origin.y - region.boundingBox.height,
                width: region.boundingBox.width,
                height: region.boundingBox.height
            )

            // Add some padding around detected text
            let paddedRect = uikitRect.insetBy(dx: -0.02, dy: -0.01)
            let clampedRect = CGRect(
                x: max(0, paddedRect.origin.x),
                y: max(0, paddedRect.origin.y),
                width: min(paddedRect.width, 1 - max(0, paddedRect.origin.x)),
                height: min(paddedRect.height, 1 - max(0, paddedRect.origin.y))
            )

            redactionRegions.append(VideoRedactionRegion(rect: clampedRect))
        }
    }

    private func generatePreview() async {
        previewImage = await VideoRedactionService.shared.generatePreviewImage(
            from: videoURL,
            regions: redactionRegions,
            at: currentTime
        )
        showingPreview = true
    }

    private func applyRedaction() async {
        isExporting = true
        exportProgress = 0

        let result = await VideoRedactionService.shared.applyRedaction(
            to: videoURL,
            regions: redactionRegions
        ) { progress in
            Task { @MainActor in
                exportProgress = progress
            }
        }

        isExporting = false

        if result.success, let outputURL = result.outputURL {
            onComplete(outputURL)
        } else {
            errorMessage = result.error ?? "Failed to export video"
            showingError = true
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
