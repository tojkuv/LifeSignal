# Performance Considerations

**Navigation:** [Back to iOS Architecture](../README.md)

---

> **Note:** As this is an MVP, the performance considerations may evolve as the project matures.

## Performance Design Principles

Performance in LifeSignal follows these core principles:

1. **Efficient State Updates**: Minimize unnecessary state updates
2. **Optimized Effects**: Optimize effects for performance
3. **Efficient View Rendering**: Minimize unnecessary view rendering
4. **Memory Management**: Properly manage memory
5. **Background Processing**: Perform intensive work in the background

## State Update Optimization

### Use onChange for Selective Effect Execution

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      // Reducer implementation...
    }
    .onChange(of: \.searchText) { oldValue, newValue in
      guard !newValue.isEmpty else {
        return .none
      }
      
      return .run { send in
        let results = try await searchClient.search(newValue)
        await send(.searchResponse(results))
      }
      .cancellable(id: CancelID.search)
    }
  }
}
```

### Avoid Computed Properties in Scopes

```swift
// Inefficient
extension ParentFeature.State {
  var computedChild: ChildFeature.State {
    ChildFeature.State(
      // Heavy computation here...
    )
  }
}

ChildView(
  store: store.scope(state: \.computedChild, action: \.child)
)

// Efficient
extension ParentFeature.State {
  var child: ChildFeature.State {
    get { _child }
    set { _child = newValue }
  }
  var _child = ChildFeature.State()
}

ChildView(
  store: store.scope(state: \.child, action: \.child)
)
```

## Effect Optimization

### Use Task.yield() for CPU-Intensive Work

```swift
case .processDataButtonTapped:
  return .run { send in
    var result = // ...
    for (index, value) in someLargeCollection.enumerated() {
      // Some intense computation with value

      // Yield every once in awhile to cooperate in the thread pool.
      if index.isMultiple(of: 1_000) {
        await Task.yield()
      }
    }
    await send(.processDataResponse(result))
  }
```

### Share Logic with Methods

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .buttonTapped:
        state.count += 1
        return self.sharedComputation(state: &state)

      case .toggleChanged:
        state.isEnabled.toggle()
        return self.sharedComputation(state: &state)

      case let .textFieldChanged(text):
        state.description = text
        return self.sharedComputation(state: &state)
      }
    }
  }

  func sharedComputation(state: inout State) -> Effect<Action> {
    // Some shared work to compute something.
    return .run { send in
      // A shared effect to compute something
    }
  }
}
```

### Use TaskResult Caching

```swift
@Reducer
struct Feature {
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .loadDataButtonTapped:
        return .run { [id = state.id] send in
          let result = try await TaskResult {
            try await dataClient.loadData(id)
          }
          await send(.dataResponse(result))
        }
        
      case let .dataResponse(.success(data)):
        state.data = data
        return .none
        
      case let .dataResponse(.failure(error)):
        state.error = error
        return .none
      }
    }
  }
}
```

## View Rendering Optimization

### Use ._printChanges() to Identify Unnecessary Updates

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    Form {
      // View implementation...
    }
    ._printChanges()
  }
}
```

### Use Equatable for State

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var count = 0
    var isLoading = false
    var error: Error?
    var user: User?
    
    static func == (lhs: State, rhs: State) -> Bool {
      lhs.count == rhs.count &&
      lhs.isLoading == rhs.isLoading &&
      (lhs.error != nil) == (rhs.error != nil) &&
      lhs.user == rhs.user
    }
  }
  
  // Actions, body, etc.
}
```

### Use Lazy Views

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>
  
  var body: some View {
    List {
      ForEach(store.items) { item in
        LazyVStack {
          Text(item.name)
          
          if store.isExpanded[item.id] ?? false {
            // Expensive view that's only created when needed
            DetailView(item: item)
          }
        }
      }
    }
  }
}
```

## Memory Management

### Cancel Effects When No Longer Needed

```swift
case .viewDidAppear:
  return .run { send in
    for await data in await dataClient.streamData() {
      await send(.dataReceived(data))
    }
  }
  .cancellable(id: CancelID.dataStream)

case .viewDidDisappear:
  return .cancel(id: CancelID.dataStream)
```

### Use Weak References in Closures

```swift
return .run { [weak self] send in
  guard let self = self else { return }
  
  // Use self safely
}
```

### Release Resources When Done

```swift
case .viewDidDisappear:
  return .merge(
    .cancel(id: CancelID.dataStream),
    .run { _ in
      await dataClient.closeConnection()
    }
  )
```

## Background Processing

### Use Background Tasks

```swift
case .processDataButtonTapped:
  return .run { send in
    await send(.processingStarted)
    
    let result = await Task.detached {
      // Perform CPU-intensive work in a background thread
      return processData()
    }.value
    
    await send(.processingFinished(result))
  }
```

### Use DispatchQueue for UI Updates

```swift
case .dataReceived(let data):
  return .run { send in
    // Process data in the background
    let processedData = await Task.detached {
      return processData(data)
    }.value
    
    // Update UI on the main thread
    await MainActor.run {
      await send(.processedDataReceived(processedData))
    }
  }
```

## Firebase Optimization

### Use Efficient Queries

```swift
func getItems() async throws -> [Item] {
  // Use efficient queries with limits and filters
  let snapshot = try await firestore
    .collection("items")
    .whereField("userId", isEqualTo: userId)
    .limit(to: 20)
    .getDocuments()
  
  return snapshot.documents.compactMap { document in
    try? document.data(as: Item.self)
  }
}
```

### Use Atomic Operations

```swift
func incrementCounter() async throws {
  try await firestore
    .document("counters/\(userId)")
    .updateData([
      "count": FieldValue.increment(Int64(1))
    ])
}
```

### Use Batched Writes

```swift
func updateMultipleItems(items: [Item]) async throws {
  let batch = firestore.batch()
  
  for item in items {
    let docRef = firestore.document("items/\(item.id)")
    batch.updateData(item.dictionary, forDocument: docRef)
  }
  
  try await batch.commit()
}
```

## Shared State Optimization

### Use Appropriate Persistence Strategy

```swift
// In-memory persistence (resets on app restart)
@Shared(.inMemory("count")) var count = 0

// UserDefaults persistence
@Shared(.appStorage("count")) var count = 0

// Document-based persistence
@Shared(.document("count")) var count = 0
```

## Best Practices

1. **Use onChange**: Use `onChange` for selective effect execution
2. **Avoid Computed Properties in Scopes**: Store computed values in state
3. **Use Task.yield()**: Use `Task.yield()` for CPU-intensive work
4. **Share Logic with Methods**: Share logic using methods
5. **Use TaskResult Caching**: Cache expensive computations
6. **Use ._printChanges()**: Use `._printChanges()` to identify unnecessary updates
7. **Use Equatable for State**: Implement `Equatable` for state
8. **Use Lazy Views**: Use lazy views for expensive UI
9. **Cancel Effects**: Cancel effects when no longer needed
10. **Use Background Tasks**: Perform intensive work in the background
