import SwiftUI

/// A SwiftUI view for displaying a QR code with additional information
struct QRCodeShareView: View {
    // MARK: - Properties

    /// The name to display
    let name: String

    /// The subtitle to display
    let subtitle: String

    /// The QR code ID to display
    let qrCodeId: String

    /// The footer text to display
    let footer: String

    // MARK: - Body

    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text(name)
                .font(.title2)
                .fontWeight(.bold)

            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)

            // QR code
            QRCodeView(qrCodeId: qrCodeId)
                .frame(width: 200, height: 200)

            // Footer
            Text(footer)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    QRCodeShareView(
        name: "John Doe",
        subtitle: "LifeSignal contact",
        qrCodeId: "example-qr-code",
        footer: "Use LifeSignal's QR code scanner to add this contact"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
