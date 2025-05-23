import ComposableArchitecture
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct ConnectivityClient {
    var isOnline: @Sendable () -> Bool = { true }
    var onlineStatusStream: @Sendable () -> AsyncStream<Bool> = {
        AsyncStream { continuation in
            continuation.yield(true)
            continuation.finish()
        }
    }
}

extension ConnectivityClient: DependencyKey {
    static let liveValue = ConnectivityClient(
        isOnline: { true },
        onlineStatusStream: {
            AsyncStream { continuation in
                // Mock connectivity changes
                Task {
                    continuation.yield(true)
                    try? await Task.sleep(for: .seconds(10))
                    continuation.yield(false)
                    try? await Task.sleep(for: .seconds(5))
                    continuation.yield(true)
                }
            }
        }
    )
    
    static let testValue = ConnectivityClient(
        isOnline: { true },
        onlineStatusStream: {
            AsyncStream { continuation in
                continuation.yield(true)
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var connectivity: ConnectivityClient {
        get { self[ConnectivityClient.self] }
        set { self[ConnectivityClient.self] = newValue }
    }
}