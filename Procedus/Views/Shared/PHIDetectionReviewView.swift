// PHIDetectionReviewView.swift
// Procedus - Unified
// Preview and redact detected PHI text regions

import SwiftUI

struct PHIDetectionReviewView: View {
    let originalImage: UIImage
    let detectedRegions: [DetectedTextRegion]
    let onRedactAndSave: (UIImage) -> Void
    let onCropInstead: () -> Void
    let onCancel: () -> Void
    let onRescanAsDiagram: (() -> Void)?

    @State private var highlightedImage: UIImage?
    @State private var selectedRegionIds: Set<UUID>
    @State private var showingRedactionPreview = false
    @State private var redactedImage: UIImage?
    @State private var showingManualRedaction = false
    @State private var manualRedactionRects: [CGRect] = []

    init(
        originalImage: UIImage,
        detectedRegions: [DetectedTextRegion],
        onRedactAndSave: @escaping (UIImage) -> Void,
        onCropInstead: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onRescanAsDiagram: (() -> Void)? = nil
    ) {
        self.originalImage = originalImage
        self.detectedRegions = detectedRegions
        self.onRedactAndSave = onRedactAndSave
        self.onCropInstead = onCropInstead
        self.onCancel = onCancel
        self.onRescanAsDiagram = onRescanAsDiagram
        // Default: all regions selected for redaction
        _selectedRegionIds = State(initialValue: Set(detectedRegions.map { $0.id }))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning header
                warningHeader

                // Image with highlighted regions
                ScrollView {
                    VStack(spacing: 16) {
                        imagePreview
                        detectedTextList
                    }
                    .padding()
                }

                // Action buttons
                actionButtons
            }
            .navigationTitle("PHI Detected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .onAppear {
                generateHighlightedImage()
            }
            .sheet(isPresented: $showingRedactionPreview) {
                redactionPreviewSheet
            }
            .sheet(isPresented: $showingManualRedaction) {
                ManualRedactionView(
                    image: originalImage,
                    existingRects: manualRedactionRects,
                    onSave: { rects in
                        manualRedactionRects = rects
                        showingManualRedaction = false
                        // Apply manual redaction
                        if let redacted = RedactionService.shared.applyManualRedaction(to: originalImage, rects: rects) {
                            onRedactAndSave(redacted)
                        }
                    },
                    onCancel: {
                        showingManualRedaction = false
                    }
                )
            }
        }
    }

    // MARK: - Warning Header

    private var warningHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("Text Detected")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("This image contains text that may include PHI. You must redact or crop before saving.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .background(Color.red)
    }

    // MARK: - Image Preview

    private var imagePreview: some View {
        Group {
            if let highlighted = highlightedImage {
                Image(uiImage: highlighted)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            } else {
                Image(uiImage: originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 4)
            }
        }
    }

    // MARK: - Detected Text List

    private var detectedTextList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Text (\(detectedRegions.count))")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            ForEach(detectedRegions) { region in
                HStack {
                    Image(systemName: selectedRegionIds.contains(region.id) ? "checkmark.square.fill" : "square")
                        .foregroundStyle(selectedRegionIds.contains(region.id) ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(region.text)
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                            .lineLimit(1)

                        Text("Confidence: \(Int(region.confidence * 100))%")
                            .font(.caption2)
                            .foregroundStyle(ProcedusTheme.textTertiary)
                    }

                    Spacer()

                    Image(systemName: "rectangle.inset.filled")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .padding(12)
                .background(selectedRegionIds.contains(region.id) ? Color.red.opacity(0.05) : ProcedusTheme.cardBackground)
                .cornerRadius(8)
                .onTapGesture {
                    toggleRegionSelection(region.id)
                }
            }

            // Select All / Deselect All
            HStack {
                Button("Select All") {
                    selectedRegionIds = Set(detectedRegions.map { $0.id })
                    generateHighlightedImage()
                }
                .font(.caption)
                .foregroundStyle(ProcedusTheme.primary)

                Spacer()

                Button("Deselect All") {
                    selectedRegionIds.removeAll()
                    generateHighlightedImage()
                }
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Redact All button (primary action)
            Button {
                previewRedaction()
            } label: {
                HStack {
                    Image(systemName: "rectangle.inset.filled")
                    Text(selectedRegionIds.count == detectedRegions.count ? "Redact All" : "Redact Selected (\(selectedRegionIds.count))")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(selectedRegionIds.isEmpty ? Color.gray : Color.red)
                .cornerRadius(12)
            }
            .disabled(selectedRegionIds.isEmpty)

            HStack(spacing: 8) {
                // Crop button
                Button {
                    onCropInstead()
                } label: {
                    HStack {
                        Image(systemName: "crop")
                        Text("Crop")
                    }
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(ProcedusTheme.primary.opacity(0.1))
                    .cornerRadius(10)
                }

                // Manual redaction button
                Button {
                    showingManualRedaction = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.badge.plus")
                        Text("Manual")
                    }
                    .font(.caption)
                    .foregroundStyle(.purple)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(10)
                }

                // Hand-drawn diagram button
                if let rescanAsDiagram = onRescanAsDiagram {
                    Button {
                        rescanAsDiagram()
                    } label: {
                        HStack {
                            Image(systemName: "hand.draw")
                            Text("Diagram")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }

            // Help text for diagram mode
            if onRescanAsDiagram != nil {
                Text("Tap 'Diagram' if this is a hand-drawn sketch. Only the patient label area (top-right) will require redaction.")
                    .font(.caption2)
                    .foregroundStyle(ProcedusTheme.textTertiary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
    }

    // MARK: - Redaction Preview Sheet

    private var redactionPreviewSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Preview Redaction")
                    .font(.headline)

                if let redacted = redactedImage {
                    Image(uiImage: redacted)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                }

                Text("Black rectangles will permanently cover the selected text regions.")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                // Confirm button
                Button {
                    if let redacted = redactedImage {
                        showingRedactionPreview = false
                        onRedactAndSave(redacted)
                    }
                } label: {
                    Text("Confirm & Save")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(ProcedusTheme.primary)
                        .cornerRadius(12)
                }
                .padding()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        showingRedactionPreview = false
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func toggleRegionSelection(_ id: UUID) {
        if selectedRegionIds.contains(id) {
            selectedRegionIds.remove(id)
        } else {
            selectedRegionIds.insert(id)
        }
        generateHighlightedImage()
    }

    private func generateHighlightedImage() {
        let selectedRegions = detectedRegions.filter { selectedRegionIds.contains($0.id) }
        highlightedImage = RedactionService.shared.drawPreviewHighlights(
            on: originalImage,
            regions: selectedRegions
        )
    }

    private func previewRedaction() {
        let selectedRegions = detectedRegions.filter { selectedRegionIds.contains($0.id) }
        redactedImage = RedactionService.shared.applyRedaction(
            to: originalImage,
            regions: selectedRegions
        )
        showingRedactionPreview = true
    }
}

// MARK: - No PHI Confirmation View

// MARK: - Manual Redaction View

/// Allows user to draw rectangles manually for PHI redaction
struct ManualRedactionView: View {
    let image: UIImage
    let existingRects: [CGRect]
    let onSave: ([CGRect]) -> Void
    let onCancel: () -> Void

    @State private var rects: [CGRect] = []
    @State private var currentRect: CGRect?
    @State private var dragStart: CGPoint?
    @State private var imageDisplaySize: CGSize = .zero

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Instructions
                HStack(spacing: 8) {
                    Image(systemName: "hand.draw")
                        .foregroundStyle(.purple)
                    Text("Draw rectangles over areas to redact")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                }
                .padding()
                .background(Color.purple.opacity(0.1))

                // Image with drawing overlay
                GeometryReader { geometry in
                    let aspectRatio = image.size.width / image.size.height
                    let containerAspect = geometry.size.width / geometry.size.height

                    let displaySize: CGSize = {
                        if aspectRatio > containerAspect {
                            return CGSize(width: geometry.size.width, height: geometry.size.width / aspectRatio)
                        } else {
                            return CGSize(width: geometry.size.height * aspectRatio, height: geometry.size.height)
                        }
                    }()

                    let offsetX = (geometry.size.width - displaySize.width) / 2
                    let offsetY = (geometry.size.height - displaySize.height) / 2

                    ZStack {
                        // Image
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)

                        // Existing rectangles
                        ForEach(rects.indices, id: \.self) { index in
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: rects[index].width, height: rects[index].height)
                                .position(x: rects[index].midX, y: rects[index].midY)
                                .onTapGesture {
                                    rects.remove(at: index)
                                }
                        }

                        // Current drawing rectangle
                        if let rect = currentRect {
                            Rectangle()
                                .stroke(Color.red, lineWidth: 2)
                                .background(Color.red.opacity(0.2))
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                        }
                    }
                    .frame(width: displaySize.width, height: displaySize.height)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                // Adjust for image offset
                                let adjustedStart = CGPoint(
                                    x: value.startLocation.x - offsetX,
                                    y: value.startLocation.y - offsetY
                                )
                                let adjustedCurrent = CGPoint(
                                    x: value.location.x - offsetX,
                                    y: value.location.y - offsetY
                                )

                                // Clamp to image bounds
                                let clampedStart = CGPoint(
                                    x: max(0, min(displaySize.width, adjustedStart.x)),
                                    y: max(0, min(displaySize.height, adjustedStart.y))
                                )
                                let clampedEnd = CGPoint(
                                    x: max(0, min(displaySize.width, adjustedCurrent.x)),
                                    y: max(0, min(displaySize.height, adjustedCurrent.y))
                                )

                                let minX = min(clampedStart.x, clampedEnd.x)
                                let minY = min(clampedStart.y, clampedEnd.y)
                                let width = abs(clampedEnd.x - clampedStart.x)
                                let height = abs(clampedEnd.y - clampedStart.y)

                                currentRect = CGRect(x: minX, y: minY, width: width, height: height)
                            }
                            .onEnded { _ in
                                if let rect = currentRect, rect.width > 10, rect.height > 10 {
                                    rects.append(rect)
                                }
                                currentRect = nil
                            }
                    )
                    .onAppear {
                        imageDisplaySize = displaySize
                    }
                    .onChange(of: geometry.size) { _, _ in
                        imageDisplaySize = displaySize
                    }
                }
                .padding()

                // Rect count and clear button
                HStack {
                    Text("\(rects.count) area(s) marked")
                        .font(.caption)
                        .foregroundStyle(ProcedusTheme.textSecondary)

                    Spacer()

                    if !rects.isEmpty {
                        Button("Clear All") {
                            rects.removeAll()
                        }
                        .font(.caption)
                        .foregroundStyle(.red)
                    }
                }
                .padding(.horizontal)

                // Save button
                Button {
                    // Convert display rects to normalized coordinates
                    let normalizedRects = rects.map { rect -> CGRect in
                        CGRect(
                            x: rect.origin.x / imageDisplaySize.width,
                            y: rect.origin.y / imageDisplaySize.height,
                            width: rect.width / imageDisplaySize.width,
                            height: rect.height / imageDisplaySize.height
                        )
                    }
                    onSave(normalizedRects)
                } label: {
                    Text("Apply Redaction")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(rects.isEmpty ? Color.gray : Color.purple)
                        .cornerRadius(12)
                }
                .disabled(rects.isEmpty)
                .padding()
            }
            .navigationTitle("Manual Redaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
            }
            .onAppear {
                rects = existingRects
            }
        }
    }
}

/// Shown when no text is detected - user must confirm no PHI
struct NoPHIConfirmationView: View {
    let image: UIImage
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var isConfirmed = false

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

                    Text("Our scan didn't find any text in this image.")
                        .font(.subheadline)
                        .foregroundStyle(ProcedusTheme.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 250)
                    .cornerRadius(12)

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

                            Text("I confirm this image does not contain any Protected Health Information (PHI), including patient names, dates of birth, or other identifying information.")
                                .font(.subheadline)
                                .foregroundStyle(ProcedusTheme.textPrimary)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        onConfirm()
                    } label: {
                        Text("Save Image")
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
        }
    }
}
