import ComposableArchitecture
import Foundation

@Reducer
struct ConnectivityFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.isOnline) var isOnline: Bool = true
        @Shared(.offlineQueue) var offlineQueue: [OfflineAction] = []

        var offlineQueueCount: Int { offlineQueue.count }
        var canSync: Bool { isOnline && !offlineQueue.isEmpty }
    }

    enum Action {
        case onAppear
        case connectivityChanged(Bool)
        case syncOfflineActions
        case syncCompleted
    }

    @Dependency(\.connectivity) var connectivity
    @Dependency(\.contactRepository) var contactRepository

    var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    for await isOnline in connectivity.onlineStatusStream() {
                        await send(.connectivityChanged(isOnline))
                    }
                }

            case let .connectivityChanged(isOnline):
                state.isOnline = isOnline
                if isOnline && !state.offlineQueue.isEmpty {
                    return .send(.syncOfflineActions)
                }
                return .none

            case .syncOfflineActions:
                guard state.canSync else { return .none }
                return .run { send in
                    try await contactRepository.syncOfflineActions()
                    await send(.syncCompleted)
                }

            case .syncCompleted:
                state.offlineQueue = []
                return .none
            }
        }
    }
}