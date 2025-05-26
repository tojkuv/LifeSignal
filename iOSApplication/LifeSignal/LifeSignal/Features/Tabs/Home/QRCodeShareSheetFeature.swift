import SwiftUI
import UIKit
import ComposableArchitecture

/// QR Code Share Sheet Feature for TCA
@Reducer
struct QRCodeShareSheetFeature {
    @ObservableState
    struct State: Equatable {
        var qrCodeImage: UIImage?
        var shareableItems: [Any] = []
        
        static func == (lhs: State, rhs: State) -> Bool {
            // Compare images by their data
            let lhsData = lhs.qrCodeImage?.pngData()
            let rhsData = rhs.qrCodeImage?.pngData()
            return lhsData == rhsData
        }
    }
    
    enum Action {
        case dismiss
        case shareItems([Any])
    }
    
    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .dismiss:
                return .none
            case .shareItems(let items):
                state.shareableItems = items
                return .none
            }
        }
    }
}

/// QR Code Share Sheet View
struct QRCodeShareSheetView: View {
    @Bindable var store: StoreOf<QRCodeShareSheetFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share QR Code")
                .font(.title2)
                .fontWeight(.bold)
            
            if let qrImage = store.qrCodeImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 250, height: 250)
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            
            Button("Share") {
                if let image = store.qrCodeImage {
                    store.send(.shareItems([image]))
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Close") {
                store.send(.dismiss)
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

/// A simple UIActivityViewController wrapper for sharing QR code images
struct QRCodeShareSheet: UIViewControllerRepresentable {
    let qrCodeImage: UIImage
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: [qrCodeImage],
            applicationActivities: nil
        )
        
        // Exclude some activities that don't make sense for QR codes
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList
        ]
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}

/// Generic activity share sheet for sharing any items
struct ActivityShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No updates needed
    }
}