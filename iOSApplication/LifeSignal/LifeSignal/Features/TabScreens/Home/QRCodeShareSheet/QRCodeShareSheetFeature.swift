import Foundation
import SwiftUI
import ComposableArchitecture
import UIKit

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
        
        struct ShareSheetState: Equatable {
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
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case generateQRCode
        case share
        case regenerateQRCode
        case shareSheet(PresentationAction<ShareSheetAction>)
        case confirmationAlert(PresentationAction<QRCodeShareSheetAlert>)
        case qrGenerationResponse(Result<UIImage, Error>)
        case shareableGenerationResponse(Result<UIImage, Error>)
        case dismiss
        
        enum ShareSheetAction {
            case completed
            case cancelled
        }
    }

    @Dependency(\.qrCodeGenerator) var qrCodeGenerator
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics

    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .generateQRCode:
                guard let user = state.currentUser, state.qrCodeImage != nil else { return .none }
                state.isGenerating = true
                state.errorMessage = nil
                
                return .run { [qrImage = state.qrCodeImage, name = user.name] send in
                    await analytics.track(.featureUsed(feature: "qr_share_generate", context: [:]))
                    await send(.shareableGenerationResponse(Result {
                        guard let qrImage = qrImage else {
                            throw NSError(domain: "QRCodeShareSheet", code: 1, userInfo: [NSLocalizedDescriptionKey: "No QR code image available"])
                        }
                        return try await qrCodeGenerator.generateShareableQRCode(qrImage, name)
                    }))
                }
                
            case .share:
                guard let image = state.shareableImage, let user = state.currentUser else { return .none }
                
                state.shareSheet = State.ShareSheetState(
                    image: image,
                    text: "Connect with me on LifeSignal! My QR code: \(user.qrCodeId)"
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
                
            case .shareSheet(.presented(.completed)):
                state.shareSheet = nil
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "qr_share_completed", context: [:]))
                }
                
            case .shareSheet(.presented(.cancelled)):
                state.shareSheet = nil
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "qr_share_cancelled", context: [:]))
                }
                
            case .shareSheet:
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