import SwiftUI

/// A SwiftUI view for displaying a QR code card
struct QRCodeCardView: View {
    // MARK: - Properties
    
    /// The view model for the QR code card
    @ObservedObject var viewModel: QRCodeCardViewModel
    
    /// The subtitle to display
    var subtitle: String = ""
    
    // MARK: - Initialization
    
    /// Initialize with a name, subtitle, QR code ID, and footer
    /// - Parameters:
    ///   - name: The name to display
    ///   - subtitle: The subtitle to display
    ///   - qrCodeId: The QR code ID
    ///   - footer: The footer text to display
    init(
        name: String,
        subtitle: String = "",
        qrCodeId: String,
        footer: String = ""
    ) {
        self.viewModel = QRCodeCardViewModel(
            name: name,
            qrCodeId: qrCodeId,
            footer: footer
        )
        self.subtitle = subtitle
    }
    
    /// Initialize with a view model
    /// - Parameter viewModel: The view model
    init(viewModel: QRCodeCardViewModel, subtitle: String = "") {
        self.viewModel = viewModel
        self.subtitle = subtitle
    }
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 16) {
            // Avatar and name
            VStack(spacing: 8) {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(viewModel.name.prefix(1)))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                // Name
                Text(viewModel.name)
                    .font(.title3)
                    .fontWeight(.bold)
                
                // Subtitle
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // QR code
            QRCodeView(viewModel: viewModel.qrCodeViewModel)
                .frame(width: 200, height: 200)
                .padding(.vertical, 8)
            
            // Footer
            if !viewModel.footer.isEmpty {
                Text(viewModel.footer)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
        .padding(.horizontal)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .edgesIgnoringSafeArea(.all)
        
        QRCodeCardView(
            name: "John Doe",
            subtitle: "LifeSignal contact",
            qrCodeId: "https://example.com",
            footer: "Scan this QR code to add me as a contact"
        )
    }
}
