# Performance Optimization in TCA

**Navigation:** [Back to iOS Architecture](../../../README_copy.md)

---

## Overview

Performance optimization in The Composable Architecture (TCA) is essential for building responsive and efficient applications. This document outlines the principles and patterns for optimizing performance in modern TCA applications using the latest features and best practices.

## Core Principles

### 1. Selective Effect Execution

Use the `onChange` reducer operator for selective effect execution:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var query = ""
    var results: [Result] = []
    var isLoading = false
  }

  enum Action: Equatable, Sendable {
    case queryChanged(String)
    case resultsLoaded([Result])
  }

  @Dependency(\.searchClient) var searchClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .queryChanged(query):
        state.query = query
        return .none

      case let .resultsLoaded(results):
        state.results = results
        state.isLoading = false
        return .none
      }
    }
    .onChange(of: \.query) { oldQuery, newQuery in
      guard !newQuery.isEmpty else {
        return .none
      }

      return .run { send in
        let results = try await searchClient.search(newQuery)
        await send(.resultsLoaded(results))
      }
      .cancellable(id: SearchCancelID.self)
    }
  }
}
```

This ensures:
- Effects are only executed when relevant state changes
- Unnecessary effect executions are avoided
- Clear separation between state updates and effect triggers

### 2. TaskResult Caching

Use `TaskResult` caching for expensive computations:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var input = ""
    var result: TaskResult<String>?
  }

  enum Action: Equatable, Sendable {
    case inputChanged(String)
    case computeResult
    case resultComputed(TaskResult<String>)
  }

  @Dependency(\.expensiveComputation) var expensiveComputation

  private struct ComputationCancelID: Hashable {}

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .inputChanged(input):
        state.input = input
        return .none

      case .computeResult:
        state.result = .loading

        return .run { [input = state.input] send in
          await send(
            .resultComputed(
              await TaskResult {
                try await expensiveComputation(input)
              }
            )
          )
        }
        .cancellable(id: ComputationCancelID())

      case let .resultComputed(result):
        state.result = result
        return .none
      }
    }
  }
}
```

This ensures:
- Expensive computations are only performed when necessary
- Loading states are properly managed
- Error handling is consistent

### 3. Task Yielding

Yield periodically during CPU-intensive work:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable {
    var data: [Data] = []
    var processedData: [ProcessedData] = []
    var isProcessing = false
    var progress = 0.0
  }

  enum Action: Equatable, Sendable {
    case processButtonTapped
    case processingProgressed(Double)
    case processingCompleted([ProcessedData])
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .processButtonTapped:
        state.isProcessing = true
        state.progress = 0.0

        return .run { [data = state.data] send in
          var processedData: [ProcessedData] = []
          let total = Double(data.count)

          for (index, item) in data.enumerated() {
            let processed = await processItem(item)
            processedData.append(processed)

            let progress = Double(index + 1) / total
            await send(.processingProgressed(progress))

            // Yield every 100 items to keep UI responsive
            if (index + 1) % 100 == 0 {
              await Task.yield()
            }
          }

          await send(.processingCompleted(processedData))
        }

      case let .processingProgressed(progress):
        state.progress = progress
        return .none

      case let .processingCompleted(processedData):
        state.processedData = processedData
        state.isProcessing = false
        return .none
      }
    }
  }

  private func processItem(_ item: Data) async -> ProcessedData {
    // Expensive processing logic
    return ProcessedData()
  }
}
```

This ensures:
- UI remains responsive during heavy processing
- Progress updates are provided to the user
- CPU time is shared fairly with other tasks

### 4. Print Changes

Use `._printChanges()` during development to identify unnecessary state updates:

```swift
struct FeatureView: View {
  @Bindable var store: StoreOf<Feature>

  var body: some View {
    VStack {
      Text("Count: \(store.count)")
      Button("Increment") { store.send(.incrementButtonTapped) }
    }
    ._printChanges()
  }
}
```

This helps:
- Identify unnecessary view updates
- Pinpoint performance bottlenecks
- Optimize state updates

### 5. Shared State

Use `@Shared` with appropriate persistence strategy for shared state:

```swift
@Reducer
struct ParentFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Shared(.inMemory("count")) var count = 0
    var localState = ""
  }

  enum Action: Equatable, Sendable {
    case incrementButtonTapped
    case textChanged(String)
    case child(ChildFeature.Action)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1  // Automatically synchronized with child
        return .none

      case let .textChanged(text):
        state.localState = text
        return .none

      case .child:
        return .none
      }
    }
    .ifLet(\.child, action: \.child) {
      ChildFeature()
    }
  }
}

@Reducer
struct ChildFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    @Shared(.inMemory("count")) var count = 0  // Shared with parent
    var childLocalState = ""
  }

  enum Action: Equatable, Sendable {
    case decrementButtonTapped
    case childTextChanged(String)
  }

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .decrementButtonTapped:
        state.count -= 1  // Automatically synchronized with parent
        return .none

      case let .childTextChanged(text):
        state.childLocalState = text
        return .none
      }
    }
  }
}
```

This ensures:
- State is shared efficiently across features
- State updates are thread-safe
- State persistence is handled appropriately

## Performance Optimization Patterns

### 1. Debouncing User Input

Debounce rapidly changing user input:

```swift
@Reducer
struct SearchFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var query = ""
    var results: [Result] = []
    var isLoading = false
  }

  enum Action: Equatable, Sendable {
    case queryChanged(String)
    case debouncedQueryChanged(String)
    case resultsLoaded([Result])
  }

  @Dependency(\.searchClient) var searchClient
  @Dependency(\.continuousClock) var clock

  private struct SearchCancelID: Hashable {}

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .queryChanged(query):
        state.query = query

        return .run { send in
          try await clock.sleep(for: .milliseconds(300))
          await send(.debouncedQueryChanged(query))
        }
        .cancellable(id: SearchCancelID())

      case let .debouncedQueryChanged(query):
        guard !query.isEmpty else {
          state.results = []
          return .none
        }

        state.isLoading = true

        return .run { send in
          let results = try await searchClient.search(query)
          await send(.resultsLoaded(results))
        }

      case let .resultsLoaded(results):
        state.results = results
        state.isLoading = false
        return .none
      }
    }
  }
}
```

### 2. Pagination

Implement pagination for large data sets:

```swift
@Reducer
struct ListFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var items: [Item] = []
    var nextPage: String?
    var isLoading = false
    var hasReachedEnd = false
  }

  enum Action: Equatable, Sendable {
    case onAppear
    case loadNextPage
    case itemsLoaded([Item], nextPage: String?)
  }

  @Dependency(\.itemsClient) var itemsClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        guard state.items.isEmpty else { return .none }

        state.isLoading = true

        return .run { send in
          let (items, nextPage) = try await itemsClient.getItems(page: nil)
          await send(.itemsLoaded(items, nextPage: nextPage))
        }

      case .loadNextPage:
        guard !state.isLoading, !state.hasReachedEnd, let nextPage = state.nextPage else {
          return .none
        }

        state.isLoading = true

        return .run { send in
          let (items, nextPage) = try await itemsClient.getItems(page: nextPage)
          await send(.itemsLoaded(items, nextPage: nextPage))
        }

      case let .itemsLoaded(newItems, nextPage):
        state.items.append(contentsOf: newItems)
        state.nextPage = nextPage
        state.isLoading = false
        state.hasReachedEnd = nextPage == nil
        return .none
      }
    }
  }
}
```

### 3. Lazy Loading

Implement lazy loading for expensive resources:

```swift
@Reducer
struct GalleryFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var photos: [Photo] = []
    var loadedImages: [String: TaskResult<UIImage>] = [:]
  }

  enum Action: Equatable, Sendable {
    case onAppear
    case photosLoaded([Photo])
    case loadImage(String)
    case imageLoaded(String, TaskResult<UIImage>)
  }

  @Dependency(\.photoClient) var photoClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          let photos = try await photoClient.getPhotos()
          await send(.photosLoaded(photos))
        }

      case let .photosLoaded(photos):
        state.photos = photos
        return .none

      case let .loadImage(id):
        guard state.loadedImages[id] == nil else { return .none }

        state.loadedImages[id] = .loading

        return .run { [id] send in
          await send(
            .imageLoaded(
              id,
              await TaskResult {
                try await photoClient.loadImage(id)
              }
            )
          )
        }

      case let .imageLoaded(id, result):
        state.loadedImages[id] = result
        return .none
      }
    }
  }
}
```

### 4. Batch Updates

Batch multiple updates together:

```swift
@Reducer
struct TodoListFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var todos: [Todo] = []
    var isSaving = false
  }

  enum Action: Equatable, Sendable {
    case toggleAllButtonTapped
    case deleteCompletedButtonTapped
    case todosUpdated([Todo])
    case saveCompleted
  }

  @Dependency(\.todoClient) var todoClient

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .toggleAllButtonTapped:
        let allCompleted = state.todos.allSatisfy(\.isCompleted)
        state.todos = state.todos.map { todo in
          var todo = todo
          todo.isCompleted = !allCompleted
          return todo
        }

        state.isSaving = true

        return .run { [todos = state.todos] send in
          try await todoClient.saveTodos(todos)
          await send(.saveCompleted)
        }

      case .deleteCompletedButtonTapped:
        state.todos = state.todos.filter { !$0.isCompleted }

        state.isSaving = true

        return .run { [todos = state.todos] send in
          try await todoClient.saveTodos(todos)
          await send(.saveCompleted)
        }

      case let .todosUpdated(todos):
        state.todos = todos
        return .none

      case .saveCompleted:
        state.isSaving = false
        return .none
      }
    }
  }
}
```

### 5. Memoization

Implement memoization for expensive computations:

```swift
@Reducer
struct FeatureWithMemoization {
  @ObservableState
  struct State: Equatable, Sendable {
    var input = ""
    var cachedResults: [String: String] = [:]
    var result: String?
    var isComputing = false
  }

  enum Action: Equatable, Sendable {
    case inputChanged(String)
    case computeButtonTapped
    case resultComputed(String)
  }

  @Dependency(\.expensiveComputation) var expensiveComputation

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .inputChanged(input):
        state.input = input
        return .none

      case .computeButtonTapped:
        // Check cache first
        if let cachedResult = state.cachedResults[state.input] {
          state.result = cachedResult
          return .none
        }

        state.isComputing = true

        return .run { [input = state.input] send in
          let result = try await expensiveComputation(input)
          await send(.resultComputed(result))
        }

      case let .resultComputed(result):
        state.result = result
        state.cachedResults[state.input] = result
        state.isComputing = false
        return .none
      }
    }
  }
}
```

### 6. Background Processing

Perform expensive operations in the background:

```swift
@Reducer
struct BackgroundProcessingFeature {
  @ObservableState
  struct State: Equatable, Sendable {
    var data: Data?
    var processedData: ProcessedData?
    var isProcessing = false
  }

  enum Action: Equatable, Sendable {
    case dataLoaded(Data)
    case processButtonTapped
    case processingCompleted(ProcessedData)
  }

  @Dependency(\.backgroundQueue) var backgroundQueue

  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case let .dataLoaded(data):
        state.data = data
        return .none

      case .processButtonTapped:
        guard let data = state.data else { return .none }

        state.isProcessing = true

        return .run { send in
          let processedData = await backgroundQueue.schedule {
            processData(data)
          }

          await send(.processingCompleted(processedData))
        }

      case let .processingCompleted(processedData):
        state.processedData = processedData
        state.isProcessing = false
        return .none
      }
    }
  }

  private func processData(_ data: Data) -> ProcessedData {
    // Expensive processing logic
    return ProcessedData()
  }
}
```

## SwiftUI Optimization

### 1. View Modifiers

Use custom view modifiers for cross-cutting concerns:

```swift
extension View {
  func analyticsScreen(_ name: String) -> some View {
    self.modifier(AnalyticsScreenModifier(name: name))
  }
}

struct AnalyticsScreenModifier: ViewModifier {
  let name: String

  @Dependency(\.analytics) var analytics

  func body(content: Content) -> some View {
    content
      .onAppear {
        analytics.trackScreen(name)
      }
  }
}
```

### 2. Lazy Views

Use lazy views for expensive content:

```swift
struct LazyLoadingView: View {
  @Bindable var store: StoreOf<GalleryFeature>

  var body: some View {
    ScrollView {
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
        ForEach(store.photos) { photo in
          PhotoView(
            store: store,
            photo: photo
          )
        }
      }
    }
  }
}

struct PhotoView: View {
  @Bindable var store: StoreOf<GalleryFeature>
  let photo: Photo

  var body: some View {
    ZStack {
      Rectangle()
        .fill(Color.gray.opacity(0.2))

      Group {
        switch store.loadedImages[photo.id] {
        case .none:
          Color.clear
            .onAppear {
              store.send(.loadImage(photo.id))
            }
        case .loading:
          ProgressView()
        case let .success(image):
          Image(uiImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
        case .failure:
          Image(systemName: "exclamationmark.triangle")
        }
      }
    }
    .aspectRatio(1, contentMode: .fit)
    .clipped()
  }
}
```

### 3. Equatable Conformance

Ensure all state types conform to `Equatable`:

```swift
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var user: User?
  var items: [Item] = []

  // Custom Equatable implementation for types that don't conform to Equatable
  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.count == rhs.count &&
    lhs.user == rhs.user &&
    lhs.items == rhs.items
  }
}
```

### 4. View Composition

Break down complex views into smaller components:

```swift
// ❌ Monolithic view
struct ComplexView: View {
  @Bindable var store: StoreOf<ComplexFeature>

  var body: some View {
    VStack {
      // Header
      HStack {
        Text("Title")
        Spacer()
        Button("Settings") { store.send(.settingsButtonTapped) }
      }

      // Content
      List {
        ForEach(store.items) { item in
          HStack {
            Text(item.name)
            Spacer()
            Text(item.description)
          }
        }
      }

      // Footer
      HStack {
        Button("Add") { store.send(.addButtonTapped) }
        Spacer()
        Button("Refresh") { store.send(.refreshButtonTapped) }
      }
    }
  }
}

// ✅ Composed view
struct ComplexView: View {
  @Bindable var store: StoreOf<ComplexFeature>

  var body: some View {
    VStack {
      HeaderView(store: store)
      ContentView(store: store)
      FooterView(store: store)
    }
  }
}

struct HeaderView: View {
  @Bindable var store: StoreOf<ComplexFeature>

  var body: some View {
    HStack {
      Text("Title")
      Spacer()
      Button("Settings") { store.send(.settingsButtonTapped) }
    }
  }
}

struct ContentView: View {
  @Bindable var store: StoreOf<ComplexFeature>

  var body: some View {
    List {
      ForEach(store.items) { item in
        ItemRow(item: item)
      }
    }
  }
}

struct ItemRow: View {
  let item: Item

  var body: some View {
    HStack {
      Text(item.name)
      Spacer()
      Text(item.description)
    }
  }
}

struct FooterView: View {
  @Bindable var store: StoreOf<ComplexFeature>

  var body: some View {
    HStack {
      Button("Add") { store.send(.addButtonTapped) }
      Spacer()
      Button("Refresh") { store.send(.refreshButtonTapped) }
    }
  }
}
```

## Best Practices

### 1. Profile Before Optimizing

Profile your application before optimizing:

- Use Instruments to identify performance bottlenecks
- Use Time Profiler to identify CPU-intensive code
- Use Allocations to identify memory issues
- Use Core Animation to identify rendering issues

### 2. Optimize State Updates

Minimize unnecessary state updates:

```swift
// ❌ Unnecessary state updates
case .incrementButtonTapped:
  state.count += 1
  state.lastUpdated = Date()  // Updates on every increment
  state.isCountPositive = state.count > 0  // Computed property would be better
  return .none

// ✅ Minimal state updates
case .incrementButtonTapped:
  state.count += 1
  return .none
```

### 3. Use Computed Properties

Use computed properties for derived state:

```swift
// ❌ Stored properties for derived state
@ObservableState
struct State: Equatable, Sendable {
  var count = 0
  var isCountPositive = false
  var isCountEven = true

  mutating func updateDerivedState() {
    isCountPositive = count > 0
    isCountEven = count % 2 == 0
  }
}

// ✅ Computed properties for derived state
@ObservableState
struct State: Equatable, Sendable {
  var count = 0

  var isCountPositive: Bool {
    count > 0
  }

  var isCountEven: Bool {
    count % 2 == 0
  }
}
```

### 4. Batch State Updates

Batch multiple state updates together:

```swift
// ❌ Multiple separate updates
case .resetButtonTapped:
  state.count = 0
  state.name = ""
  state.isEnabled = false
  state.items = []
  return .none

// ✅ Batched update
case .resetButtonTapped:
  state = State()  // Reset to initial state
  return .none
```

### 5. Cancel Unnecessary Effects

Cancel unnecessary effects:

```swift
// ❌ No cancellation
case .searchQueryChanged(let query):
  state.query = query

  return .run { send in
    let results = try await searchClient.search(query)
    await send(.searchResultsLoaded(results))
  }

// ✅ With cancellation
case .searchQueryChanged(let query):
  state.query = query

  return .run { send in
    let results = try await searchClient.search(query)
    await send(.searchResultsLoaded(results))
  }
  .cancellable(id: SearchCancelID.self)
```

### 6. Use Appropriate Data Structures

Use appropriate data structures for your use case:

```swift
// ❌ Inefficient data structure for lookups
@ObservableState
struct State: Equatable, Sendable {
  var items: [Item] = []

  func findItem(id: String) -> Item? {
    items.first { $0.id == id }  // O(n) lookup
  }
}

// ✅ Efficient data structure for lookups
@ObservableState
struct State: Equatable, Sendable {
  var itemsById: [String: Item] = [:]

  var items: [Item] {
    Array(itemsById.values)
  }

  func findItem(id: String) -> Item? {
    itemsById[id]  // O(1) lookup
  }
}
```

### 7. Avoid Unnecessary Recomputation

Cache expensive computations:

```swift
// ❌ Recomputing on every access
var filteredItems: [Item] {
  items.filter { $0.isActive }
}

// ✅ Caching computation
private var _filteredItems: [Item]?
private var _lastItemsForFiltering: [Item]?

var filteredItems: [Item] {
  if _lastItemsForFiltering != items {
    _lastItemsForFiltering = items
    _filteredItems = items.filter { $0.isActive }
  }
  return _filteredItems ?? []
}
```

## Conclusion

Performance optimization in modern TCA requires a thoughtful approach to state management, effect execution, and view rendering. By following the principles and best practices outlined in this document, you can create TCA applications that are responsive, efficient, and provide a great user experience.

Modern TCA provides several powerful tools for performance optimization, including:

1. **@ObservableState**: Efficient state updates with fine-grained SwiftUI view updates
2. **onChange**: Selective effect execution based on state changes
3. **@Shared**: Efficient state sharing across features
4. **TaskResult**: Caching and error handling for expensive computations
5. **Task.yield()**: Cooperative multitasking for CPU-intensive work

By leveraging these tools and following the best practices outlined in this document, you can create TCA applications that are both powerful and performant.
