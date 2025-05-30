import SwiftUI
import ComposableArchitecture

// MARK: - Test Feature and View Pair (Same File)

/// Test Feature that demonstrates FeatureContext protocol with paired view
@Reducer
struct TestFeature: FeatureContext {
    
    /// The view paired with this feature (same file requirement)
    typealias PairedView = TestView
    
    @ObservableState
    struct State: Equatable {
        var count: Int = 0
        var isLoading: Bool = false
        var message: String = "Hello, LifeSignal!"
    }
    
    enum Action: Equatable {
        case incrementTapped
        case decrementTapped
        case loadDataTapped
        case dataLoaded(String)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .incrementTapped:
                state.count += 1
                return .none
                
            case .decrementTapped:
                state.count -= 1
                return .none
                
            case .loadDataTapped:
                state.isLoading = true
                return .run { send in
                    try await Task.sleep(for: .seconds(1))
                    await send(.dataLoaded("Data loaded at \(Date())"))
                }
                
            case let .dataLoaded(message):
                state.isLoading = false
                state.message = message
                return .none
            }
        }
    }
}

/// Test View that demonstrates FeatureView protocol paired with TestFeature
struct TestView: View, FeatureView {
    
    /// The feature paired with this view (same file requirement)
    typealias PairedFeature = TestFeature
    
    @Bindable var store: StoreOf<TestFeature>
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Test LifeSignal Architecture")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Count: \(store.count)")
                .font(.headline)
            
            HStack(spacing: 16) {
                Button("Decrement") {
                    store.send(.decrementTapped)
                }
                .buttonStyle(.bordered)
                
                Button("Increment") {
                    store.send(.incrementTapped)
                }
                .buttonStyle(.borderedProminent)
            }
            
            Divider()
            
            Text(store.message)
                .font(.body)
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Load Data") {
                store.send(.loadDataTapped)
            }
            .buttonStyle(.bordered)
            .disabled(store.isLoading)
            
            if store.isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Preview

#Preview {
    TestView(
        store: Store(initialState: TestFeature.State()) {
            TestFeature()
        }
    )
    .padding()
}