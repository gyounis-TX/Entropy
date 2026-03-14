import SwiftUI
import VisionKit
import PhotosUI

/// UIKit bridge for VNDocumentCameraViewController — the native iOS document scanner.
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            onScan(images)
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onCancel()
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            print("Document scanner failed: \(error)")
            onCancel()
        }
    }
}

/// Combined photo source picker: Camera scanner, Photo Library, or regular Camera.
struct DocumentImagePicker: View {
    @Binding var frontImage: Data?
    @Binding var backImage: Data?
    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var showingCamera = false
    @State private var pickingTarget: PickTarget = .front
    @State private var selectedPhotoItem: PhotosPickerItem?

    enum PickTarget {
        case front, back
    }

    var body: some View {
        VStack(spacing: 12) {
            // Front image
            imageSlot(
                label: "Front",
                imageData: frontImage,
                target: .front
            )

            // Back image
            imageSlot(
                label: "Back",
                imageData: backImage,
                target: .back
            )

            // Action buttons
            HStack(spacing: 12) {
                if VNDocumentCameraViewController.isSupported {
                    Button {
                        showingScanner = true
                    } label: {
                        Label("Scan Document", systemImage: "doc.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("Photo Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .sheet(isPresented: $showingScanner) {
            DocumentScannerView(
                onScan: { images in
                    showingScanner = false
                    handleScannedImages(images)
                },
                onCancel: { showingScanner = false }
            )
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem,
                       matching: .images)
        .onChange(of: selectedPhotoItem) {
            Task { await loadSelectedPhoto() }
        }
    }

    @ViewBuilder
    private func imageSlot(label: String, imageData: Data?, target: PickTarget) -> some View {
        GroupBox(label) {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(alignment: .topTrailing) {
                        Button {
                            switch target {
                            case .front: frontImage = nil
                            case .back: backImage = nil
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .red)
                        }
                        .padding(4)
                    }
                    .onTapGesture {
                        pickingTarget = target
                        showingPhotoPicker = true
                    }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                    .frame(height: 120)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Tap to add \(label.lowercased())")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .onTapGesture {
                        pickingTarget = target
                        showingPhotoPicker = true
                    }
            }
        }
    }

    private func handleScannedImages(_ images: [UIImage]) {
        if let first = images.first {
            frontImage = first.jpegData(compressionQuality: 0.8)
        }
        if images.count > 1 {
            backImage = images[1].jpegData(compressionQuality: 0.8)
        }
    }

    private func loadSelectedPhoto() async {
        guard let item = selectedPhotoItem else { return }
        guard let data = try? await item.loadTransferable(type: Data.self) else { return }

        switch pickingTarget {
        case .front: frontImage = data
        case .back: backImage = data
        }
        selectedPhotoItem = nil
    }
}
