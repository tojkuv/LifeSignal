# Performance Considerations

**Navigation:** [Back to iOS Architecture](README.md) | [TCA Implementation](TCAImplementation.md) | [Modern TCA Architecture](ComposableArchitecture.md) | [Core Principles](CorePrinciples.md)

---

> **Note:** As this is an MVP, the performance optimization strategies may evolve as the project matures.

## State Management Optimization

### Selective Effect Execution

Use the `onChange` reducer operator to only execute effects when specific state changes:

```swift
Reduce { state, action in
    // Reducer implementation
}
.onChange(of: \.user) { oldValue, newValue in
    // This effect only runs when the user state changes
    return .run { send in
        await send(.userChanged(newValue))
    }
}
```

### TaskResult Caching

Cache expensive computations using `TaskResult`:

```swift
@Dependency(\.userClient) var userClient

var cachedUserResult: TaskResult<User>?

// In the reducer
case .loadUser:
    if let cachedResult = cachedUserResult {
        return .send(.userLoaded(cachedResult))
    }

    return .run { send in
        let result = await TaskResult { try await userClient.getCurrentUser() }
        cachedUserResult = result
        await send(.userLoaded(result))
    }
```

### Shared State Management

Use `@Shared` with appropriate persistence strategy for shared state:

```swift
@ObservableState
struct AppState: Equatable, Sendable {
    @Shared(.inMemory) var session: SessionState
    @Shared(.userDefaults(key: "user_preferences")) var preferences: PreferencesState
}
```

### Minimize State Updates

Avoid frequent updates to state properties that trigger UI updates:

```swift
// Instead of updating a timestamp every second
case .timerTick:
    state.currentTime = Date()  // Triggers UI update
    return .none

// Consider using a computed property in the view
var formattedTime: String {
    let formatter = DateFormatter()
    formatter.timeStyle = .medium
    return formatter.string(from: Date())
}
```

### Use Derived State

Use computed properties for derived state to avoid redundant storage:

```swift
@ObservableState
struct ContactsState: Equatable, Sendable {
    var contacts: [Contact] = []

    var favoriteContacts: [Contact] {
        contacts.filter { $0.isFavorite }
    }

    var nonResponsiveContacts: [Contact] {
        contacts.filter { $0.isNonResponsive }
    }
}
```

## Effect Optimization

### Cancel Long-Running Effects

Always cancel long-running effects when they're no longer needed:

```swift
case .startObserving:
    return .run { send in
        for await user in userClient.observeCurrentUser() {
            await send(.userUpdated(user))
        }
    }
    .cancellable(id: UserObservationID.self)

case .stopObserving:
    return .cancel(id: UserObservationID.self)
```

### Use Debouncing for User Input

Debounce frequent user inputs to reduce unnecessary processing:

```swift
case let .searchQueryChanged(query):
    state.searchQuery = query

    // Cancel any previous search
    return .run { send in
        try await clock.sleep(for: .milliseconds(300))
        await send(.executeSearch(query))
    }
    .cancellable(id: SearchDebounceID.self)
```

### Use Throttling for High-Frequency Events

Throttle high-frequency events to reduce processing load:

```swift
case .locationUpdated(let location):
    // Only process location updates every 5 seconds
    return .run { send in
        try await clock.sleep(for: .seconds(5))
        await send(.processLocationUpdate(location))
    }
    .cancellable(id: LocationThrottleID.self)
```

### Yield During CPU-Intensive Work

Use `Task.yield()` periodically during CPU-intensive work:

```swift
return .run { send in
    var results: [ProcessedItem] = []

    for (index, item) in items.enumerated() {
        let processedItem = processItem(item)
        results.append(processedItem)

        // Yield every 10 items to avoid blocking the main thread
        if index % 10 == 0 {
            await Task.yield()
        }
    }

    await send(.processingComplete(results))
}
```

### Use Proper Task Priorities

Set appropriate task priorities for different types of work:

```swift
return .run { send in
    await Task.detached(priority: .userInitiated) {
        // High-priority work that affects the UI
        let result = try await userClient.getCurrentUser()
        await send(.userLoaded(result))
    }
}

return .run { send in
    await Task.detached(priority: .background) {
        // Lower-priority work that can happen in the background
        let result = try await analyticsClient.uploadEvents()
        await send(.eventsUploaded(result))
    }
}
```

## UI Performance

### Use `._printChanges()` During Development

Identify unnecessary state updates with `._printChanges()`:

```swift
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack {
                // View content
            }
            ._printChanges()  // Prints when the view is redrawn
        }
    }
}
```

### Use Lazy Loading for Expensive Views

Defer the creation of expensive views until they're needed:

```swift
ScrollView {
    LazyVStack {
        ForEach(viewStore.contacts) { contact in
            ContactRow(contact: contact)
                .onAppear {
                    store.send(.contactAppeared(contact.id))
                }
        }
    }
}
```

### Use View Modifiers Instead of Conditional Views

Prefer view modifiers over conditional views to reduce view identity changes:

```swift
// Instead of this
if viewStore.isLoading {
    ProgressView()
} else {
    ContentView()
}

// Do this
ContentView()
    .opacity(viewStore.isLoading ? 0 : 1)
    .overlay {
        if viewStore.isLoading {
            ProgressView()
        }
    }
```

### Use `@ViewBuilder` for Complex View Hierarchies

Use `@ViewBuilder` to create reusable view components:

```swift
@ViewBuilder
func contactSection(title: String, contacts: [Contact]) -> some View {
    Section(title) {
        ForEach(contacts) { contact in
            ContactRow(contact: contact)
        }
    }
}
```

### Use `LazyVStack` and `LazyHStack` for Large Collections

Use lazy stacks for large collections to improve performance:

```swift
ScrollView {
    LazyVStack(spacing: 8) {
        ForEach(viewStore.contacts) { contact in
            ContactRow(contact: contact)
        }
    }
}
```

## Network Optimization

### Use Pagination for Large Data Sets

Implement pagination for large data sets:

```swift
@ObservableState
struct ContactsState: Equatable, Sendable {
    var contacts: [Contact] = []
    var isLoading: Bool = false
    var nextPageToken: String? = nil
    var hasMorePages: Bool = true
}

case .loadMoreContacts:
    guard state.hasMorePages && !state.isLoading else { return .none }
    state.isLoading = true

    return .run { [nextPageToken = state.nextPageToken] send in
        let result = await TaskResult {
            try await contactsClient.getContacts(pageToken: nextPageToken, pageSize: 20)
        }
        await send(.contactsLoaded(result))
    }

case let .contactsLoaded(.success(response)):
    state.isLoading = false
    state.contacts.append(contentsOf: response.contacts)
    state.nextPageToken = response.nextPageToken
    state.hasMorePages = response.nextPageToken != nil
    return .none
```

### Use Caching for Frequently Accessed Data

Implement caching for frequently accessed data:

```swift
@Dependency(\.cacheClient) var cacheClient

case .loadUser(let userId):
    // Check cache first
    if let cachedUser = cacheClient.getUser(userId) {
        return .send(.userLoaded(.success(cachedUser)))
    }

    // Load from network if not in cache
    return .run { send in
        let result = await TaskResult { try await userClient.getUser(userId) }

        // Cache successful results
        if case let .success(user) = result {
            cacheClient.setUser(user)
        }

        await send(.userLoaded(result))
    }
```

### Use Batch Operations

Use batch operations for multiple updates:

```swift
case .updateMultipleContacts(let contacts):
    return .run { send in
        let result = await TaskResult { try await contactsClient.batchUpdate(contacts) }
        await send(.contactsUpdated(result))
    }
```

### Implement Proper Retry Logic

Implement retry logic for transient failures:

```swift
func retryWithBackoff<T>(
    maxAttempts: Int = 3,
    operation: @escaping () async throws -> T
) async throws -> T {
    var attempts = 0
    var lastError: Error?

    while attempts < maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            attempts += 1

            if attempts < maxAttempts {
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempts)) * 100_000_000))
            }
        }
    }

    throw lastError!
}

case .loadData:
    return .run { send in
        do {
            let data = try await retryWithBackoff {
                try await dataClient.loadData()
            }
            await send(.dataLoaded(.success(data)))
        } catch {
            await send(.dataLoaded(.failure(error)))
        }
    }
```

## Memory Management

### Use Value Types

Prefer value types (`struct`) over reference types (`class`) to avoid reference cycles:

```swift
struct User: Equatable, Sendable {
    let id: String
    var name: String
    var email: String?
    // Other properties
}
```

### Avoid Capturing Self in Closures

Be careful about capturing `self` in closures, especially in long-lived tasks:

```swift
// Instead of this
return .run { send in
    for await user in self.userClient.observeCurrentUser() {
        await send(.userUpdated(user))
    }
}

// Do this
return .run { [userClient] send in
    for await user in userClient.observeCurrentUser() {
        await send(.userUpdated(user))
    }
}
```

### Clean Up Resources

Ensure proper cleanup of resources:

```swift
case .onAppear:
    return .run { send in
        await send(.startObserving)

        return .task {
            await send(.stopObserving)
        }
    }
```

### Use Weak References for Delegates

Use weak references for delegates to avoid reference cycles:

```swift
protocol ContactsDelegate: AnyObject {
    func contactsUpdated(_ contacts: [Contact])
}

class ContactsManager {
    weak var delegate: ContactsDelegate?

    func loadContacts() {
        // Load contacts
        delegate?.contactsUpdated(contacts)
    }
}
```
