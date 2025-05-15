import SwiftUI

/// A SwiftUI view for displaying a QR code sheet
struct QRCodeSheetView: View {
    // MARK: - Properties
    
    /// The view model for the QR code sheet
    @ObservedObject var viewModel: QRCodeSheetViewModel
    
    /// Whether the share sheet is showing
    @State private var isShowingShareSheet = false
    
    /// The QR code image to share
    @State private var qrCodeImage: UIImage?
    
    /// The callback for when the sheet is dismissed
    var onDismiss: () -> Void
    
    // MARK: - Initialization
    
    /// Initialize with a name, QR code ID, and dismiss callback
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID
    ///   - onDismiss: The callback for when the sheet is dismissed
    init(
        name: String,
        qrCodeId: String,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = QRCodeSheetViewModel(
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
        viewModel: QRCodeSheetViewModel,
        onDismiss: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onDismiss = onDismiss
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            Text("Your QR Code")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // Subtitle
            Text("Share this QR code with others to add \(viewModel.name) as a contact")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            // QR code card
            QRCodeCardView(viewModel: viewModel.qrCodeCardViewModel)
                .padding(.vertical)
            
            // Share button
            Button(action: {
                qrCodeImage = viewModel.generateShareableQRCode()
                isShowingShareSheet = true
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
            
            // Close button
            Button(action: {
                viewModel.dismiss()
                onDismiss()
            }) {
                Text("Close")
                    .foregroundColor(.blue)
            }
            .padding(.bottom)
        }
        .padding()
        .sheet(isPresented: $isShowingShareSheet) {
            if let image = qrCodeImage {
                QRCodeShareSheet(items: [image])
            }
        }
    }
}

/// A UIViewControllerRepresentable for sharing content
struct QRCodeShareSheet: UIViewControllerRepresentable {
    /// The items to share
    let items: [Any]
    
    /// Create the UIActivityViewController
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    /// Update the UIActivityViewController (not needed)
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    QRCodeSheetView(
        name: "John Doe",
        qrCodeId: "https://example.com",
        onDismiss: {}
    )
}
