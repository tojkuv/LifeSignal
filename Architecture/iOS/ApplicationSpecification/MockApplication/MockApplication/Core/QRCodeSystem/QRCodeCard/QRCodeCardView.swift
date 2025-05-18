import SwiftUI

/// A SwiftUI view for displaying a QR code card
struct QRCodeCardView: View {
    // MARK: - Properties

    /// The view model for the QR code card
    @ObservedObject var viewModel: QRCodeCardViewModel

    /// Whether to show a shadow
    var showShadow: Bool = true

    // MARK: - Initialization

    /// Initialize with a name, subtitle, QR code ID, and footer
    /// - Parameters:
    ///   - name: The name to display
    ///   - subtitle: The subtitle to display
    ///   - qrCodeId: The QR code ID
    ///   - footer: The footer text to display
    ///   - showShadow: Whether to show a shadow
    init(
        name: String,
        subtitle: String = "",
        qrCodeId: String,
        footer: String = "",
        showShadow: Bool = true
    ) {
        self.viewModel = QRCodeCardViewModel(
            name: name,
            subtitle: subtitle,
            qrCodeId: qrCodeId,
            footer: footer
        )
        self.showShadow = showShadow
    }

    /// Initialize with a view model
    /// - Parameters:
    ///   - viewModel: The view model
    ///   - showShadow: Whether to show a shadow
    init(viewModel: QRCodeCardViewModel, showShadow: Bool = true) {
        self.viewModel = viewModel
        self.showShadow = showShadow
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()
            VStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 6) {
                        Text(viewModel.name)
                            .font(.headline)
                            .bold()

                        Text(viewModel.subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 4)

                        QRCodeView(qrCodeId: viewModel.qrCodeViewModel.qrCodeId)
                            .frame(width: 180, height: 180)
                            .padding(18)
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                    }
                    .padding(.top, 40)
                    .padding(.bottom, 35)
                    .frame(maxWidth: 300)
                    .background(Color(UIColor.systemGray5))
                    .cornerRadius(20)

                    AvatarView(
                        name: viewModel.name,
                        size: 60,
                        strokeWidth: 4,
                        strokeColor: Color(UIColor.systemGray5)
                    )
                    .offset(y: -170)
                }
                .padding(.bottom, 40)
                .shadow(color: Color.black.opacity(0.18), radius: 24, x: 0, y: 18)


                Text(viewModel.footer)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
                    .frame(maxWidth: 300)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .frame(width: 390, height: 844)
    }
}

#Preview {
    ZStack {
        Color(.systemGroupedBackground)
            .edgesIgnoringSafeArea(.all)

        QRCodeCardView(
            name: "John Doe",
            subtitle: "LifeSignal contact",
            qrCodeId: "F3B6C150-9E23-4BFA-A13E-8A8B842BB4C5",
            footer: "Use LifeSignal's QR code scanner to add this contact",
            showShadow: true
        )
    }
}
