import SwiftUI
import PhotosUI
@preconcurrency import AVFoundation

/// A SwiftUI view that wraps a UIKit camera preview view
struct CameraPreviewView: UIViewRepresentable {
    /// Whether the torch is on
    var torchOn: Bool
    
    /// Coordinator class to manage the capture session
    class Coordinator: NSObject {
        let session = AVCaptureSession()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    /// Create the UIView
    func makeUIView(context: Context) -> UIView {
        // Create a UIView to hold the camera preview
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black

        // Create a preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: context.coordinator.session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Configure the session
        configureSession(context.coordinator.session)

        return view
    }

    /// Update the UIView
    func updateUIView(_ uiView: UIView, context: Context) {
        // Update torch state
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        
        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                device.torchMode = torchOn ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Failed to set torch mode: \(error)")
            }
        }
    }

    /// Configure the capture session
    private func configureSession(_ session: AVCaptureSession) {
        // Get the default video device
        guard let device = AVCaptureDevice.default(for: .video) else {
            print("No video device available")
            return
        }

        // Create an input from the device
        guard let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to create capture input")
            return
        }

        // Check if we can add the input to the session
        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            print("Cannot add input to session")
            return
        }

        // Create a metadata output
        let output = AVCaptureMetadataOutput()
        
        // Check if we can add the output to the session
        if session.canAddOutput(output) {
            session.addOutput(output)
            
            // Configure the output to detect QR codes
            output.metadataObjectTypes = [.qr]
        } else {
            print("Cannot add output to session")
            return
        }

        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }
}