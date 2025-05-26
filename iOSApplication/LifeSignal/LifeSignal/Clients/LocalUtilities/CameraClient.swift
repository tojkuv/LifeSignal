import Foundation
import SwiftUI
import ComposableArchitecture
import DependenciesMacros
import AVFoundation

@DependencyClient
struct CameraClient {
    var requestPermission: @Sendable () async -> AVAuthorizationStatus = { .notDetermined }
    var checkPermission: @Sendable () async -> AVAuthorizationStatus = { .notDetermined }
}

extension CameraClient: DependencyKey {
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
        }
    )

    static let testValue = CameraClient(
        requestPermission: { .authorized },
        checkPermission: { .authorized }
    )
}

extension DependencyValues {
    var cameraClient: CameraClient {
        get { self[CameraClient.self] }
        set { self[CameraClient.self] = newValue }
    }
}
