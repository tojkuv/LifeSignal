import Foundation
import Network
import ComposableArchitecture
import Dependencies
import DependenciesMacros
@_exported import Sharing

// MARK: - Network Shared State

struct NetworkClientState: Equatable, Codable {
    var isConnected: Bool
    var connectionType: NetworkConnectionType
    var lastConnectedTimestamp: Date?
    var lastDisconnectedTimestamp: Date?
    var isExpensive: Bool
    var isConstrained: Bool
    
    init(
        isConnected: Bool = false,
        connectionType: NetworkConnectionType = .none,
        lastConnectedTimestamp: Date? = nil,
        lastDisconnectedTimestamp: Date? = nil,
        isExpensive: Bool = false,
        isConstrained: Bool = false
    ) {
        self.isConnected = isConnected
        self.connectionType = connectionType
        self.lastConnectedTimestamp = lastConnectedTimestamp
        self.lastDisconnectedTimestamp = lastDisconnectedTimestamp
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}

enum NetworkConnectionType: String, Codable, Equatable {
    case none = "none"
    case wifi = "wifi"
    case cellular = "cellular"
    case wiredEthernet = "ethernet"
    case other = "other"
}

// MARK: - Clean Shared Key Implementation (FileStorage)

extension SharedReaderKey where Self == FileStorageKey<NetworkClientState>.Default {
    static var networkInternalState: Self {
        Self[.fileStorage(.documentsDirectory.appending(component: "networkInternalState.json")), default: NetworkClientState()]
    }
}

// MARK: - Network Monitor Service

protocol NetworkMonitorServiceProtocol: Sendable {
    func startMonitoring() async
    func stopMonitoring() async
    func getCurrentStatus() async -> NetworkStatus
    var statusUpdates: AsyncStream<NetworkStatus> { get }
}

struct NetworkStatus: Sendable, Equatable {
    let isConnected: Bool
    let connectionType: NetworkConnectionType
    let isExpensive: Bool
    let isConstrained: Bool
    let timestamp: Date
}

// MARK: - Live Network Monitor Implementation

final class LiveNetworkMonitorService: NetworkMonitorServiceProtocol, Sendable {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    private let statusContinuation: AsyncStream<NetworkStatus>.Continuation
    private let _statusUpdates: AsyncStream<NetworkStatus>
    
    var statusUpdates: AsyncStream<NetworkStatus> { _statusUpdates }
    
    init() {
        let (stream, continuation) = AsyncStream<NetworkStatus>.makeStream()
        self._statusUpdates = stream
        self.statusContinuation = continuation
        
        monitor.pathUpdateHandler = { [weak self] path in
            let status = NetworkStatus(
                isConnected: path.status == .satisfied,
                connectionType: self?.getConnectionType(from: path) ?? .none,
                isExpensive: path.isExpensive,
                isConstrained: path.isConstrained,
                timestamp: Date()
            )
            self?.statusContinuation.yield(status)
        }
    }
    
    func startMonitoring() async {
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() async {
        monitor.cancel()
        statusContinuation.finish()
    }
    
    func getCurrentStatus() async -> NetworkStatus {
        let path = monitor.currentPath
        return NetworkStatus(
            isConnected: path.status == .satisfied,
            connectionType: getConnectionType(from: path),
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            timestamp: Date()
        )
    }
    
    private func getConnectionType(from path: NWPath) -> NetworkConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .wiredEthernet
        } else if path.status == .satisfied {
            return .other
        } else {
            return .none
        }
    }
}

// MARK: - Mock Network Monitor Implementation

actor MockNetworkMonitorService: NetworkMonitorServiceProtocol {
    private let statusContinuation: AsyncStream<NetworkStatus>.Continuation
    private let _statusUpdates: AsyncStream<NetworkStatus>
    private var isMonitoring = false
    
    nonisolated var statusUpdates: AsyncStream<NetworkStatus> { _statusUpdates }
    
    init() {
        let (stream, continuation) = AsyncStream<NetworkStatus>.makeStream()
        self._statusUpdates = stream
        self.statusContinuation = continuation
    }
    
    func startMonitoring() async {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Start with connected state
        let initialStatus = NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false,
            timestamp: Date()
        )
        statusContinuation.yield(initialStatus)
        
        // Simulate network changes for testing
        Task {
            try? await Task.sleep(for: .seconds(5))
            if isMonitoring {
                let disconnectedStatus = NetworkStatus(
                    isConnected: false,
                    connectionType: .none,
                    isExpensive: false,
                    isConstrained: false,
                    timestamp: Date()
                )
                statusContinuation.yield(disconnectedStatus)
            }
            
            try? await Task.sleep(for: .seconds(3))
            if isMonitoring {
                let reconnectedStatus = NetworkStatus(
                    isConnected: true,
                    connectionType: .cellular,
                    isExpensive: true,
                    isConstrained: true,
                    timestamp: Date()
                )
                statusContinuation.yield(reconnectedStatus)
            }
        }
    }
    
    func stopMonitoring() async {
        isMonitoring = false
        statusContinuation.finish()
    }
    
    func getCurrentStatus() async -> NetworkStatus {
        return NetworkStatus(
            isConnected: true,
            connectionType: .wifi,
            isExpensive: false,
            isConstrained: false,
            timestamp: Date()
        )
    }
}

// MARK: - Network Client Errors

enum NetworkClientError: Error, LocalizedError {
    case monitoringFailed(String)
    case networkUnavailable
    case connectionTimeout
    case invalidConfiguration
    
    var errorDescription: String? {
        switch self {
        case .monitoringFailed(let details):
            return "Network monitoring failed: \(details)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .connectionTimeout:
            return "Network connection timed out"
        case .invalidConfiguration:
            return "Invalid network configuration"
        }
    }
}

// MARK: - NetworkClient (TCA Shared State Pattern)

@LifeSignalClient
@DependencyClient
struct NetworkClient: ClientContext {
    
    // MARK: - StateOwner Implementation (will be enforced by macro in Phase 2)
    // typealias OwnedState = NetworkClientState
    // static var stateKey: any SharedReaderKey<NetworkClientState> { .networkInternalState }
    
    // MARK: - Network Monitoring
    var startNetworkMonitoring: @Sendable () async throws -> Void = { }
    var stopNetworkMonitoring: @Sendable () async throws -> Void = { }
    var getCurrentNetworkStatus: @Sendable () async -> NetworkStatus = {
        NetworkStatus(
            isConnected: false,
            connectionType: .none,
            isExpensive: false,
            isConstrained: false,
            timestamp: Date()
        )
    }
    
    // MARK: - Network State Queries
    var isConnected: @Sendable () -> Bool = { false }
    var connectionType: @Sendable () -> NetworkConnectionType = { .none }
    var isExpensiveConnection: @Sendable () -> Bool = { false }
    var isConstrainedConnection: @Sendable () -> Bool = { false }
    
    // MARK: - State Management
    var clearNetworkState: @Sendable () async throws -> Void = { }
}

extension NetworkClient: DependencyKey {
    static let liveValue = NetworkClient(
        startNetworkMonitoring: {
            let service = LiveNetworkMonitorService()
            
            await service.startMonitoring()
            
            // Update shared state with network status changes
            Task {
                for await status in service.statusUpdates {
                    @Shared(.networkInternalState) var networkState
                    $networkState.withLock { state in
                        let now = Date()
                        
                        // Update connection state
                        let wasConnected = state.isConnected
                        state.isConnected = status.isConnected
                        state.connectionType = status.connectionType
                        state.isExpensive = status.isExpensive
                        state.isConstrained = status.isConstrained
                        
                        // Update timestamps
                        if !wasConnected && status.isConnected {
                            state.lastConnectedTimestamp = now
                        } else if wasConnected && !status.isConnected {
                            state.lastDisconnectedTimestamp = now
                        }
                    }
                }
            }
        },
        
        stopNetworkMonitoring: {
            let service = LiveNetworkMonitorService()
            await service.stopMonitoring()
        },
        
        getCurrentNetworkStatus: {
            let service = LiveNetworkMonitorService()
            return await service.getCurrentStatus()
        },
        
        isConnected: {
            @Shared(.networkInternalState) var networkState
            return networkState.isConnected
        },
        
        connectionType: {
            @Shared(.networkInternalState) var networkState
            return networkState.connectionType
        },
        
        isExpensiveConnection: {
            @Shared(.networkInternalState) var networkState
            return networkState.isExpensive
        },
        
        isConstrainedConnection: {
            @Shared(.networkInternalState) var networkState
            return networkState.isConstrained
        },
        
        clearNetworkState: {
            @Shared(.networkInternalState) var networkState
            $networkState.withLock { state in
                state.isConnected = false
                state.connectionType = .none
                state.lastConnectedTimestamp = nil
                state.lastDisconnectedTimestamp = nil
                state.isExpensive = false
                state.isConstrained = false
            }
        }
    )
    
    static let testValue = NetworkClient()
    
    static let mockValue = NetworkClient(
        startNetworkMonitoring: {
            let service = MockNetworkMonitorService()
            
            await service.startMonitoring()
            
            // Update shared state with mock network status changes
            Task {
                for await status in service.statusUpdates {
                    @Shared(.networkInternalState) var networkState
                    $networkState.withLock { state in
                        let now = Date()
                        
                        // Update connection state
                        let wasConnected = state.isConnected
                        state.isConnected = status.isConnected
                        state.connectionType = status.connectionType
                        state.isExpensive = status.isExpensive
                        state.isConstrained = status.isConstrained
                        
                        // Update timestamps
                        if !wasConnected && status.isConnected {
                            state.lastConnectedTimestamp = now
                        } else if wasConnected && !status.isConnected {
                            state.lastDisconnectedTimestamp = now
                        }
                    }
                }
            }
        },
        
        stopNetworkMonitoring: {
            let service = MockNetworkMonitorService()
            await service.stopMonitoring()
        },
        
        getCurrentNetworkStatus: {
            let service = MockNetworkMonitorService()
            return await service.getCurrentStatus()
        },
        
        isConnected: {
            @Shared(.networkInternalState) var networkState
            return networkState.isConnected
        },
        
        connectionType: {
            @Shared(.networkInternalState) var networkState
            return networkState.connectionType
        },
        
        isExpensiveConnection: {
            @Shared(.networkInternalState) var networkState
            return networkState.isExpensive
        },
        
        isConstrainedConnection: {
            @Shared(.networkInternalState) var networkState
            return networkState.isConstrained
        },
        
        clearNetworkState: {
            @Shared(.networkInternalState) var networkState
            $networkState.withLock { state in
                state.isConnected = false
                state.connectionType = .none
                state.lastConnectedTimestamp = nil
                state.lastDisconnectedTimestamp = nil
                state.isExpensive = false
                state.isConstrained = false
            }
        }
    )
}

extension DependencyValues {
    var networkClient: NetworkClient {
        get { self[NetworkClient.self] }
        set { self[NetworkClient.self] = newValue }
    }
}