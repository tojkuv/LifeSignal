import DependenciesMacros
import Foundation
import ComposableArchitecture

// MARK: - Logging Client (MVP Mock Implementation)

@DependencyClient
struct LoggingClient {
    var debug: @Sendable (String, [String: Any]) -> Void = { _, _ in }
    var info: @Sendable (String, [String: Any]) -> Void = { _, _ in }
    var warning: @Sendable (String, [String: Any]) -> Void = { _, _ in }
    var error: @Sendable (String, Error?, [String: Any]) -> Void = { _, _, _ in }
}

extension LoggingClient: DependencyKey {
    static let liveValue = LoggingClient.mockValue
    static let testValue = LoggingClient.mockValue
    
    static let mockValue = LoggingClient(
        debug: { message, metadata in
            print("🐛 [MOCK] DEBUG: \(message)")
            if !metadata.isEmpty {
                print("   Metadata: \(metadata)")
            }
        },
        
        info: { message, metadata in
            print("ℹ️ [MOCK] INFO: \(message)")
            if !metadata.isEmpty {
                print("   Metadata: \(metadata)")
            }
        },
        
        warning: { message, metadata in
            print("⚠️ [MOCK] WARNING: \(message)")
            if !metadata.isEmpty {
                print("   Metadata: \(metadata)")
            }
        },
        
        error: { message, error, metadata in
            print("❌ [MOCK] ERROR: \(message)")
            if let error = error {
                print("   Error: \(error.localizedDescription)")
            }
            if !metadata.isEmpty {
                print("   Metadata: \(metadata)")
            }
        }
    )
}

extension DependencyValues {
    var logging: LoggingClient {
        get { self[LoggingClient.self] }
        set { self[LoggingClient.self] = newValue }
    }
}