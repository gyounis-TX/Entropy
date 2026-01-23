// MediaPickerView.swift
// Procedus - Unified
// Photo and video picker with camera capture option

import SwiftUI
import PhotosUI
import AVFoundation

/// Result from media picker
struct MediaPickerResult {
    let image: UIImage?
    let videoURL: URL?
    let mediaType: MediaType

    var isImage: Bool { mediaType == .image }
    var isVideo: Bool { mediaType == .video }
}

struct MediaPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let onMediaSelected: (MediaPickerResult) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingSourcePicker = true
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                if isProcessing {
                    processingView
                } else if showingSourcePicker {
                    sourcePickerView
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding()
                }
            }
            .padding()
            .navigationTitle("Add Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $selectedItem,
                matching: .any(of: [.images, .videos]),
                preferredItemEncoding: .current
            )
            .onChange(of: selectedItem) { _, newValue in
                if let item = newValue {
                    Task {
                        await processSelectedItem(item)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    handleCameraCapture(image)
                }
            }
        }
    }

    // MARK: - Source Picker View

    private var sourcePickerView: some View {
        VStack(spacing: 20) {
            Text("Choose Media Source")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            HStack(spacing: 24) {
                // Camera button
                Button {
                    checkCameraPermissionAndShow()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 40))
                        Text("Camera")
                            .font(.subheadline)
                    }
                    .frame(width: 120, height: 120)
                    .foregroundStyle(ProcedusTheme.primary)
                    .background(ProcedusTheme.primary.opacity(0.1))
                    .cornerRadius(16)
                }

                // Photo Library button
                Button {
                    showingPhotoPicker = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40))
                        Text("Library")
                            .font(.subheadline)
                    }
                    .frame(width: 120, height: 120)
                    .foregroundStyle(ProcedusTheme.accent)
                    .background(ProcedusTheme.accent.opacity(0.1))
                    .cornerRadius(16)
                }
            }

            Text("Maximum file size: 10 MB")
                .font(.caption)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Processing media...")
                .font(.subheadline)
                .foregroundStyle(ProcedusTheme.textSecondary)
        }
    }

    // MARK: - Camera Permission

    private func checkCameraPermissionAndShow() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        errorMessage = "Camera access is required to take photos"
                    }
                }
            }
        case .denied, .restricted:
            errorMessage = "Camera access denied. Enable in Settings."
        @unknown default:
            errorMessage = "Unable to access camera"
        }
    }

    // MARK: - Handle Camera Capture

    private func handleCameraCapture(_ image: UIImage?) {
        showingCamera = false

        guard let image = image else { return }

        // Check if captured image data exceeds size limit
        guard let imageData = image.jpegData(compressionQuality: 0.8),
              imageData.count <= CaseMedia.maxFileSizeBytes else {
            errorMessage = "Image exceeds 10 MB limit. Try a lower resolution."
            return
        }

        let result = MediaPickerResult(image: image, videoURL: nil, mediaType: .image)
        onMediaSelected(result)
        dismiss()
    }

    // MARK: - Process Selected Item

    @MainActor
    private func processSelectedItem(_ item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil

        // Try loading as image first
        if let data = try? await item.loadTransferable(type: Data.self) {
            // Check file size
            if data.count > CaseMedia.maxFileSizeBytes {
                isProcessing = false
                errorMessage = "File exceeds 10 MB limit (\(MediaStorageService.shared.formattedFileSize(data.count)))"
                selectedItem = nil
                return
            }

            // Check if it's an image
            if let image = UIImage(data: data) {
                isProcessing = false
                let result = MediaPickerResult(image: image, videoURL: nil, mediaType: .image)
                onMediaSelected(result)
                dismiss()
                return
            }
        }

        // Try loading as video
        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            // Check file size
            if let attrs = try? FileManager.default.attributesOfItem(atPath: movie.url.path),
               let size = attrs[.size] as? Int,
               size > CaseMedia.maxFileSizeBytes {
                isProcessing = false
                errorMessage = "Video exceeds 10 MB limit (\(MediaStorageService.shared.formattedFileSize(size)))"
                selectedItem = nil
                // Clean up temp file
                try? FileManager.default.removeItem(at: movie.url)
                return
            }

            isProcessing = false
            let result = MediaPickerResult(image: nil, videoURL: movie.url, mediaType: .video)
            onMediaSelected(result)
            dismiss()
            return
        }

        isProcessing = false
        errorMessage = "Unable to load selected media"
        selectedItem = nil
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // Copy to temp location
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Camera View (UIImagePickerController wrapper)

struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage?) -> Void

        init(onCapture: @escaping (UIImage?) -> Void) {
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            picker.dismiss(animated: true) {
                self.onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true) {
                self.onCapture(nil)
            }
        }
    }
}
