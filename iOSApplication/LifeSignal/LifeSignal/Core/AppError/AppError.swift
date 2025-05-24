import Foundation

// MARK: - Base App Error

enum AppError: Error, LocalizedError, Equatable {
    case network(NetworkError)
    case authentication(AuthenticationError)
    case repository(RepositoryError)
    case validation(ValidationError)
    case qrCode(QRCodeError)
    case notification(NotificationError)
    case storage(StorageError)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .network(let error):
            return error.errorDescription
        case .authentication(let error):
            return error.errorDescription
        case .repository(let error):
            return error.errorDescription
        case .validation(let error):
            return error.errorDescription
        case .qrCode(let error):
            return error.errorDescription
        case .notification(let error):
            return error.errorDescription
        case .storage(let error):
            return error.errorDescription
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Network Errors

enum NetworkError: Error, LocalizedError, Equatable {
    case noInternet
    case timeout
    case serverError(statusCode: Int)
    case invalidResponse
    case decodingFailed
    case requestFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No internet connection"
        case .timeout:
            return "Request timed out"
        case .serverError(let statusCode):
            return "Server error (code: \(statusCode))"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingFailed:
            return "Failed to decode response"
        case .requestFailed(let reason):
            return reason
        }
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: Error, LocalizedError, Equatable {
    case notAuthenticated
    case invalidCredentials
    case verificationCodeInvalid
    case phoneNumberInvalid
    case sessionExpired
    case accountNotFound
    case accountAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please sign in to continue"
        case .invalidCredentials:
            return "Invalid credentials"
        case .verificationCodeInvalid:
            return "Invalid verification code"
        case .phoneNumberInvalid:
            return "Invalid phone number"
        case .sessionExpired:
            return "Your session has expired"
        case .accountNotFound:
            return "Account not found"
        case .accountAlreadyExists:
            return "An account with this phone number already exists"
        }
    }
}

// MARK: - Repository Errors

enum RepositoryError: Error, LocalizedError, Equatable {
    case fetchFailed(String)
    case saveFailed(String)
    case deleteFailed(String)
    case notFound(String)
    case alreadyExists(String)
    
    var errorDescription: String? {
        switch self {
        case .fetchFailed(let entity):
            return "Failed to fetch \(entity)"
        case .saveFailed(let entity):
            return "Failed to save \(entity)"
        case .deleteFailed(let entity):
            return "Failed to delete \(entity)"
        case .notFound(let entity):
            return "\(entity) not found"
        case .alreadyExists(let entity):
            return "\(entity) already exists"
        }
    }
}

// MARK: - Validation Errors

enum ValidationError: Error, LocalizedError, Equatable {
    case invalidPhoneNumber
    case nameTooShort
    case nameTooLong
    case invalidQRCode
    case invalidTimeInterval
    case missingRequiredField(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidPhoneNumber:
            return "Please enter a valid phone number"
        case .nameTooShort:
            return "Name must be at least 2 characters"
        case .nameTooLong:
            return "Name must be less than 50 characters"
        case .invalidQRCode:
            return "Invalid QR code"
        case .invalidTimeInterval:
            return "Invalid time interval"
        case .missingRequiredField(let field):
            return "\(field) is required"
        }
    }
}

// MARK: - QR Code Errors

enum QRCodeError: Error, LocalizedError, Equatable {
    case generationFailed
    case invalidData
    case scanningFailed
    case alreadyScanned
    
    var errorDescription: String? {
        switch self {
        case .generationFailed:
            return "Failed to generate QR code"
        case .invalidData:
            return "Invalid QR code data"
        case .scanningFailed:
            return "Failed to scan QR code"
        case .alreadyScanned:
            return "This QR code has already been scanned"
        }
    }
}

// MARK: - Notification Errors

enum NotificationError: Error, LocalizedError, Equatable {
    case permissionDenied
    case schedulingFailed
    case notificationCenterUnavailable
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Notification permission denied"
        case .schedulingFailed:
            return "Failed to schedule notification"
        case .notificationCenterUnavailable:
            return "Notification center is unavailable"
        }
    }
}

// MARK: - Storage Errors

enum StorageError: Error, LocalizedError, Equatable {
    case uploadFailed(String)
    case downloadFailed(String)
    case insufficientSpace
    case fileTooLarge
    case invalidFileType
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .insufficientSpace:
            return "Insufficient storage space"
        case .fileTooLarge:
            return "File is too large"
        case .invalidFileType:
            return "Invalid file type"
        }
    }
}