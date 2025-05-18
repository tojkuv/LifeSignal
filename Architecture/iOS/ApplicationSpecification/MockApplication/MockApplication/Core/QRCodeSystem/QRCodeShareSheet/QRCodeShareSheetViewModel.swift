import Foundation
import SwiftUI
import UIKit

/// View model for QR code share sheet functionality
@MainActor
class QRCodeShareSheetViewModel: ObservableObject {
    // MARK: - Published Properties

    /// The name to display
    @Published var name: String = ""

    /// The subtitle to display
    @Published var subtitle: String = "LifeSignal contact"

    /// Whether the share sheet is showing
    @Published var isShowingShareSheet: Bool = false

    /// The QR code generator view model
    @Published var qrCodeViewModel: QRCodeViewModel

    /// The footer text to display
    @Published var footer: String = "Use LifeSignal's QR code scanner to add this contact"

    // MARK: - Initialization

    /// Initialize with default values
    /// - Parameters:
    ///   - name: The name to display
    ///   - qrCodeId: The QR code ID
    ///   - subtitle: The subtitle to display
    ///   - footer: The footer text to display
    ///   - isShowingShareSheet: Whether the share sheet is showing
    init(
        name: String = "",
        qrCodeId: String = "",
        subtitle: String = "LifeSignal contact",
        footer: String = "Use LifeSignal's QR code scanner to add this contact",
        isShowingShareSheet: Bool = false
    ) {
        self.name = name
        self.subtitle = subtitle
        self.footer = footer
        self.isShowingShareSheet = isShowingShareSheet
        self.qrCodeViewModel = QRCodeViewModel(
            qrCodeId: qrCodeId,
            size: 200,  // Size for display in the view
            branded: true
        )

        // Force generate QR code image immediately
        // Use a sync call to ensure the image is generated before the view appears
        self.qrCodeViewModel.generateQRCodeImage()

        // Also schedule an async call as a backup
        DispatchQueue.main.async {
            self.qrCodeViewModel.generateQRCodeImage()
        }
    }

    // MARK: - Methods

    /// Set whether the share sheet is showing
    /// - Parameter isShowing: Whether the share sheet is showing
    func setShowingShareSheet(_ isShowing: Bool) {
        isShowingShareSheet = isShowing
    }

    /// Share the QR code
    func shareQRCode() {
        // In a real app, this would share the QR code
        print("Sharing QR code for \(name)")
    }

    /// Dismiss the sheet
    func dismiss() {
        // In a real app, this would dismiss the sheet
    }

    /// Generate a shareable QR code with high resolution
    /// - Returns: The QR code image
    func generateShareableQRCode() -> UIImage? {
        // Create a high-resolution QR code for sharing
        return QRCodeViewModel.generateBrandedQRCode(
            from: qrCodeViewModel.qrCodeId,
            size: 1024  // High resolution for sharing
        )
    }

    /// Generate a shareable image from the QR code card view
    /// - Parameter completion: Completion handler with the generated image
    func generateShareableImage(completion: @escaping (UIImage?) -> Void) {
        // Create a view with the correct aspect ratio for sharing
        let shareableView = createQRCodeCardView(useHighResQRCode: true, forSharing: true)

        // Since this class is already marked as @MainActor, we can directly use ImageRenderer
        // Create a renderer to capture the view
        let renderer = ImageRenderer(content: shareableView)

        // Set the scale to ensure high quality
        renderer.scale = 3.0

        // Generate the image
        let uiImage = renderer.uiImage

        // Call the completion handler
        completion(uiImage)
    }

    /// Create a QR code card view with the specified parameters
    /// This is a helper function to create the shareable image
    func createQRCodeCardView(
        useHighResQRCode: Bool = false,
        forSharing: Bool = false
    ) -> some View {
        ZStack {
            Color.blue
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // Card container
                VStack(spacing: 0) {
                    // Avatar at top
                    AvatarView(
                        name: name,
                        size: 60,
                        strokeWidth: 4,
                        strokeColor: .white
                    )
                    .padding(.top, 40)
                    .padding(.bottom, 16)

                    // Name and subtitle
                    Text(name)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.black)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 24)

                    // QR Code - use a high-resolution QR code for sharing if requested
                    if useHighResQRCode, let qrImage = generateShareableQRCode() {
                        Image(uiImage: qrImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.bottom, 24)
                    } else {
                        // Use the standard QR code view
                        QRCodeView(viewModel: qrCodeViewModel)
                            .frame(width: 200, height: 200)
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .padding(.bottom, 24)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color(UIColor.systemGray5))
                .cornerRadius(20)
                .frame(width: 300)
                .padding(.bottom, 24)

                // Footer text (QR Code ID or instructions)
                Text(footer)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 300)
            }
            .padding(.vertical, 40)
        }
        .frame(width: forSharing ? 390 : nil, height: forSharing ? 844 : nil) // iPhone-like aspect ratio for sharing
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}
