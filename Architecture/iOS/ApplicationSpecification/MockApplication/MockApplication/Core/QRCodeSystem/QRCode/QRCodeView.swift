import SwiftUI

/// A SwiftUI view for displaying a QR code
struct QRCodeView: View {
    // MARK: - Properties

    /// The view model for the QR code
    @ObservedObject var viewModel: QRCodeViewModel

    // MARK: - Initialization

    /// Initialize with a QR code ID
    /// - Parameter qrCodeId: The QR code ID to display
    init(qrCodeId: String) {
        self.viewModel = QRCodeViewModel(qrCodeId: qrCodeId)
    }

    /// Initialize with a view model
    /// - Parameter viewModel: The view model
    init(viewModel: QRCodeViewModel) {
        self.viewModel = viewModel
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            if let qrCodeImage = viewModel.qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
            } else {
                // Placeholder when no QR code is available
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Text("Loading...")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .onAppear {
            // Generate the QR code image when the view appears
            viewModel.generateQRCodeImage()
        }
        .onChange(of: viewModel.qrCodeId) { _, _ in
            // Regenerate the QR code image when the ID changes
            viewModel.generateQRCodeImage()
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(spacing: 20) {
        QRCodeView(qrCodeId: "https://example.com")
            .frame(width: 200, height: 200)

        QRCodeView(viewModel: QRCodeViewModel(
            qrCodeId: "https://example.com",
            size: 150,
            branded: false
        ))
        .frame(width: 150, height: 150)
    }
    .padding()
}
