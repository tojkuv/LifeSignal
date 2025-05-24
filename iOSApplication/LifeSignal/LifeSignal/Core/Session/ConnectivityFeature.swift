import SwiftUI
import Foundation
import ComposableArchitecture

@Reducer
struct ConnectivityFeature {
    @ObservableState
    struct State: Equatable {
        var isOnline = true
        var isSyncing = false
        var syncError: String? = nil
        var offlineQueueCount = 0
        var lastSyncTime: Date? = nil
        var retryAttempts = 0
        var maxRetryAttempts = 3
        var syncInterval: TimeInterval = 30
        var isAutoSyncEnabled = true
        var connectivityBannerMessage: String? = nil
        var showConnectivityBanner = false
    }

    enum Action {
        case onAppear
        case startMonitoring
        case stopMonitoring
        case connectivityChanged(Bool)
        case startSync
        case syncCompleted(Result<Void, Error>)
        case retrySync
        case retryOfflineActions
        case clearSyncError
        case updateOfflineQueueCount(Int)
        case dismissConnectivityBanner
        case toggleAutoSync(Bool)
        case performHealthCheck
        case healthCheckCompleted(Bool)
    }

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .none
                
            case .startMonitoring:
                return .none
                
            case .stopMonitoring:
                return .none
                
            case .connectivityChanged(let isOnline):
                state.isOnline = isOnline
                state.showConnectivityBanner = !isOnline
                state.connectivityBannerMessage = isOnline ? nil : "No internet connection"
                return .none
                
            case .startSync:
                guard state.isOnline && !state.isSyncing else { return .none }
                state.isSyncing = true
                state.syncError = nil
                return .none
                
            case .syncCompleted(.success):
                state.isSyncing = false
                state.lastSyncTime = Date()
                state.retryAttempts = 0
                return .none
                
            case .syncCompleted(.failure(let error)):
                state.isSyncing = false
                state.syncError = error.localizedDescription
                state.retryAttempts += 1
                return .none
                
            case .retrySync:
                guard state.retryAttempts < state.maxRetryAttempts else { return .none }
                return .send(.startSync)
                
            case .retryOfflineActions:
                return .none
                
            case .clearSyncError:
                state.syncError = nil
                state.retryAttempts = 0
                return .none
                
            case .updateOfflineQueueCount(let count):
                state.offlineQueueCount = count
                return .none
                
            case .dismissConnectivityBanner:
                state.showConnectivityBanner = false
                return .none
                
            case .toggleAutoSync(let enabled):
                state.isAutoSyncEnabled = enabled
                return .none
                
            case .performHealthCheck:
                return .none
                
            case .healthCheckCompleted(let isHealthy):
                if !isHealthy {
                    state.syncError = "Health check failed"
                }
                return .none
            }
        }
    }
}