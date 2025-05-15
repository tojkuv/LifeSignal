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
            // Camera view or camera failed view
            if viewModel.cameraLoadFailed {
                cameraFailedView
            } else {
                cameraView
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
                        Image(systemName: viewModel.torchOn ? "bolt.fill" : "bolt.slash.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                    }
                }
                
                Spacer()
                
                // Bottom controls
                VStack {
                    // Gallery carousel
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
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(viewModel.selectedGalleryIndex == index ? Color.blue : Color.white, lineWidth: 2)
                                        )
                                }
                            }
                            
                            // Gallery picker button
                            Button(action: {
                                viewModel.isShowingGallery = true
                            }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white)
                                    .frame(width: 60, height: 60)
                                    .background(Color.gray.opacity(0.5))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: 80)
                    .padding(.bottom)
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
            PhotoPickerView { image in
                if let image = image {
                    viewModel.loadAndProcessFullImage(image)
                }
            }
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
            // Mock camera view (black background with scanning animation)
            Color.black
                .edgesIgnoringSafeArea(.all)
                .overlay(
                    ZStack {
                        // Scanning animation
                        if viewModel.isCameraReady {
                            ScanningAnimationView()
                        } else {
                            // Loading indicator
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        }
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

/// A SwiftUI view for the scanning animation
struct ScanningAnimationView: View {
    @State private var animationOffset: CGFloat = -200
    
    var body: some View {
        ZStack {
            // Scanner frame
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 2)
                .frame(width: 250, height: 250)
            
            // Scanning line
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, .blue, .clear]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 250, height: 2)
                .offset(y: animationOffset)
        }
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 2.0)
                    .repeatForever(autoreverses: true)
            ) {
                animationOffset = 200
            }
        }
    }
}

/// A SwiftUI view for picking photos
struct PhotoPickerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onImagePicked: (UIImage?) -> Void
    
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
                parent.onImagePicked(nil)
                return
            }
            
            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    DispatchQueue.main.async {
                        self.parent.onImagePicked(image as? UIImage)
                    }
                }
            } else {
                parent.onImagePicked(nil)
            }
        }
    }
}

#Preview {
    QRScannerView { qrCode in
        print("Scanned QR code: \(qrCode)")
    }
}
