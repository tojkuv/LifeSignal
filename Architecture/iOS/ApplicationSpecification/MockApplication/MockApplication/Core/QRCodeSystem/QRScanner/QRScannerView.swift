import SwiftUI
import PhotosUI
import AVFoundation

/// A SwiftUI view for scanning QR codes
struct QRScannerView: View {
    // MARK: - Properties

    /// The view model for the QR scanner
    @StateObject private var viewModel = QRScannerViewModel()

    /// The callback for when a QR code is scanned
    var onScanned: (String) -> Void

    // MARK: - Initialization

    /// Initialize with a callback for when a QR code is scanned
    /// - Parameter onScanned: The callback for when a QR code is scanned
    init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Show gallery picker if needed
            if viewModel.isShowingGallery {
                PhotoPickerView(onImageSelected: { image in
                    viewModel.isShowingGallery = false
                    // Process the selected image for QR codes
                    // In a real app, this would scan the image for QR codes
                    // For now, we'll just simulate a successful scan
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onScanned("gallery-qr-code-\(Int.random(in: 1000...9999))")
                    }
                })
            }
            // Camera view or camera failed view
            if viewModel.cameraLoadFailed {
                cameraFailedView
            } else {
                cameraView
                    .environmentObject(viewModel)

                // Helper text with fade animation
                VStack {
                    Spacer()

                    Text("Scan or upload a LifeSignal QR code")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                        .padding(.bottom, 100)
                        .opacity(viewModel.helperTextOpacity)
                        .onAppear {
                            withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                viewModel.helperTextOpacity = 0.7
                            }
                        }
                }
            }

            // Overlay controls
            VStack {
                // Top controls
                HStack {
                    // Close button
                    Button(action: {
                        viewModel.setShowScanner(false)
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }

                    Spacer()

                    // Torch button
                    Button(action: {
                        viewModel.toggleTorch()
                    }) {
                        Image(systemName: viewModel.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.torchOn ? .yellow : .white)
                            .padding()
                    }
                }

                Spacer()

                // Bottom controls
                VStack {
                    // Gallery carousel
                    VStack(spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                // Gallery thumbnails
                                ForEach(0..<viewModel.galleryThumbnails.count, id: \.self) { index in
                                    Button(action: {
                                        viewModel.setSelectedGalleryIndex(index)
                                    }) {
                                        Image(uiImage: viewModel.galleryThumbnails[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }

                                // Gallery picker button
                                Button(action: {
                                    viewModel.isShowingGallery = true
                                }) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                        .frame(width: 80, height: 80)
                                        .background(Color.gray.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 90)

                        // Open Photos button
                        Button(action: {
                            viewModel.isShowingGallery = true
                        }) {
                            Text("Open Photos")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                }
            }

            // Processing overlay
            if viewModel.isProcessingQRCode {
                Color.black.opacity(0.5)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        VStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)

                            Text("Processing QR Code...")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    )
            }
        }
        .onAppear {
            // Set up the QR code handler
            viewModel.onQRCodeScanned = { qrCode in
                onScanned(qrCode)
            }

            // Initialize the camera
            viewModel.initializeCamera()
        }
        .sheet(isPresented: $viewModel.isShowingGallery) {
            // Photo picker
            PhotoPickerView(onImageSelected: { image in
                viewModel.loadAndProcessFullImage(image)
            })
        }
        .alert("No QR Code Found", isPresented: $viewModel.showNoQRCodeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The selected image does not contain a valid QR code. Please try another image.")
        }
    }

    // MARK: - Subviews

    /// The camera view
    private var cameraView: some View {
        ZStack {
            // Camera view with scanning animation
            CameraPreviewView(torchOn: viewModel.torchOn)
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    ZStack {
                        // Scanning animation - always show it immediately without loading state
                        ScanningAnimationView()
                    }
                )
        }
    }

    /// The camera failed view
    private var cameraFailedView: some View {
        ZStack {
            Color.black
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)

                Text("Camera Access Required")
                    .font(.title2)
                    .foregroundColor(.white)

                Text("Please allow camera access in Settings to scan QR codes.")
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {
                    // Open settings
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Open Settings")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }

                Button(action: {
                    viewModel.isShowingGallery = true
                }) {
                    Text("Select from Gallery")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(10)
                }
            }
            .padding()
        }
    }
}

/// A SwiftUI view for the scanning animation - simplified without animation line
struct ScanningAnimationView: View {
    var body: some View {
        // Empty view - removed scanning animation and center square as requested
        Color.clear
    }
}

/// A SwiftUI view for picking photos
struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onImageSelected: (UIImage) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.presentationMode.wrappedValue.dismiss()

            guard let provider = results.first?.itemProvider else {
                // No image selected
                return
            }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            self.parent.onImageSelected(uiImage)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    QRScannerView { qrCode in
        print("Scanned QR code: \(qrCode)")
    }
}
