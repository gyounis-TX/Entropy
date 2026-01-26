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

    @State private var showingManualRedaction = false
    @State private var manualRedactionRects: [CGRect] = []
    @State private var showingSkipAttestation = false
    @State private var skipAttestationConfirmed = false
    @State private var showingAutoRedactionPreview = false
    @State private var autoRedactedImage: UIImage?

    init(
        originalImage: UIImage,
        detectedRegions: [DetectedTextRegion],
        onRedactAndSave: @escaping (UIImage) -> Void,
        onCropInstead: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.originalImage = originalImage
        self.detectedRegions = detectedRegions
        self.onRedactAndSave = onRedactAndSave
        self.onCropInstead = onCropInstead
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Warning header
                warningHeader

                // Image preview (no highlighted boxes)
                ScrollView {
                    VStack(spacing: 16) {
                        imagePreview

                        // Info text
                        VStack(spacing: 8) {
                            Text("\(detectedRegions.count) text region(s) detected")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("You can accept automatic redaction, crop, draw manual redaction boxes, or proceed without editing.")
                                .font(.caption)
                                .foregroundStyle(ProcedusTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding()
                }

                // Action buttons
                actionButtons
            }
            .navigationTitle("Text Detected")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
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
            .sheet(isPresented: $showingSkipAttestation) {
                skipAttestationSheet
            }
            .sheet(isPresented: $showingAutoRedactionPreview) {
                autoRedactionPreviewSheet
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
                Text("This image may contain PHI. Choose how to handle detected text below.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()
        }
        .padding()
        .background(Color.orange)
    }

    // MARK: - Image Preview

    private var highlightedImage: UIImage {
        RedactionService.shared.drawPreviewHighlights(
            on: originalImage,
            regions: detectedRegions
        ) ?? originalImage
    }

    private var imagePreview: some View {
        Image(uiImage: highlightedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxHeight: 300)
            .cornerRadius(12)
            .shadow(radius: 4)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Accept AI Redaction (primary action)
            Button {
                if let redacted = RedactionService.shared.applyRedaction(to: originalImage, regions: detectedRegions) {
                    autoRedactedImage = redacted
                    showingAutoRedactionPreview = true
                }
            } label: {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Accept AI Redaction")
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }

            // Crop button (secondary)
            Button {
                onCropInstead()
            } label: {
                HStack {
                    Image(systemName: "crop")
                    Text("Crop Image")
                }
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(ProcedusTheme.primary.opacity(0.1))
                .cornerRadius(12)
            }

            // Manual redaction button
            Button {
                showingManualRedaction = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.badge.plus")
                    Text("Draw Redaction Boxes")
                }
                .font(.subheadline)
                .foregroundStyle(.purple)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple.opacity(0.1))
                .cornerRadius(12)
            }

            // Skip (proceed without editing) - requires attestation
            Button {
                showingSkipAttestation = true
            } label: {
                Text("Proceed Without Editing")
                    .font(.caption)
                    .foregroundStyle(ProcedusTheme.textSecondary)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(ProcedusTheme.cardBackground)
    }

    // MARK: - Skip Attestation Sheet

    private var skipAttestationSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "exclamationmark.shield.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.orange)

                Text("Proceed Without Editing?")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Text was detected in this image. By proceeding, you confirm that you have reviewed the image and it does not contain any Protected Health Information (PHI).")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Attestation toggle
                Button {
                    skipAttestationConfirmed.toggle()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: skipAttestationConfirmed ? "checkmark.square.fill" : "square")
                            .font(.title2)
                            .foregroundStyle(skipAttestationConfirmed ? ProcedusTheme.primary : ProcedusTheme.textSecondary)

                        Text("I confirm this image does not contain any PHI, including patient names, dates of birth, medical record numbers, or other identifying information.")
                            .font(.caption)
                            .foregroundStyle(ProcedusTheme.textPrimary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .buttonStyle(.plain)
                .padding()
                .background(ProcedusTheme.cardBackground)
                .cornerRadius(12)

                Spacer()

                // Continue button
                Button {
                    showingSkipAttestation = false
                    onRedactAndSave(originalImage)
                } label: {
                    Text("Continue Without Editing")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(skipAttestationConfirmed ? ProcedusTheme.primary : Color.gray)
                        .cornerRadius(12)
                }
                .disabled(!skipAttestationConfirmed)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        showingSkipAttestation = false
                        skipAttestationConfirmed = false
                    }
                }
            }
        }
    }

    // MARK: - Auto Redaction Preview Sheet

    private var autoRedactionPreviewSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.green)

                Text("AI Redaction Preview")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(detectedRegions.count) region(s) automatically redacted")
                    .font(.subheadline)
                    .foregroundStyle(ProcedusTheme.textSecondary)

                if let redacted = autoRedactedImage {
                    Image(uiImage: redacted)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 4)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showingAutoRedactionPreview = false
                        if let redacted = autoRedactedImage {
                            onRedactAndSave(redacted)
                        }
                    } label: {
                        Text("Use This Image")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    Button {
                        showingAutoRedactionPreview = false
                        autoRedactedImage = nil
                    } label: {
                        Text("Go Back")
                            .font(.subheadline)
                            .foregroundStyle(ProcedusTheme.textSecondary)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Back") {
                        showingAutoRedactionPreview = false
                        autoRedactedImage = nil
                    }
                }
            }
        }
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
