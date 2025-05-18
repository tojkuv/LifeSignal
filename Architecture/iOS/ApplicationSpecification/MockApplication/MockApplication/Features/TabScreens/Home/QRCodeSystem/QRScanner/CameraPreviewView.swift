/// A SwiftUI view that wraps a UIKit camera preview view
struct CameraPreviewView: UIViewRepresentable {
    /// Whether the torch is on
    var torchOn: Bool
    /// The AVCaptureSession for the camera
    private let session = AVCaptureSession()

    /// Create the UIView
    func makeUIView(context: Context) -> UIView {
        // Create a UIView to hold the camera preview
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black

        // Create a preview layer
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Set up the camera session
        setupCameraSession()

        return view
    }

    /// Update the UIView
    func updateUIView(_ uiView: UIView, context: Context) {
        // Toggle torch if needed
        toggleTorch(on: torchOn)
    }

    /// Toggle the torch on or off
    private func toggleTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video) else { return }

        if device.hasTorch && device.isTorchAvailable {
            do {
                try device.lockForConfiguration()
                device.torchMode = on ? .on : .off
                device.unlockForConfiguration()
            } catch {
                print("Error toggling torch: \(error)")
            }
        }
    }

    /// Set up the camera session
    private func setupCameraSession() {
        // Check if the session is already running
        if session.isRunning {
            return
        }

        // Configure the session
        session.beginConfiguration()

        // Add video input
        guard let videoDevice = AVCaptureDevice.default(for: .video),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            return
        }

        session.addInput(videoInput)

        // Add metadata output for QR codes
        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.metadataObjectTypes = [.qr]
            // In a real app, you would set a delegate here to handle QR code detection
        }

        session.commitConfiguration()

        // Start the session on a background thread
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }
}