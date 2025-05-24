// MARK: - Network Errors

import Foundation

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