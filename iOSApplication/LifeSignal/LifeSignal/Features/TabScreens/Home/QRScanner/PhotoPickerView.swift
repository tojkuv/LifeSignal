import SwiftUI
import PhotosUI
import AVFoundation
import ComposableArchitecture

/// A SwiftUI view for picking photos
struct PhotoPickerView: UIViewControllerRepresentable {
    /// The TCA store for the QR scanner
    let store: StoreOf<QRScannerFeature>

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .images
        configuration.selectionLimit = 1

        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView

        init(_ parent: PhotoPickerView) {
            self.parent = parent
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker
            DispatchQueue.main.async {
                self.parent.store.send(.toggleGallery(false))
            }

            guard let provider = results.first?.itemProvider else {
                // No image selected
                return
            }

            if provider.canLoadObject(ofClass: UIImage.self) {
                provider.loadObject(ofClass: UIImage.self) { image, error in
                    if let uiImage = image as? UIImage {
                        DispatchQueue.main.async {
                            // Process the selected image for QR code scanning
                            // This would need to be implemented in the feature
                            // For now, just show an alert if no QR code is found
                            self.parent.store.send(.showNoQRCodeAlert(true))
                        }
                    }
                }
            }
        }
    }
}