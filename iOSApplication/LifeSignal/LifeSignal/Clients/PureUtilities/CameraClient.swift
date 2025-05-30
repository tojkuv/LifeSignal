import Foundation
import SwiftUI
import ComposableArchitecture
import DependenciesMacros
import AVFoundation
import Photos
import Vision

@DependencyClient
struct CameraClient: PureUtilityClient, Sendable {
    var requestPermission: @Sendable () async -> AVAuthorizationStatus = { .notDetermined }
    var checkPermission: @Sendable () async -> AVAuthorizationStatus = { .notDetermined }
    var requestPhotoLibraryPermission: @Sendable () async -> PHAuthorizationStatus = { .notDetermined }
    var checkPhotoLibraryPermission: @Sendable () async -> PHAuthorizationStatus = { .notDetermined }
    var getRecentPhotos: @Sendable () async -> [UIImage] = { [] }
    var getFullResolutionRecentPhoto: @Sendable (Int) async -> UIImage? = { _ in nil }
    var detectQRCode: @Sendable (UIImage) async -> String? = { _ in nil }
}

extension CameraClient: DependencyKey {
    static let defaultValue = liveValue
    // MARK: - Helper Methods
    
    static func generateMockThumbnails() -> [UIImage] {
        return (0..<7).map { i in
            let size = CGSize(width: 90, height: 90)
            let renderer = UIGraphicsImageRenderer(size: size)
            
            return renderer.image { context in
                // Create gradient background
                let colors = [
                    UIColor.systemBlue,
                    UIColor.systemPurple, 
                    UIColor.systemPink,
                    UIColor.systemOrange,
                    UIColor.systemYellow,
                    UIColor.systemGreen,
                    UIColor.systemTeal
                ]
                
                let color = colors[i % colors.count]
                color.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // Add mock content shapes
                UIColor.white.withAlphaComponent(0.3).setFill()
                let rect1 = CGRect(x: 10, y: 15, width: 25, height: 25)
                let rect2 = CGRect(x: 55, y: 50, width: 25, height: 25)
                context.fill(rect1)
                context.fill(rect2)
                
                // Add photo icon
                UIColor.white.withAlphaComponent(0.7).setStroke()
                context.cgContext.setLineWidth(2)
                let photoRect = CGRect(x: 30, y: 30, width: 30, height: 30)
                context.cgContext.stroke(photoRect)
                
                // Add index number for identification
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
                let text = "\(i+1)"
                text.draw(at: CGPoint(x: 5, y: 5), withAttributes: attrs)
            }
        }
    }
    static let liveValue = CameraClient(
        requestPermission: {
            await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    continuation.resume(returning: status)
                }
            }
        },
        checkPermission: {
            AVCaptureDevice.authorizationStatus(for: .video)
        },
        requestPhotoLibraryPermission: {
            await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                    continuation.resume(returning: status)
                }
            }
        },
        checkPhotoLibraryPermission: {
            PHPhotoLibrary.authorizationStatus(for: .readWrite)
        },
        getRecentPhotos: {
            // Check if running in simulator or if photo library access might fail
            #if targetEnvironment(simulator)
            // For simulator, provide mock thumbnails since photo library is often empty
            return Self.generateMockThumbnails()
            #else
            // Check photo library permission first
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else {
                return Self.generateMockThumbnails() // Fallback to mock thumbnails
            }
            
            do {
                // Fetch recent photos
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.fetchLimit = 10 // Limit to 10 most recent photos
                
                let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                
                // If no photos available, return mock thumbnails for better UX
                guard assets.count > 0 else {
                    return Self.generateMockThumbnails()
                }
                
                let imageManager = PHImageManager.default()
                let requestOptions = PHImageRequestOptions()
                requestOptions.deliveryMode = .fastFormat
                requestOptions.resizeMode = .fast
                requestOptions.isNetworkAccessAllowed = false // Avoid network requests
                requestOptions.isSynchronous = true // Use synchronous for simplicity
                
                let targetSize = CGSize(width: 90, height: 90)
                var thumbnails: [UIImage] = []
                
                // Process up to 10 assets sequentially to avoid threading issues
                let maxCount = min(assets.count, 10)
                for i in 0..<maxCount {
                    let asset = assets.object(at: i)
                    
                    var thumbnail: UIImage?
                    imageManager.requestImage(
                        for: asset,
                        targetSize: targetSize,
                        contentMode: .aspectFill,
                        options: requestOptions
                    ) { image, _ in
                        thumbnail = image
                    }
                    
                    if let thumbnail = thumbnail {
                        thumbnails.append(thumbnail)
                    }
                    
                    // Limit processing time to avoid blocking
                    if thumbnails.count >= 8 {
                        break
                    }
                }
                
                // If we couldn't load any real photos, fallback to mock thumbnails
                return thumbnails.isEmpty ? Self.generateMockThumbnails() : thumbnails
            } catch {
                // If Photos access fails, return mock thumbnails for better UX
                print("Failed to load recent photos: \(error)")
                return Self.generateMockThumbnails()
            }
            #endif
        },
        getFullResolutionRecentPhoto: { index in
            #if targetEnvironment(simulator)
            // For simulator, return a larger mock image with embedded QR code for testing
            let size = CGSize(width: 400, height: 400)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                // Draw a mock QR code pattern
                UIColor.black.setFill()
                let qrSize: CGFloat = 200
                let qrRect = CGRect(x: 100, y: 100, width: qrSize, height: qrSize)
                context.fill(qrRect)
                
                // Add some white squares to simulate QR pattern
                UIColor.white.setFill()
                for row in 0..<10 {
                    for col in 0..<10 {
                        if (row + col) % 2 == 0 {
                            let squareSize: CGFloat = qrSize / 10
                            let x = 100 + CGFloat(col) * squareSize
                            let y = 100 + CGFloat(row) * squareSize
                            context.fill(CGRect(x: x, y: y, width: squareSize, height: squareSize))
                        }
                    }
                }
                
                // Add label
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 16),
                    .foregroundColor: UIColor.black
                ]
                "Test QR #\(index)".draw(at: CGPoint(x: 150, y: 320), withAttributes: attrs)
            }
            #else
            // For real device, load full resolution image from photo library
            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            guard status == .authorized || status == .limited else {
                print("❌ Photo library access not authorized")
                return nil
            }
            
            do {
                let fetchOptions = PHFetchOptions()
                fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                fetchOptions.fetchLimit = 10
                
                let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)
                
                guard index < assets.count else {
                    print("❌ Index \(index) out of bounds for \(assets.count) assets")
                    return nil
                }
                
                let asset = assets.object(at: index)
                let imageManager = PHImageManager.default()
                let requestOptions = PHImageRequestOptions()
                requestOptions.deliveryMode = .highQualityFormat
                requestOptions.resizeMode = .none
                requestOptions.isNetworkAccessAllowed = true
                requestOptions.isSynchronous = true
                
                var fullImage: UIImage?
                imageManager.requestImage(
                    for: asset,
                    targetSize: PHImageManagerMaximumSize,
                    contentMode: .default,
                    options: requestOptions
                ) { image, _ in
                    fullImage = image
                }
                
                print("📸 Loaded full resolution image: \(fullImage?.size ?? .zero)")
                return fullImage
            } catch {
                print("❌ Failed to load full resolution photo: \(error)")
                return nil
            }
            #endif
        },
        detectQRCode: { image in
            await withCheckedContinuation { continuation in
                print("🔍 LIVE: Starting QR code detection on image with size: \(image.size)")
                
                guard let cgImage = image.cgImage else {
                    print("❌ LIVE: Failed to get CGImage from UIImage")
                    continuation.resume(returning: nil)
                    return
                }
                
                print("🔍 LIVE: Creating VNDetectBarcodesRequest...")
                let request = VNDetectBarcodesRequest { request, error in
                    if let error = error {
                        print("❌ LIVE: QR code detection error: \(error)")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    guard let results = request.results as? [VNBarcodeObservation] else {
                        print("❌ LIVE: No barcode results found")
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    print("📊 LIVE: Found \(results.count) barcode(s)")
                    
                    // Find the first QR code
                    for (index, result) in results.enumerated() {
                        print("📝 LIVE: Barcode \(index): symbology = \(result.symbology.rawValue)")
                        if result.symbology == .qr,
                           let payloadString = result.payloadStringValue {
                            print("✅ LIVE: Found QR code with content: \(payloadString)")
                            continuation.resume(returning: payloadString)
                            return
                        }
                    }
                    
                    // No QR code found
                    print("❌ LIVE: No QR codes found in \(results.count) barcode(s)")
                    continuation.resume(returning: nil)
                }
                
                // Configure the request to specifically look for QR codes
                request.symbologies = [.qr]
                print("🔍 LIVE: Configured request to look specifically for QR codes")
                
                print("🔍 LIVE: Performing Vision request...")
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    print("🔍 LIVE: Vision request completed")
                } catch {
                    print("❌ LIVE: Failed to perform QR code detection: \(error)")
                    continuation.resume(returning: nil)
                }
            }
        }
    )

    static let testValue = CameraClient(
        requestPermission: { .authorized },
        checkPermission: { .authorized },
        requestPhotoLibraryPermission: { .authorized },
        checkPhotoLibraryPermission: { .authorized },
        getRecentPhotos: {
            // Generate mock thumbnails for testing
            return (0..<5).map { i in
                let size = CGSize(width: 90, height: 90)
                let renderer = UIGraphicsImageRenderer(size: size)
                return renderer.image { context in
                    UIColor.systemGray.setFill()
                    context.fill(CGRect(origin: .zero, size: size))
                    
                    // Add test label
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 12),
                        .foregroundColor: UIColor.white
                    ]
                    let text = "IMG\n\(i+1)"
                    text.draw(in: CGRect(x: 25, y: 35, width: 40, height: 20), withAttributes: attrs)
                }
            }
        },
        getFullResolutionRecentPhoto: { index in
            print("🧪 TEST: Using testValue getFullResolutionRecentPhoto for index \(index)")
            // Generate a larger mock image for testing
            let size = CGSize(width: 500, height: 500)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                
                UIColor.systemBlue.setFill()
                context.fill(CGRect(x: 100, y: 100, width: 300, height: 300))
                
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 24),
                    .foregroundColor: UIColor.white
                ]
                "Full Res\nIMG \(index + 1)".draw(in: CGRect(x: 200, y: 230, width: 100, height: 60), withAttributes: attrs)
            }
        },
        detectQRCode: { image in
            print("🧪 TEST: Using testValue detectQRCode for image size: \(image.size)")
            print("🧪 TEST: Returning mock UUID instead of real QR detection")
            // For testing, return a mock QR code
            return UUID().uuidString
        }
    )
}

extension DependencyValues {
    var cameraClient: CameraClient {
        get { self[CameraClient.self] }
        set { self[CameraClient.self] = newValue }
    }
}
