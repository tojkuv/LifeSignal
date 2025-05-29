import Foundation
import UIKit
import LocalAuthentication
import ComposableArchitecture
import Dependencies
import DependenciesMacros

// MARK: - BiometricType

enum BiometricType: String, CaseIterable, Sendable {
    case faceID = "Face ID"
    case touchID = "Touch ID"
    case none = "Not Available"
    
    var displayName: String {
        return self.rawValue
    }
}

// MARK: - BiometricClient Errors

enum BiometricClientError: Error, LocalizedError {
    case notAvailable
    case notEnrolled
    case userCancel
    case userFallback
    case systemCancel
    case passcodeNotSet
    case authenticationFailed
    case permissionDenied
    case biometryLocked
    case unknown(Error)
    
    static func == (lhs: BiometricClientError, rhs: BiometricClientError) -> Bool {
        switch (lhs, rhs) {
        case (.notAvailable, .notAvailable),
             (.notEnrolled, .notEnrolled),
             (.userCancel, .userCancel),
             (.userFallback, .userFallback),
             (.systemCancel, .systemCancel),
             (.passcodeNotSet, .passcodeNotSet),
             (.authenticationFailed, .authenticationFailed),
             (.permissionDenied, .permissionDenied),
             (.biometryLocked, .biometryLocked):
            return true
        case (.unknown(let lhsError), .unknown(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric data is enrolled on this device"
        case .userCancel:
            return "Authentication was cancelled by the user"
        case .userFallback:
            return "User chose to use fallback authentication"
        case .systemCancel:
            return "Authentication was cancelled by the system"
        case .passcodeNotSet:
            return "Device passcode is not set"
        case .authenticationFailed:
            return "Biometric authentication failed"
        case .permissionDenied:
            return "Biometric authentication permission denied. Please enable in Settings."
        case .biometryLocked:
            return "Biometric authentication is temporarily locked. Try again later or use your passcode."
        case .unknown(let error):
            return "Authentication error: \(error.localizedDescription)"
        }
    }
}

// MARK: - BiometricClient

@LifeSignalClient
@DependencyClient
struct BiometricClient {
    var isAvailable: @Sendable () -> BiometricType = { .none }
    var authenticate: @Sendable (String) async throws -> Bool = { _ in false }
    var authenticateWithPermissionRequest: @Sendable (String) async throws -> Bool = { _ in false }
    var getBiometricType: @Sendable () -> BiometricType = { .none }
    var isBiometricCapable: @Sendable () -> Bool = { false }
    var openSettings: @Sendable () -> Void = { }
}

extension BiometricClient: DependencyKey {
    static let liveValue: BiometricClient = {
        let context = LAContext()
        
        return BiometricClient(
            isAvailable: {
                let context = LAContext()
                var error: NSError?
                
                guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                    return .none
                }
                
                switch context.biometryType {
                case .faceID:
                    return .faceID
                case .touchID:
                    return .touchID
                case .opticID:
                    return .faceID // Treat Optic ID as Face ID for display purposes
                case .none:
                    return .none
                @unknown default:
                    return .none
                }
            },
            
            authenticate: { reason in
                let context = LAContext()
                
                // Configure context
                context.localizedFallbackTitle = "Use Passcode"
                context.localizedCancelTitle = "Cancel"
                
                do {
                    let result = try await context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: reason
                    )
                    return result
                } catch {
                    // Map LAError to BiometricClientError
                    if let laError = error as? LAError {
                        switch laError.code {
                        case .biometryNotAvailable:
                            throw BiometricClientError.notAvailable
                        case .biometryNotEnrolled:
                            throw BiometricClientError.notEnrolled
                        case .userCancel:
                            throw BiometricClientError.userCancel
                        case .userFallback:
                            throw BiometricClientError.userFallback
                        case .systemCancel:
                            throw BiometricClientError.systemCancel
                        case .passcodeNotSet:
                            throw BiometricClientError.passcodeNotSet
                        case .authenticationFailed:
                            throw BiometricClientError.authenticationFailed
                        case .biometryLockout:
                            // Biometry is locked due to too many failed attempts
                            throw BiometricClientError.biometryLocked
                        default:
                            throw BiometricClientError.unknown(error)
                        }
                    } else {
                        throw BiometricClientError.unknown(error)
                    }
                }
            },
            
            authenticateWithPermissionRequest: { reason in
                let context = LAContext()
                
                // Configure context
                context.localizedFallbackTitle = "Use Passcode"
                context.localizedCancelTitle = "Cancel"
                
                do {
                    let result = try await context.evaluatePolicy(
                        .deviceOwnerAuthenticationWithBiometrics,
                        localizedReason: reason
                    )
                    return result
                } catch {
                    // Map LAError to BiometricClientError
                    if let laError = error as? LAError {
                        switch laError.code {
                        case .biometryNotAvailable:
                            throw BiometricClientError.notAvailable
                        case .biometryNotEnrolled:
                            throw BiometricClientError.notEnrolled
                        case .userCancel:
                            throw BiometricClientError.userCancel
                        case .userFallback:
                            throw BiometricClientError.userFallback
                        case .systemCancel:
                            throw BiometricClientError.systemCancel
                        case .passcodeNotSet:
                            throw BiometricClientError.passcodeNotSet
                        case .authenticationFailed:
                            // For repeated failures, try again with device owner authentication
                            let retryContext = LAContext()
                            retryContext.localizedFallbackTitle = "Use Passcode"
                            retryContext.localizedCancelTitle = "Cancel"
                            
                            do {
                                let retryResult = try await retryContext.evaluatePolicy(
                                    .deviceOwnerAuthentication,
                                    localizedReason: reason
                                )
                                return retryResult
                            } catch {
                                throw BiometricClientError.authenticationFailed
                            }
                        case .biometryLockout:
                            // Biometry is locked due to too many failed attempts
                            throw BiometricClientError.biometryLocked
                        default:
                            throw BiometricClientError.unknown(error)
                        }
                    } else {
                        throw BiometricClientError.unknown(error)
                    }
                }
            },
            
            getBiometricType: {
                let context = LAContext()
                var error: NSError?
                
                guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
                    return .none
                }
                
                switch context.biometryType {
                case .faceID:
                    return .faceID
                case .touchID:
                    return .touchID
                case .opticID:
                    return .faceID // Treat Optic ID as Face ID for display purposes
                case .none:
                    return .none
                @unknown default:
                    return .none
                }
            },
            
            isBiometricCapable: {
                let context = LAContext()
                // Check if device has biometric hardware, regardless of enrollment or permission
                switch context.biometryType {
                case .faceID, .touchID, .opticID:
                    return true
                case .none:
                    return false
                @unknown default:
                    return false
                }
            },
            
            openSettings: {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    Task { @MainActor in
                        UIApplication.shared.open(settingsUrl)
                    }
                }
            }
        )
    }()
    
    static let testValue = BiometricClient(
        isAvailable: { .faceID },
        authenticate: { _ in true },
        authenticateWithPermissionRequest: { _ in true },
        getBiometricType: { .faceID },
        isBiometricCapable: { true },
        openSettings: { }
    )
    
    static let mockValue = BiometricClient(
        isAvailable: { .faceID },
        authenticate: { reason in
            // Simulate authentication delay
            try await Task.sleep(for: .milliseconds(500))
            return true
        },
        authenticateWithPermissionRequest: { reason in
            // Simulate authentication delay
            try await Task.sleep(for: .milliseconds(500))
            return true
        },
        getBiometricType: { .faceID },
        isBiometricCapable: { true },
        openSettings: { }
    )
}

extension DependencyValues {
    var biometricClient: BiometricClient {
        get { self[BiometricClient.self] }
        set { self[BiometricClient.self] = newValue }
    }
}