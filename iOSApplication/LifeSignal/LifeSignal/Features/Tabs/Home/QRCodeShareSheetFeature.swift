import SwiftUI
import Foundation
import UIKit
@preconcurrency import AVFoundation
import PhotosUI
import ComposableArchitecture
import Perception


// Define Alert enum outside to avoid circular dependencies
enum QRCodeShareSheetAlert: Equatable {
    case confirmRegenerate
}

@Reducer
struct QRCodeShareSheetFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.currentUser) var currentUser: User? = nil
        
        var qrCodeImage: UIImage?
        var shareableImage: UIImage?
        var isGenerating = false
        var errorMessage: String?
        @Presents var shareSheet: ShareSheetState?
        @Presents var confirmationAlert: AlertState<QRCodeShareSheetAlert>?
        
        var canShare: Bool {
            shareableImage != nil && currentUser != nil
        }
        
        var userDisplayName: String {
            currentUser?.name ?? "LifeSignal User"
        }
        
        struct ShareSheetState: Equatable, Identifiable {
            let id = UUID()
            let image: UIImage
            let text: String
        }
        
        init(qrCodeId: String? = nil, qrCodeImage: UIImage? = nil) {
            self.qrCodeImage = qrCodeImage
            self.shareableImage = nil
            self.isGenerating = false
            self.errorMessage = nil
            self.shareSheet = nil
            self.confirmationAlert = nil
            // qrCodeId is available but not currently stored in state
            // In a full implementation, it would be used for QR generation
        }
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case generateQRCode
        case share
        case regenerateQRCode
        case confirmationAlert(PresentationAction<QRCodeShareSheetAlert>)
        case qrGenerationResponse(Result<UIImage, Error>)
        case shareableGenerationResponse(Result<UIImage, Error>)
        case dismiss
    }

    @Dependency(\.qrCodeGenerator) var qrCodeGenerator
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none
                
            case .generateQRCode:
                guard let user = state.currentUser, let qrImage = state.qrCodeImage else { return .none }
                state.isGenerating = true
                state.errorMessage = nil
                
                return .run { [name = user.name] send in
                    await analytics.track(.featureUsed(feature: "qr_share_generate", context: [:]))
                    await send(.shareableGenerationResponse(Result {
                        return try await qrCodeGenerator.generateShareableQRCode(qrImage, name)
                    }))
                }
                
            case .share:
                guard let image = state.shareableImage, let user = state.currentUser else { return .none }
                
                state.shareSheet = State.ShareSheetState(
                    image: image,
                    text: "Connect with me on LifeSignal! My QR code: \(user.qrCodeId.uuidString)"
                )
                
                return .run { _ in
                    await haptics.impact(.medium)
                    await analytics.track(.featureUsed(feature: "qr_share_initiated", context: [:]))
                }
                
            case .regenerateQRCode:
                state.confirmationAlert = AlertState {
                    TextState("Regenerate QR Code")
                } actions: {
                    ButtonState(role: .destructive, action: .confirmRegenerate) {
                        TextState("Regenerate")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("Are you sure you want to regenerate your QR code? Your existing contacts will need to scan your new code to stay connected.")
                }
                return .none
                
                
            case .confirmationAlert(.presented(.confirmRegenerate)):
                state.isGenerating = true
                return .run { send in
                    await haptics.notification(.warning)
                    await analytics.track(.featureUsed(feature: "qr_regenerate_confirmed", context: [:]))
                    // In production, this would regenerate the QR code
                    await send(.qrGenerationResponse(Result {
                        throw NSError(domain: "QRCodeShareSheet", code: 2, userInfo: [NSLocalizedDescriptionKey: "QR code regeneration not implemented"])
                    }))
                }
                
            case .confirmationAlert:
                return .none
                
            case let .qrGenerationResponse(.success(image)):
                state.isGenerating = false
                state.qrCodeImage = image
                state.shareableImage = nil
                return .send(.generateQRCode)
                
            case let .qrGenerationResponse(.failure(error)):
                state.isGenerating = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case let .shareableGenerationResponse(.success(image)):
                state.isGenerating = false
                state.shareableImage = image
                return .run { _ in
                    await haptics.notification(.success)
                }
                
            case let .shareableGenerationResponse(.failure(error)):
                state.isGenerating = false
                state.errorMessage = error.localizedDescription
                return .none
                
            case .dismiss:
                return .none
            }
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}

/// A UIViewControllerRepresentable for sharing content
struct ActivityShareSheet: UIViewControllerRepresentable {
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


/// A SwiftUI view for displaying and sharing QR codes
struct QRCodeShareSheetView: View {
    @Bindable var store: StoreOf<QRCodeShareSheetFeature>

    var body: some View {
        WithPerceptionTracking {
            VStack(spacing: 20) {
                // Header with title and refresh button
                headerView()

                // QR Code Display
                qrCodeView()

                // QR Code ID (if available)
                if let user = store.currentUser {
                    Text("ID: \(user.qrCodeId.uuidString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Share button
                shareButton()

                // Close button
                closeButton()
            }
            .padding()
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(item: $store.shareSheet) { shareSheet in
                ActivityShareSheet(items: [shareSheet.image, shareSheet.text])
            }
            .alert($store.scope(state: \.confirmationAlert, action: \.confirmationAlert))
        }
    }

    // MARK: - UI Components

    /// Header view with title and refresh button
    @ViewBuilder
    private func headerView() -> some View {
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
    @ViewBuilder
    private func qrCodeView() -> some View {
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
    @ViewBuilder
    private func shareButton() -> some View {
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
    @ViewBuilder
    private func closeButton() -> some View {
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