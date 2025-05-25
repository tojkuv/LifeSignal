import Foundation
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Network Shared State

extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
    static var isNetworkConnected: Self {
        Self[.inMemory("isNetworkConnected"), default: true]
    }
}

extension SharedReaderKey where Self == InMemoryKey<Date?>.Default {
    static var lastNetworkCheck: Self {
        Self[.inMemory("lastNetworkCheck"), default: nil]
    }
}

// MARK: - Network Client Errors

enum NetworkClientError: Error, LocalizedError {
    case connectionUnavailable(String)
    case connectionTimeout(String)
    case connectionFailure(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionUnavailable(let details):
            return "Network connection unavailable: \(details)"
        case .connectionTimeout(let details):
            return "Network connection timeout: \(details)"
        case .connectionFailure(let details):
            return "Network connection failed: \(details)"
        }
    }
}

// MARK: - Network Client

@DependencyClient
struct NetworkClient {
    // Core connectivity functions
    var checkConnectivity: @Sendable () async -> Bool = { true }
    var updateNetworkStatus: @Sendable (Bool) async -> Void = { _ in }
    var monitorConnectivity: @Sendable () async -> AsyncStream<Bool> = {
        AsyncStream { _ in }
    }
    
    // Connection validation
    var isReachable: @Sendable (String) async -> Bool = { _ in true }
    var pingServer: @Sendable () async throws -> TimeInterval = { 0.1 }
    
    // Network status information
    var getConnectionType: @Sendable () async -> ConnectionType = { .wifi }
    var getNetworkQuality: @Sendable () async -> NetworkQuality = { .good }
    
    enum ConnectionType: String, CaseIterable, Sendable {
        case none = "none"
        case cellular = "cellular"
        case wifi = "wifi"
        case ethernet = "ethernet"
        
        var displayName: String {
            switch self {
            case .none: return "No Connection"
            case .cellular: return "Cellular"
            case .wifi: return "Wi-Fi"
            case .ethernet: return "Ethernet"
            }
        }
    }
    
    enum NetworkQuality: String, CaseIterable, Sendable {
        case poor = "poor"
        case fair = "fair"
        case good = "good"
        case excellent = "excellent"
        
        var displayName: String {
            switch self {
            case .poor: return "Poor"
            case .fair: return "Fair"
            case .good: return "Good"
            case .excellent: return "Excellent"
            }
        }
    }
}

extension NetworkClient: DependencyKey {
    static let liveValue: NetworkClient = NetworkClient()
    static let testValue = NetworkClient()
    
    static let mockValue = NetworkClient(
        checkConnectivity: {
            @Shared(.isNetworkConnected) var isConnected
            @Shared(.lastNetworkCheck) var lastCheck
            $lastNetworkCheck.withLock { $0 = Date() }
            return isConnected
        },
        
        updateNetworkStatus: { connected in
            @Shared(.isNetworkConnected) var isConnected
            @Shared(.lastNetworkCheck) var lastCheck
            $isConnected.withLock { $0 = connected }
            $lastNetworkCheck.withLock { $0 = Date() }
        },
        
        monitorConnectivity: {
            AsyncStream { continuation in
                Task {
                    @Shared(.isNetworkConnected) var isConnected
                    
                    // Simulate connectivity changes
                    while !Task.isCancelled {
                        continuation.yield(isConnected)
                        try await Task.sleep(for: .seconds(2))
                    }
                    continuation.finish()
                }
            }
        },
        
        isReachable: { host in
            @Shared(.isNetworkConnected) var isConnected
            return isConnected
        },
        
        pingServer: {
            @Shared(.isNetworkConnected) var isConnected
            guard isConnected else {
                throw NetworkClientError.connectionUnavailable("No network connection")
            }
            
            // Simulate network ping
            try await Task.sleep(for: .milliseconds(50))
            return 0.05 // 50ms ping
        },
        
        getConnectionType: {
            @Shared(.isNetworkConnected) var isConnected
            return isConnected ? .wifi : .none
        },
        
        getNetworkQuality: {
            @Shared(.isNetworkConnected) var isConnected
            return isConnected ? .good : .poor
        }
    )
}

extension DependencyValues {
    var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}