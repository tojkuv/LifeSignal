import Foundation
import SwiftUI
import PhotosUI
import UIKit
import AVFoundation

/// View model for QR code scanning functionality
class QRScannerViewModel: ObservableObject {
    // MARK: - Published Properties
    
    /// Whether to show the scanner sheet
    @Published var showScanner: Bool = false
    
    /// Whether the torch is on
    @Published var torchOn: Bool = false
    
    /// Whether the gallery picker is showing
    @Published var isShowingGallery: Bool = false
    
    /// Whether the user's QR code is showing
    @Published var isShowingMyCode: Bool = false
    
    /// Whether the camera is ready
    @Published var isCameraReady: Bool = false
    
    /// Whether the camera failed to load
    @Published var cameraLoadFailed: Bool = false
    
    /// Whether a QR code is being processed
    @Published var isProcessingQRCode: Bool = false
    
    /// Whether to show the no QR code alert
    @Published var showNoQRCodeAlert: Bool = false
    
    /// Gallery assets for the carousel
    @Published var galleryAssets: [UIImage] = []
    
    /// Gallery thumbnails for the carousel
    @Published var galleryThumbnails: [UIImage] = []
    
    /// Selected gallery index
    @Published var selectedGalleryIndex: Int? = nil
    
    /// The scanned QR code
    @Published var scannedQRCode: String = ""
    
    /// The last scan timestamp
    @Published var lastScanTimestamp: Date = Date.distantPast
    
    /// Callback for when a QR code is scanned
    var onQRCodeScanned: ((String) -> Void)?
    
    // MARK: - Computed Properties
    
    /// Whether a QR code has been scanned
    var qrCodeScanned: Bool {
        return !scannedQRCode.isEmpty && lastScanTimestamp != Date.distantPast
    }
    
    // MARK: - Initialization
    
    init() {
        // Load mock gallery assets
        loadMockGalleryAssets()
    }
    
    // MARK: - Methods
    
    /// Toggle the torch
    func toggleTorch() {
        torchOn.toggle()
        // In a real app, this would toggle the torch
    }
    
    /// Initialize the camera
    func initializeCamera() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Camera is authorized, simulate initialization
            simulateCameraInitialization()
        case .notDetermined:
            // Request camera permission
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.simulateCameraInitialization()
                    } else {
                        self?.cameraLoadFailed = true
                    }
                }
            }
        case .denied, .restricted:
            // Camera permission denied
            cameraLoadFailed = true
        @unknown default:
            // Unknown status
            cameraLoadFailed = true
        }
    }
    
    /// Simulate camera initialization
    private func simulateCameraInitialization() {
        // Simulate a delay for camera initialization
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            // 90% chance of success for demo purposes
            if Double.random(in: 0...1) < 0.9 {
                self?.isCameraReady = true
            } else {
                self?.cameraLoadFailed = true
            }
        }
    }
    
    /// Start scanning for QR codes
    func startScanning() {
        // In a real app, this would start the QR code scanner
    }
    
    /// Stop scanning for QR codes
    func stopScanning() {
        // In a real app, this would stop the QR code scanner
    }
    
    /// Set up the QR code handler
    func setupQRCodeHandler() {
        // In a real app, this would set up the QR code handler
    }
    
    /// Handle a scanned QR code
    /// - Parameter qrCode: The scanned QR code
    func handleScannedQRCode(_ qrCode: String) {
        scannedQRCode = qrCode
        lastScanTimestamp = Date()
        onQRCodeScanned?(qrCode)
    }
    
    /// Set whether to show the scanner
    /// - Parameter show: Whether to show the scanner
    func setShowScanner(_ show: Bool) {
        showScanner = show
        if show {
            initializeCamera()
        } else {
            stopScanning()
        }
    }
    
    /// Load mock gallery assets
    private func loadMockGalleryAssets() {
        // Create mock gallery assets
        galleryAssets = (0..<10).map { _ in createMockImage() }
        galleryThumbnails = galleryAssets
    }
    
    /// Create a mock image
    /// - Returns: A mock image
    private func createMockImage() -> UIImage {
        // Create a mock image with a random color
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100))
        return renderer.image { context in
            let randomColor = UIColor(
                red: .random(in: 0...1),
                green: .random(in: 0...1),
                blue: .random(in: 0...1),
                alpha: 1.0
            )
            randomColor.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }
    
    /// Load and process a full image
    /// - Parameter asset: The asset to load
    func loadAndProcessFullImage(_ asset: UIImage) {
        isProcessingQRCode = true
        
        // Simulate a delay for processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }
            
            // 50% chance of finding a QR code for demo purposes
            if Double.random(in: 0...1) < 0.5 {
                let mockQRCode = "mock-qr-code-\(Int.random(in: 1000...9999))"
                self.handleScannedQRCode(mockQRCode)
            } else {
                self.showNoQRCodeAlert = true
            }
            
            self.isProcessingQRCode = false
        }
    }
    
    /// Set the selected gallery index
    /// - Parameter index: The index to select
    func setSelectedGalleryIndex(_ index: Int) {
        selectedGalleryIndex = index
        if index >= 0 && index < galleryAssets.count {
            loadAndProcessFullImage(galleryAssets[index])
        }
    }
    
    /// Generate a mock QR code for testing
    /// - Returns: A random mock QR code string
    static func mockScanQRCode() -> String {
        return "mock-qr-code-\(Int.random(in: 1000...9999))"
    }
}
