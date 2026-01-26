// MediaPickerView.swift
// Procedus - Unified
// Photo and video picker with camera capture option

import SwiftUI
import PhotosUI
import AVFoundation
import UniformTypeIdentifiers

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
    @State private var showingFilePicker = false
    @State private var showingSourcePicker = true
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var selectedVideoSize: Int?

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
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: [.image, .movie],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
        }
    }

    // MARK: - Source Picker View

    private var sourcePickerView: some View {
        VStack(spacing: 20) {
            Text("Choose Media Source")
                .font(.headline)
                .foregroundStyle(ProcedusTheme.textPrimary)

            HStack(spacing: 16) {
                // Camera button
                Button {
                    checkCameraPermissionAndShow()
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 32))
                        Text("Camera")
                            .font(.caption)
                    }
                    .frame(width: 100, height: 100)
                    .foregroundStyle(ProcedusTheme.primary)
                    .background(ProcedusTheme.primary.opacity(0.1))
                    .cornerRadius(16)
                }

                // Photo Library button
                Button {
                    showingPhotoPicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 32))
                        Text("Library")
                            .font(.caption)
                    }
                    .frame(width: 100, height: 100)
                    .foregroundStyle(ProcedusTheme.accent)
                    .background(ProcedusTheme.accent.opacity(0.1))
                    .cornerRadius(16)
                }

                // Files button
                Button {
                    showingFilePicker = true
                } label: {
                    VStack(spacing: 10) {
                        Image(systemName: "folder.fill")
                            .font(.system(size: 32))
                        Text("Files")
                            .font(.caption)
                    }
                    .frame(width: 100, height: 100)
                    .foregroundStyle(.orange)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                }
            }

            // Video size indicator (if video was selected)
            if let size = selectedVideoSize {
                HStack(spacing: 8) {
                    Image(systemName: "video.fill")
                        .foregroundStyle(.secondary)
                    Text("Video size: \(MediaStorageService.shared.formattedFileSize(size))")
                        .font(.subheadline)
                    if size > CaseMedia.maxVideoFileSizeBytes {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(size > CaseMedia.maxVideoFileSizeBytes ? Color.red.opacity(0.1) : Color.green.opacity(0.1))
                .cornerRadius(8)
            }

            Text("Images: 10 MB max • Videos: 200 MB max")
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
        // Don't dismiss - let the parent flow handle navigation
    }

    // MARK: - Process Selected Item

    @MainActor
    private func processSelectedItem(_ item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        selectedVideoSize = nil

        // Try loading as image first
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            // It's an image — check image size limit
            if data.count > CaseMedia.maxFileSizeBytes {
                isProcessing = false
                errorMessage = "Image exceeds 10 MB limit (\(MediaStorageService.shared.formattedFileSize(data.count)))"
                selectedItem = nil
                return
            }

            isProcessing = false
            let result = MediaPickerResult(image: image, videoURL: nil, mediaType: .image)
            onMediaSelected(result)
            return
        }

        // Try loading as video
        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            // Check file size and show it
            if let attrs = try? FileManager.default.attributesOfItem(atPath: movie.url.path),
               let size = attrs[.size] as? Int {

                selectedVideoSize = size

                if size > CaseMedia.maxVideoFileSizeBytes {
                    isProcessing = false
                    errorMessage = "Video exceeds 200 MB limit (\(MediaStorageService.shared.formattedFileSize(size)))"
                    selectedItem = nil
                    try? FileManager.default.removeItem(at: movie.url)
                    return
                }
            }

            isProcessing = false
            let result = MediaPickerResult(image: nil, videoURL: movie.url, mediaType: .video)
            onMediaSelected(result)
            return
        }

        isProcessing = false
        errorMessage = "Unable to load selected media"
        selectedItem = nil
    }

    // MARK: - Handle File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Unable to access file"
                return
            }

            defer { url.stopAccessingSecurityScopedResource() }

            // Check file size
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? Int else {
                errorMessage = "Unable to read file size"
                return
            }

            // Process based on file type
            let pathExtension = url.pathExtension.lowercased()
            let imageExtensions = ["jpg", "jpeg", "png", "heic", "heif", "gif", "bmp", "tiff"]
            let videoExtensions = ["mov", "mp4", "m4v", "avi"]

            // Check appropriate size limit
            let isVideo = videoExtensions.contains(pathExtension)
            let maxSize = isVideo ? CaseMedia.maxVideoFileSizeBytes : CaseMedia.maxFileSizeBytes
            if size > maxSize {
                let limitStr = isVideo ? "200 MB" : "10 MB"
                errorMessage = "File exceeds \(limitStr) limit (\(MediaStorageService.shared.formattedFileSize(size)))"
                return
            }

            if imageExtensions.contains(pathExtension) {
                if let data = try? Data(contentsOf: url), let image = UIImage(data: data) {
                    let result = MediaPickerResult(image: image, videoURL: nil, mediaType: .image)
                    onMediaSelected(result)
                } else {
                    errorMessage = "Unable to load image"
                }
            } else if videoExtensions.contains(pathExtension) {
                selectedVideoSize = size

                // Copy video to temp location
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "." + pathExtension)
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    let result = MediaPickerResult(image: nil, videoURL: tempURL, mediaType: .video)
                    onMediaSelected(result)
                } catch {
                    errorMessage = "Failed to copy video file"
                }
            } else {
                errorMessage = "Unsupported file type"
            }

        case .failure(let error):
            errorMessage = "Failed to import file: \(error.localizedDescription)"
        }
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
