import SwiftUI

/// A SwiftUI view for sharing QR codes
struct QRCodeShareSheetView: View {
    // MARK: - Properties

    /// The view model for the QR code share sheet
    @ObservedObject var viewModel: QRCodeShareSheetViewModel

    /// State for the shareable image
    @State private var shareableImage: UIImage? = nil

    /// State to track if the image has been generated
    @State private var hasGeneratedImage: Bool = false

    /// The callback for when the sheet is dismissed
    var onDismiss: () -> Void

    // MARK: - Initialization

    /// Initialize with a QR code ID, name, and dismiss callback
    /// - Parameters:
    ///   - qrCodeId: The QR code ID
    ///   - name: The name to display
    ///   - onDismiss: The callback for when the sheet is dismissed
    init(
        qrCodeId: String,
        name: String,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = QRCodeShareSheetViewModel(
            name: name,
            qrCodeId: qrCodeId
        )
        self.onDismiss = onDismiss
    }

    /// Initialize with a view model and dismiss callback
    /// - Parameters:
    ///   - viewModel: The view model
    ///   - onDismiss: The callback for when the sheet is dismissed
    init(
        viewModel: QRCodeShareSheetViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            Text("Share QR Code")
                .font(.title)
                .padding(.top)

            // Preview of the shareable image with text
            HStack(alignment: .center, spacing: 16) {
                if let image = shareableImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 180)
                        .cornerRadius(8)
                        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                } else {
                    // Placeholder while image is generating
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 100, height: 180)
                        .cornerRadius(8)
                }

                Text("My LifeSignal QR Code")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            // QR Code Card View (directly implemented here)
            qrCodeCardView
                .frame(height: 400) // Fixed height for the card

            Button(action: {
                // Share the already generated image
                viewModel.setShowingShareSheet(true)
            }) {
                Label("Share QR Code", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
            .padding(.horizontal)
            .disabled(shareableImage == nil) // Disable until image is generated

            Button(action: {
                onDismiss()
            }) {
                Text("Close")
                    .foregroundColor(.blue)
            }
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $viewModel.isShowingShareSheet) {
            if let image = shareableImage {
                QRCodeShareSheet(items: [image])
            }
        }
        .onAppear {
            // Generate the shareable image when the view appears
            if !hasGeneratedImage {
                // Mark as generating to prevent duplicate calls
                hasGeneratedImage = true

                // Use Task to handle the async operation
                Task {
                    // Use a slight delay to ensure the view is fully loaded
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds

                    // Generate the image on the main actor
                    await MainActor.run {
                        generateShareableImage()
                    }
                }
            }
        }
    }

    // MARK: - QR Code Card View

    /// The QR code card view for display in the UI
    private var qrCodeCardView: some View {
        viewModel.createQRCodeCardView(useHighResQRCode: false, forSharing: false)
    }

    // MARK: - Methods

    /// Generate a shareable image from the QR code card view
    private func generateShareableImage() {
        // Use the view model to generate the shareable image
        // This is called on the main actor, so we're already on the main thread
        viewModel.generateShareableImage { image in
            // No need for [weak self] in a struct
            self.shareableImage = image
        }
    }
}

#Preview {
    QRCodeShareSheetView(
        qrCodeId: "https://example.com",
        name: "John Doe",
        onDismiss: {}
    )
}
