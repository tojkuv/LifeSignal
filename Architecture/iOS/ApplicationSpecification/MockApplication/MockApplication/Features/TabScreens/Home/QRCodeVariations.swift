import SwiftUI
import Foundation

/// Enum for different QR code design variations
enum QRCodeDesign: Int, CaseIterable, Identifiable {
    case standard

    var id: Int { rawValue }

    var name: String {
        return "Standard"
    }

    var icon: String {
        return "qrcode"
    }
}

/// A SwiftUI view for displaying different QR code design variations
struct QRCodeVariationView: View {
    /// The QR code ID to display
    let qrCodeId: String

    /// The design to display
    let design: QRCodeDesign

    /// The user's name
    let userName: String

    /// Callback for when the refresh button is tapped
    let onRefresh: () -> Void

    /// The QR code image
    @State private var qrCodeImage: UIImage? = nil

    /// Whether the image is ready
    @State private var isImageReady: Bool = false

    /// Whether the image is being generated
    @State private var isGeneratingImage: Bool = false

    var body: some View {
        // Use environment to detect light/dark mode
        @Environment(\.colorScheme) var colorScheme

        return standardDesign
            .onAppear {
                generateQRCodeImage()
            }
            .onChange(of: qrCodeId) { _, _ in
                // Regenerate QR code when the ID changes
                generateQRCodeImage()
            }
    }




    // MARK: - Standard Design

    private var standardDesign: some View {
        HStack(alignment: .top, spacing: 16) {
            // QR Code
            qrCodeView

            // Info and button
            infoView
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(16)
        // Remove shadow as requested
        .padding(.horizontal)

    }

    /// QR Code view with white background
    private var qrCodeView: some View {
        ZStack {
            if isImageReady, let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 130, height: 130)
            } else {
                ProgressView()
                    .frame(width: 130, height: 130)
            }
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(Environment(\.colorScheme).wrappedValue == .light ? 0.15 : 0.05),
                radius: Environment(\.colorScheme).wrappedValue == .light ? 4 : 2,
                x: 0,
                y: Environment(\.colorScheme).wrappedValue == .light ? 2 : 1)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    /// Information view
    private var infoView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your QR Code")
                .font(.headline)
                .foregroundColor(.primary)

            Text("Share this QR code with others to add contacts.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            // add a copy qr code button that copies the qr code id to the clipboard. "Copy ID".
            Button(action: {
                UIPasteboard.general.string = qrCodeId
                HapticFeedback.notificationFeedback(type: .success)
                // Show a silent local notification
                NotificationManager.shared.showQRCodeCopiedNotification()
            }) {
                Label("Copy ID", systemImage: "doc.on.doc")
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    .background(
                        // Use tertiarySystemGroupedBackground only in light mode
                        Environment(\.colorScheme).wrappedValue == .light ?
                            Color(UIColor.tertiarySystemGroupedBackground) :
                            Color(UIColor.secondarySystemGroupedBackground)
                    )
                    .cornerRadius(10)
            }
            .hapticFeedback(style: .light)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }



    // MARK: - Helper Methods

    /// Generate a QR code image
    private func generateQRCodeImage() {
        if isGeneratingImage { return }

        isImageReady = false
        isGeneratingImage = true

        DispatchQueue.global(qos: .userInitiated).async {
            // Generate QR code image
            if let qrImage = generateQRCode(from: self.qrCodeId) {
                DispatchQueue.main.async {
                    self.qrCodeImage = qrImage
                    self.isImageReady = true
                    self.isGeneratingImage = false
                }
            } else {
                DispatchQueue.main.async {
                    self.isGeneratingImage = false
                    // Handle error
                }
            }
        }
    }
}

/// Generate a QR code from a string
/// - Parameter string: The string to encode
/// - Returns: A UIImage containing the QR code
func generateQRCode(from string: String) -> UIImage? {
    guard let data = string.data(using: .utf8),
          let qrFilter = CIFilter(name: "CIQRCodeGenerator") else {
        return nil
    }

    qrFilter.setValue(data, forKey: "inputMessage")
    qrFilter.setValue("H", forKey: "inputCorrectionLevel") // High error correction

    guard let outputImage = qrFilter.outputImage else {
        return nil
    }

    // Scale the image
    let scale = CGFloat(300) / outputImage.extent.width
    let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

    // Convert to UIImage
    let context = CIContext()
    guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
        return nil
    }

    return UIImage(cgImage: cgImage)
}

#Preview {
    QRCodeVariationView(
        qrCodeId: "example-qr-code-12345",
        design: .standard,
        userName: "John Doe",
        onRefresh: {}
    )
    .previewDisplayName("Standard QR Code")
    .padding()
    .background(Color(UIColor.systemGroupedBackground))
}
