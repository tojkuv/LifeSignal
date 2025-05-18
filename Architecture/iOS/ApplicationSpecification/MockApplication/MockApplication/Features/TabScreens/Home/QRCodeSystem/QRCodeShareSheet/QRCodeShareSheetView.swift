import SwiftUI

/// A SwiftUI view for displaying and sharing QR codes
struct QRCodeShareSheetView: View {
    // MARK: - Properties

    /// The view model for the QR code functionality
    @StateObject private var viewModel = QRCodeShareSheetViewModel()

    // MARK: - Body

    var body: some View {
        VStack(spacing: 20) {
            // Header with title and refresh button
            headerView

            // QR Code Display
            qrCodeView

            // QR Code ID
            Text("ID: \(viewModel.qrCodeId)")
                .font(.caption)
                .foregroundColor(.secondary)

            // Share button
            shareButton

            // Close button
            closeButton
        }
        .padding()
        .background(Color(UIColor.systemGroupedBackground))
        .sheet(isPresented: $viewModel.isShareSheetPresented) {
            if let image = viewModel.qrCodeImage {
                ActivityShareSheet(items: [image])
            }
        }
        .alert("Reset QR Code", isPresented: $viewModel.isRefreshAlertPresented) {
            Button("Cancel", role: .cancel) { }
            Button("Reset") {
                viewModel.regenerateQRCode()
            }
        } message: {
            Text("Are you sure you want to reset your QR code? This will invalidate any previously shared QR codes.")
        }
    }

    // MARK: - UI Components

    /// Header view with title and refresh button
    private var headerView: some View {
        HStack {
            Text("Your QR Code")
                .font(.title)
                .padding(.top)

            Spacer()

            // Refresh button
            Button(action: {
                viewModel.showRefreshAlert()
            }) {
                Image(systemName: "arrow.clockwise")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.top)
        }
        .padding(.horizontal)
    }

    /// QR code display view
    private var qrCodeView: some View {
        Group {
            if let qrCodeImage = viewModel.qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
        }
    }

    /// Share button view
    private var shareButton: some View {
        Button(action: {
            viewModel.showShareSheet()
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
    }

    /// Close button view
    private var closeButton: some View {
        Button(action: {
            viewModel.dismiss()
        }) {
            Text("Close")
                .foregroundColor(.blue)
        }
        .padding(.bottom)
    }
}