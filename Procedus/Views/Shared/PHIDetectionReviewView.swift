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

    @State private var highlightedImage: UIImage?
    @State private var selectedRegionIds: Set<UUID>
    @State private var showingRedactionPreview = false
    @State private var redactedImage: UIImage?

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

            // Crop Instead button
            Button {
                onCropInstead()
            } label: {
                HStack {
                    Image(systemName: "crop")
                    Text("Crop Instead")
                }
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.primary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(ProcedusTheme.primary.opacity(0.1))
                .cornerRadius(12)
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
