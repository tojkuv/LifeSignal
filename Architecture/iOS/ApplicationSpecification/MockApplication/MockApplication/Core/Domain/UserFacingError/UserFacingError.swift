import Foundation

/// User-facing error types that are Equatable and Sendable for use in TCA
enum UserFacingError: Error, Equatable, Sendable {
    /// Authentication errors
    case notAuthenticated
    case authenticationFailed(String)
    
    /// Network errors
    case networkError
    case serverError
    case requestTimeout
    
    /// Data errors
    case dataNotFound
    case dataInvalid
    case operationFailed(String)
    
    /// Permission errors
    case permissionDenied
    
    /// Session errors
    case sessionInvalid
    case sessionExpired
    
    /// Notification errors
    case notificationPermissionDenied
    
    /// Unknown error
    case unknown(String)
}
