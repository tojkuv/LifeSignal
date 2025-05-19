# Effect Management in TCA

**Navigation:** [Back to TCA Overview](Overview.md) | [State Management](StateManagement.md) | [Action Design](ActionDesign.md) | [Dependency Injection](DependencyInjection.md)

---

## Overview

Effects in The Composable Architecture (TCA) represent side effects that interact with the outside world, such as network requests, database operations, and other asynchronous operations. Effects are returned from reducers and are executed by the TCA runtime.

## Core Principles

### 1. Pure Effects

Effects should be pure functions that don't mutate state directly:

```swift
@Reducer
struct Feature {
  @ObservableState
  struct State: Equatable, Sendable { /* ... */ }
  
  enum Action: Equatable, Sendable { /* ... */ }
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .incrementButtonTapped:
        state.count += 1
        return .none
        
      case .loadDataButtonTapped:
        state.isLoading = true
        return .run { send in
          do {
            let data = try await dataClient.loadData()
            await send(.dataLoaded(data))
          } catch {
            await send(.dataLoadFailed(error))
          }
        }
        
      case let .dataLoaded(data):
        state.isLoading = false
        state.data = data
        return .none
        
      case let .dataLoadFailed(error):
        state.isLoading = false
        state.error = error
        return .none
      }
    }
  }
}
```

This ensures:
- Clear separation between state mutations and side effects
- Predictable state changes
- Testable effects

### 2. Structured Concurrency

Effects use structured concurrency for all asynchronous code:

```swift
return .run { send in
  do {
    let data = try await dataClient.loadData()
    await send(.dataLoaded(data))
  } catch {
    await send(.dataLoadFailed(error))
  }
}
```

This ensures:
- Proper cancellation of asynchronous operations
- Clear error handling
- Compatibility with Swift's concurrency system

### 3. Cancellation

Effects should be cancellable when appropriate:

```swift
case .searchQueryChanged(let query):
  state.searchQuery = query
  return .run { send in
    try await Task.sleep(for: .milliseconds(300))
    let results = try await searchClient.search(query)
    await send(.searchResultsLoaded(results))
  }
  .cancellable(id: SearchCancelID.self)
```

This ensures:
- Effects can be cancelled when no longer needed
- Resources are properly cleaned up
- Race conditions are avoided

## Effect Types

### .none

`.none` represents no effect:

```swift
case .incrementButtonTapped:
  state.count += 1
  return .none
```

Use `.none` for:
- Synchronous state updates with no side effects
- Actions that don't require any asynchronous operations

### .run

`.run` executes an asynchronous operation:

```swift
case .loadDataButtonTapped:
  state.isLoading = true
  return .run { send in
    do {
      let data = try await dataClient.loadData()
      await send(.dataLoaded(data))
    } catch {
      await send(.dataLoadFailed(error))
    }
  }
```

Use `.run` for:
- Network requests
- Database operations
- File I/O
- Other asynchronous operations

### .merge

`.merge` combines multiple effects:

```swift
case .appDidLaunch:
  return .merge(
    .run { send in
      for await user in await authClient.authStateStream() {
        await send(.authStateChanged(user))
      }
    },
    .run { send in
      for await notification in await notificationClient.notificationStream() {
        await send(.notificationReceived(notification))
      }
    }
  )
```

Use `.merge` for:
- Running multiple effects in parallel
- Combining related effects
- Initializing multiple streams

### .concatenate

`.concatenate` runs effects in sequence:

```swift
case .saveAndSyncButtonTapped:
  return .concatenate(
    .run { send in
      try await dataClient.saveData(state.data)
      await send(.dataSaved)
    },
    .run { send in
      try await syncClient.syncData()
      await send(.dataSynced)
    }
  )
```

Use `.concatenate` for:
- Running effects in a specific order
- Chaining dependent effects
- Sequential operations

## Effect Patterns

### 1. Capturing State

Capture only the necessary state in effects:

```swift
// ❌ Capturing entire state
return .run { [state] send in
  try await Task.sleep(for: .seconds(1))
  await send(.delayed(state.count))
}

// ✅ Capturing only what's needed
return .run { [count = state.count] send in
  try await Task.sleep(for: .seconds(1))
  await send(.delayed(count))
}
```

This ensures:
- Minimal memory usage
- Clear dependencies
- Thread safety

### 2. Error Handling

Handle errors within effects:

```swift
return .run { send in
  do {
    let data = try await dataClient.loadData()
    await send(.dataLoaded(data))
  } catch let error as NetworkError {
    await send(.networkError(error))
  } catch let error as DecodingError {
    await send(.decodingError(error))
  } catch {
    await send(.unknownError(error))
  }
}
```

This ensures:
- Specific error handling
- User-friendly error messages
- Appropriate error recovery

### 3. Cancellation IDs

Use cancellation IDs for long-running or repeating effects:

```swift
enum TimerCancelID {}

case .startTimerButtonTapped:
  return .run { send in
    for _ in 1...10 {
      try await Task.sleep(for: .seconds(1))
      await send(.timerTick)
    }
  }
  .cancellable(id: TimerCancelID.self)

case .stopTimerButtonTapped:
  return .cancel(id: TimerCancelID.self)
```

This ensures:
- Effects can be cancelled when no longer needed
- Resources are properly cleaned up
- Race conditions are avoided

### 4. Debouncing

Debounce rapidly changing inputs:

```swift
case .searchQueryChanged(let query):
  state.searchQuery = query
  return .run { send in
    try await Task.sleep(for: .milliseconds(300))
    let results = try await searchClient.search(query)
    await send(.searchResultsLoaded(results))
  }
  .cancellable(id: SearchCancelID.self)
```

This ensures:
- Reduced network traffic
- Improved performance
- Better user experience

### 5. Throttling

Throttle high-frequency events:

```swift
case .scrollPositionChanged(let position):
  state.scrollPosition = position
  return .run { send in
    try await Task.sleep(for: .milliseconds(100))
    await send(.saveScrollPosition(position))
  }
  .cancellable(id: ScrollCancelID.self)
```

This ensures:
- Reduced processing load
- Improved performance
- Better user experience

### 6. Long-Running Streams

Handle long-running streams:

```swift
case .appDidLaunch:
  return .run { send in
    for await user in await authClient.authStateStream() {
      await send(.authStateChanged(user))
    }
  }
  .cancellable(id: AuthStreamCancelID.self)

case .appWillTerminate:
  return .cancel(id: AuthStreamCancelID.self)
```

This ensures:
- Proper resource management
- Clean shutdown
- No memory leaks

### 7. Task Yielding

Yield during CPU-intensive work:

```swift
case .processDataButtonTapped:
  return .run { send in
    var results: [ProcessedData] = []
    for item in state.data {
      let processed = await processItem(item)
      results.append(processed)
      
      if results.count % 100 == 0 {
        await Task.yield()
      }
    }
    await send(.dataProcessed(results))
  }
```

This ensures:
- Responsive UI during heavy processing
- Fair CPU time sharing
- Better user experience

## Advanced Effect Patterns

### 1. Combining Multiple Asynchronous Operations

Combine multiple asynchronous operations in a single effect:

```swift
case .refreshButtonTapped:
  state.isLoading = true
  return .run { send in
    async let userData = userClient.fetchCurrentUser()
    async let postsData = postClient.fetchPosts()
    async let notificationsData = notificationClient.fetchNotifications()
    
    do {
      let (user, posts, notifications) = try await (userData, postsData, notificationsData)
      await send(.dataRefreshed(user: user, posts: posts, notifications: notifications))
    } catch {
      await send(.refreshFailed(error))
    }
  }
```

This ensures:
- Parallel execution of independent operations
- Single success/failure handling
- Improved performance

### 2. Progressive Loading

Implement progressive loading for better user experience:

```swift
case .loadLargeDataButtonTapped:
  state.isLoading = true
  return .run { send in
    let stream = dataClient.loadLargeDataStream()
    
    var accumulatedData: [Data] = []
    for await chunk in stream {
      accumulatedData.append(chunk)
      await send(.dataChunkLoaded(accumulatedData))
    }
    
    await send(.dataFullyLoaded(accumulatedData))
  }
```

This ensures:
- Immediate feedback to users
- Progressive UI updates
- Better user experience

### 3. Retry Logic

Implement retry logic for transient failures:

```swift
case .loadDataWithRetryButtonTapped:
  state.isLoading = true
  return .run { send in
    var retryCount = 0
    let maxRetries = 3
    
    while true {
      do {
        let data = try await dataClient.loadData()
        await send(.dataLoaded(data))
        break
      } catch {
        retryCount += 1
        if retryCount >= maxRetries {
          await send(.dataLoadFailed(error))
          break
        }
        
        // Exponential backoff
        try await Task.sleep(for: .seconds(pow(2.0, Double(retryCount))))
      }
    }
  }
```

This ensures:
- Resilience to transient failures
- Exponential backoff to avoid overwhelming servers
- Better user experience

### 4. Cancellation with Cleanup

Implement cancellation with cleanup:

```swift
case .startUploadButtonTapped:
  let uploadID = UUID()
  state.currentUploadID = uploadID
  
  return .run { send in
    defer {
      // Cleanup code that runs even if cancelled
      cleanupTemporaryFiles()
    }
    
    do {
      let result = try await uploadClient.upload(state.fileData)
      await send(.uploadCompleted(result))
    } catch is CancellationError {
      await send(.uploadCancelled)
    } catch {
      await send(.uploadFailed(error))
    }
  }
  .cancellable(id: UploadCancelID.self)

case .cancelUploadButtonTapped:
  return .cancel(id: UploadCancelID.self)
```

This ensures:
- Proper resource cleanup
- Handling of cancellation
- No resource leaks

## Best Practices

### 1. Keep Effects Focused

Each effect should have a single responsibility:

```swift
// ❌ Too many responsibilities
return .run { send in
  do {
    let user = try await authClient.login(username, password)
    let preferences = try await preferencesClient.loadPreferences(user.id)
    let notifications = try await notificationClient.loadNotifications(user.id)
    await send(.loginCompleted(user, preferences, notifications))
  } catch {
    await send(.loginFailed(error))
  }
}

// ✅ Focused
return .run { send in
  do {
    let user = try await authClient.login(username, password)
    await send(.loginCompleted(user))
  } catch {
    await send(.loginFailed(error))
  }
}
```

### 2. Use Structured Concurrency

Use structured concurrency for all asynchronous code:

```swift
// ❌ Unstructured concurrency
return .run { send in
  Task {
    do {
      let data = try await dataClient.loadData()
      await send(.dataLoaded(data))
    } catch {
      await send(.dataLoadFailed(error))
    }
  }
}

// ✅ Structured concurrency
return .run { send in
  do {
    let data = try await dataClient.loadData()
    await send(.dataLoaded(data))
  } catch {
    await send(.dataLoadFailed(error))
  }
}
```

### 3. Handle Errors Appropriately

Handle errors at the appropriate level:

```swift
// ❌ Generic error handling
return .run { send in
  do {
    let data = try await dataClient.loadData()
    await send(.dataLoaded(data))
  } catch {
    await send(.dataLoadFailed(error))
  }
}

// ✅ Specific error handling
return .run { send in
  do {
    let data = try await dataClient.loadData()
    await send(.dataLoaded(data))
  } catch let error as NetworkError {
    await send(.networkError(error))
  } catch let error as DecodingError {
    await send(.decodingError(error))
  } catch {
    await send(.unknownError(error))
  }
}
```

### 4. Use Cancellation IDs

Always specify cancellation IDs for long-running or repeating effects:

```swift
// ❌ No cancellation ID
return .run { send in
  for _ in 1...10 {
    try await Task.sleep(for: .seconds(1))
    await send(.timerTick)
  }
}

// ✅ With cancellation ID
return .run { send in
  for _ in 1...10 {
    try await Task.sleep(for: .seconds(1))
    await send(.timerTick)
  }
}
.cancellable(id: TimerCancelID.self)
```

### 5. Avoid Capturing Self

Avoid capturing `self` in effects:

```swift
// ❌ Capturing self
return .run { [self] send in
  let data = try await self.loadData()
  await send(.dataLoaded(data))
}

// ✅ Using dependencies
return .run { send in
  let data = try await dataClient.loadData()
  await send(.dataLoaded(data))
}
```

### 6. Test Both Success and Failure Paths

Test both success and failure paths for all effects:

```swift
// Testing success path
await store.send(.loadDataButtonTapped) {
  $0.isLoading = true
}
await store.receive(.dataLoaded(testData)) {
  $0.isLoading = false
  $0.data = testData
}

// Testing failure path
await store.send(.loadDataButtonTapped) {
  $0.isLoading = true
}
await store.receive(.dataLoadFailed(testError)) {
  $0.isLoading = false
  $0.error = testError
}
```

## Conclusion

Effect management in TCA provides a powerful way to handle side effects in a predictable and testable manner. By following the principles and best practices outlined in this document, you can create effects that are easy to understand, modify, and test.
