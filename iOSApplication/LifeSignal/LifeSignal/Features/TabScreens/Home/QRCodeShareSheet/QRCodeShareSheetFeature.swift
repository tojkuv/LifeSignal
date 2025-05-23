import Foundation
import SwiftUI
import ComposableArchitecture
import UIKit

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
        @Presents var confirmationAlert: AlertState<Action.Alert>?
        
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
    }

    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case generateQRCode
        case share
        case regenerateQRCode
        case shareSheet(PresentationAction<ShareSheetAction>)
        case confirmationAlert(PresentationAction<Alert>)
        case qrGenerationResponse(Result<UIImage, Error>)
        case shareableGenerationResponse(Result<UIImage, Error>)
        
        enum ShareSheetAction {
            case completed
            case cancelled
        }
        
        enum Alert: Equatable {
            case confirmRegenerate
        }
    }

    @Dependency(\.qrCodeGenerator) var qrCodeGenerator
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics

    var body: some Reducer<State, Action> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .generateQRCode:
                guard let currentUser = state.currentUser else { return .none }
                
                state.isGenerating = true
                state.errorMessage = nil
                
                return .run { send in
                    await analytics.track(.featureUsed(feature: "qr_code_generate", context: [:]))
                    await send(.qrGenerationResponse(Result {
                        try await qrCodeGenerator.generateQRCode(currentUser.id.uuidString)
                    }))
                }
                
            case .share:
                guard state.canShare, let shareableImage = state.shareableImage else {
                    return .send(.generateQRCode)
                }
                
                state.shareSheet = State.ShareSheetState(
                    image: shareableImage,
                    text: "Connect with me on LifeSignal! Scan this QR code to add me to your emergency contacts."
                )
                
                return .run { _ in
                    await haptics.selection()
                    await analytics.track(.featureUsed(feature: "qr_code_share", context: [:]))
                }
                
            case .regenerateQRCode:
                state.confirmationAlert = AlertState {
                    TextState("Regenerate QR Code")
                } actions: {
                    ButtonState(action: .confirmRegenerate) {
                        TextState("Regenerate")
                    }
                    ButtonState(role: .cancel) {
                        TextState("Cancel")
                    }
                } message: {
                    TextState("This will create a new QR code. Your old QR code will no longer work. Are you sure?")
                }
                return .none
                
            case .confirmationAlert(.presented(.confirmRegenerate)):
                state.qrCodeImage = nil
                state.shareableImage = nil
                
                return .run { send in
                    await haptics.notification(.warning)
                    await send(.generateQRCode)
                }
                
            case .confirmationAlert:
                return .none
                
            case .shareSheet(.presented(.completed)):
                return .run { _ in
                    await haptics.notification(.success)
                    await analytics.track(.featureUsed(feature: "qr_code_shared_success", context: [:]))
                }
                
            case .shareSheet(.presented(.cancelled)):
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "qr_code_share_cancelled", context: [:]))
                }
                
            case .shareSheet:
                return .none
                
            case let .qrGenerationResponse(.success(qrImage)):
                state.qrCodeImage = qrImage
                
                // Now generate the shareable version
                return .run { [userDisplayName = state.userDisplayName] send in
                    await send(.shareableGenerationResponse(Result {
                        try await qrCodeGenerator.generateShareableQRCode(qrImage, userDisplayName)
                    }))
                }
                
            case let .qrGenerationResponse(.failure(error)):
                state.isGenerating = false
                state.errorMessage = error.localizedDescription
                
                return .run { _ in
                    await haptics.notification(.error)
                }
                
            case let .shareableGenerationResponse(.success(shareableImage)):
                state.isGenerating = false
                state.shareableImage = shareableImage
                
                return .run { _ in
                    await haptics.notification(.success)
                }
                
            case let .shareableGenerationResponse(.failure(error)):
                state.isGenerating = false
                state.errorMessage = error.localizedDescription
                
                return .run { _ in
                    await haptics.notification(.error)
                }
            }
        }
        .ifLet(\.$shareSheet, action: \.shareSheet) {
            EmptyReducer() // ShareSheet actions are handled above
        }
        .ifLet(\.$confirmationAlert, action: \.confirmationAlert)
    }
}
