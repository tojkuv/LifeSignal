import SwiftUI
import ComposableArchitecture
import Perception

/// A SwiftUI view for displaying and sharing QR codes
struct QRCodeShareSheetView: View {
    @Bindable var store: StoreOf<QRCodeShareSheetFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 20) {
                // Header with title and refresh button
                headerView

                // QR Code Display
                qrCodeView

                // QR Code ID (if available)
                if let user = store.currentUser {
                    Text("ID: \(user.qrCodeId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Share button
                shareButton

                // Close button
                closeButton
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(item: $store.scope(state: \.shareSheet, action: \.shareSheet)) { shareStore in
                if let shareSheet = store.shareSheet {
                    ActivityShareSheet(items: [shareSheet.image, shareSheet.text])
                }
            }
            .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
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
                store.send(.regenerateQRCode)
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
            if let qrCodeImage = store.qrCodeImage {
                Image(uiImage: qrCodeImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            } else if store.isGenerating {
                VStack {
                    ProgressView()
                    Text("Generating QR Code...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(width: 250, height: 250)
            } else {
                Button("Generate QR Code") {
                    store.send(.generateQRCode)
                }
                .frame(width: 250, height: 250)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }

    /// Share button view
    private var shareButton: some View {
        Button(action: {
            store.send(.share)
        }) {
            Label("Share QR Code", systemImage: "square.and.arrow.up")
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(store.canShare ? Color.blue : Color.gray)
                .cornerRadius(10)
        }
        .disabled(!store.canShare)
        .padding(.horizontal)
    }

    /// Close button view
    private var closeButton: some View {
        Button(action: {
            // Send a presentation dismiss action instead
            // This should be handled by the parent feature
        }) {
            Text("Close")
                .foregroundColor(.blue)
        }
        .padding(.bottom)
    }
}