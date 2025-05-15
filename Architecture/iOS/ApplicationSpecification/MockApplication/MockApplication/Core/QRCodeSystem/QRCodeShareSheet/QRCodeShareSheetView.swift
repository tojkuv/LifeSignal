import SwiftUI

/// A SwiftUI view for sharing QR codes
struct QRCodeShareSheetView: View {
    // MARK: - Properties
    
    /// The view model for the QR code share sheet
    @ObservedObject var viewModel: QRCodeShareSheetViewModel
    
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
            
            Text("Share this QR code with others to add \(viewModel.name) as a contact")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            QRCodeView(viewModel: viewModel.qrCodeViewModel)
                .padding()
                .frame(width: 250, height: 250)
            
            Button(action: {
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
            if let image = viewModel.qrCodeViewModel.qrCodeImage {
                QRCodeShareSheet(items: [image])
            }
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
