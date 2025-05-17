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

    /// Environment presentation mode for dismissing the sheet
    @Environment(\.presentationMode) var presentationMode

    /// Whether to show the add contact sheet
    @State private var showAddContactSheet = false

    /// The scanned QR code for the add contact sheet
    @State private var scannedQRCode: String? = nil

    // MARK: - Initialization

    /// Initialize with a callback for when a QR code is scanned
    /// - Parameter onScanned: The callback for when a QR code is scanned
    init(onScanned: @escaping (String) -> Void) {
        self.onScanned = onScanned
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Camera view will be shown behind the gallery sheet
            // Camera view or camera failed view
            if viewModel.cameraLoadFailed {
                cameraFailedView
            } else {
                cameraView
                    .environmentObject(viewModel)

                // Buttons will be moved to a horizontal stack at the bottom
            }

            // Overlay controls
            VStack {
                // Top controls
                HStack {
                    // Close button
                    Button(action: {
                        HapticFeedback.triggerHaptic()
                        viewModel.setShowScanner(false)
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(12)
                    }

                    Spacer()

                    // Torch button
                    Button(action: {
                        HapticFeedback.triggerHaptic()
                        viewModel.toggleTorch()
                    }) {
                        Image(systemName: viewModel.torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.title2)
                            .foregroundColor(viewModel.torchOn ? .yellow : .white)
                            .padding(12)
                    }
                }
                .padding(4)

                Spacer()

                // Bottom controls
                VStack {
                    // Gallery carousel
                    VStack(spacing: 10) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 5) { // Reduced spacing between items
                                // Gallery thumbnails
                                ForEach(0..<viewModel.galleryThumbnails.count, id: \.self) { index in
                                    Button(action: {
                                        HapticFeedback.lightImpact()
                                        viewModel.setSelectedGalleryIndex(index)
                                    }) {
                                        Image(uiImage: viewModel.galleryThumbnails[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 90, height: 90) // Increased item size
                                            .clipShape(Rectangle()) // Removed rounded corners
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .frame(height: 100) // Increased height for larger items

                        // Horizontal stack for buttons
                        HStack {
                            // Manual Entry button
                            Button(action: {
                                HapticFeedback.triggerHaptic()
                                viewModel.isShowingManualEntry = true
                            }) {
                                Text("By QR Code ID")
                                    .font(.subheadline)
                                    .foregroundColor(.white)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 12)
                                    .cornerRadius(8)
                            }

                            Spacer()

                            // Gallery button
                            Button(action: {
                                HapticFeedback.triggerHaptic()
                                viewModel.isShowingGallery = true
                            }) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 48)
                    }
                }
            }

            // No processing overlay is shown
        }
        .onAppear {
            // Ensure no processing state is shown when view appears
            viewModel.isProcessingQRCode = false

            // Set up the QR code handler
            viewModel.onQRCodeScanned = { qrCode in
                // Stop processing state
                viewModel.isProcessingQRCode = false
                // Store the scanned QR code and show the add contact sheet
                scannedQRCode = qrCode
                showAddContactSheet = true
            }

            // Initialize the camera
            viewModel.initializeCamera()
        }
        .sheet(isPresented: $viewModel.isShowingManualEntry) {
            NavigationStack {
                VStack(alignment: .center, spacing: 20) {
                    Text("Enter QR Code ID")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.top, 20)

                    // Verification code style text field with paste button
                    ZStack(alignment: .trailing) {
                        TextField("QR Code ID", text: $viewModel.manualQRCode)
                            .keyboardType(.default)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.center)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .onChange(of: viewModel.manualQRCode) { oldValue, newValue in
                                // Limit to 36 characters (UUID format)
                                if newValue.count > 36 {
                                    viewModel.manualQRCode = String(newValue.prefix(36))
                                }
                            }

                        // Paste button that only shows when text field is empty
                        if viewModel.manualQRCode.isEmpty {
                            Button(action: {
                                HapticFeedback.lightImpact()
                                // Get text from clipboard
                                let pasteboard = UIPasteboard.general
                                if let pastedText = pasteboard.string {
                                    // Check if it's a valid UUID
                                    if UUID(uuidString: pastedText) != nil {
                                        viewModel.manualQRCode = pastedText
                                    } else {
                                        // Show alert for invalid UUID
                                        viewModel.showInvalidUUIDAlert = true
                                    }
                                }
                            }) {
                                Image(systemName: "doc.on.clipboard")
                                    .foregroundColor(.blue)
                                    .padding(.trailing, 16)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Add validation for QR code format
                    let isValidFormat = viewModel.isValidQRCodeFormat(viewModel.manualQRCode)

                    // Verify button style
                    Button(action: {
                        if !viewModel.manualQRCode.isEmpty && isValidFormat {
                            HapticFeedback.notificationFeedback(type: .success)
                            // Process the manually entered QR code
                            viewModel.handleScannedQRCode(viewModel.manualQRCode)
                            viewModel.isShowingManualEntry = false
                        }
                    }) {
                        Text("Add Contact")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .background(viewModel.manualQRCode.isEmpty || !isValidFormat ? Color.gray : Color.blue)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .disabled(viewModel.manualQRCode.isEmpty || !isValidFormat)

                    Spacer()
                }
                .padding()
                .background(Color(UIColor.systemGroupedBackground))
                .navigationBarTitle("Manual Entry", displayMode: .inline)
                .navigationBarItems(leading: Button("Cancel") {
                    HapticFeedback.triggerHaptic()
                    viewModel.isShowingManualEntry = false
                    viewModel.manualQRCode = ""
                })
            }
        }
        .sheet(isPresented: $viewModel.isShowingGallery) {
            // Photo picker as a sheet instead of fullScreenCover
            PhotoPickerView(onImageSelected: { image in
                viewModel.isShowingGallery = false

                // Ensure no processing state is shown
                viewModel.isProcessingQRCode = false

                // Check if the image contains a QR code
                // For the mock app, we'll simulate QR code detection
                // In a real app, we would use a QR code detector
                // Use a random chance of finding a QR code for demo purposes
                // In production, this would be a real QR code detection
                let randomChance = Double.random(in: 0...1)
                let qrCodeFound = randomChance < 0.9 // 90% chance of finding a QR code

                if qrCodeFound {
                    // QR code found - store the scanned QR code and show the add contact sheet
                    let generatedCode = "gallery-qr-code-\(Int.random(in: 1000...9999))"
                    scannedQRCode = generatedCode
                    showAddContactSheet = true
                } else {
                    // No QR code found - show alert
                    viewModel.showNoQRCodeAlert = true
                }
            })
        }
        .alert("No QR Code Found", isPresented: $viewModel.showNoQRCodeAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The selected image does not contain a valid QR code. Please try another image.")
        }
        .alert("Invalid UUID Format", isPresented: $viewModel.showInvalidUUIDAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The clipboard content is not a valid UUID format.")
        }
        .sheet(isPresented: $showAddContactSheet, onDismiss: {
            // When the add contact sheet is dismissed, call the onScanned callback with the scanned QR code
            // and dismiss the QR scanner sheet
            if let code = scannedQRCode {
                onScanned(code)
                presentationMode.wrappedValue.dismiss()
            }
        }) {
            if let code = scannedQRCode {
                AddContactSheetView(
                    qrCodeId: code,
                    onAddContact: { contact in
                        // Close the add contact sheet
                        showAddContactSheet = false
                    },
                    onClose: {
                        // Close the add contact sheet
                        showAddContactSheet = false
                    }
                )
            }
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
                    HapticFeedback.triggerHaptic()
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
                    HapticFeedback.triggerHaptic()
                    // Ensure no processing state is shown
                    viewModel.isProcessingQRCode = false
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
