# Effect Management

**Navigation:** [Back to iOS Architecture](../README.md) | [Feature Architecture](./FeatureArchitecture.md) | [State Management](./StateManagement.md) | [Action Design](./ActionDesign.md)

---

> **Note:** As this is an MVP, the effect management approach may evolve as the project matures.

## Effect Design Principles

Effects in LifeSignal follow these core principles:

1. **Structured Concurrency**: Effects use Swift's structured concurrency (async/await)
2. **Cancellation**: Effects are cancellable when appropriate
3. **Error Handling**: Effects handle errors within the effect
4. **Dependency Injection**: Effects use dependencies injected via TCA's dependency system
5. **Testability**: Effects are designed to be testable

## Effect Types

TCA provides several types of effects:

### 1. None Effect

For synchronous state updates with no side effects:

```swift
case .incrementButtonTapped:
  state.count += 1
  return .none
```

### 2. Run Effect

For asynchronous operations:

```swift
case .numberFactButtonTapped:
  return .run { [count = state.count] send in
    do {
      let fact = try await numberFactClient.fetch(count)
      await send(.numberFactResponse(fact))
    } catch {
      await send(.numberFactFailed(error))
    }
  }
```

### 3. Cancellable Effect

For effects that need to be cancelled:

```swift
case .startTimerButtonTapped:
  return .run { send in
    while true {
      try await clock.sleep(for: .seconds(1))
      await send(.timerTick)
    }
  }
  .cancellable(id: CancelID.timer)

case .stopTimerButtonTapped:
  return .cancel(id: CancelID.timer)
```

### 4. Merge Effect

For combining multiple effects:

```swift
case .refreshButtonTapped:
  state.isLoading = true
  return .merge(
    .run { send in
      await send(.loadUser)
    },
    .run { send in
      await send(.loadItems)
    }
  )
```

### 5. Concatenate Effect

For sequencing effects:

```swift
case .saveButtonTapped:
  return .concatenate(
    .run { send in
      await send(.validateForm)
    },
    .run { send in
      await send(.saveForm)
    }
  )
```

## Effect Cancellation

Effects are cancelled using cancellation IDs:

```swift
enum CancelID {
  case timer
  case userStream
  case itemsStream
}

case .startTimerButtonTapped:
  return .run { send in
    while true {
      try await clock.sleep(for: .seconds(1))
      await send(.timerTick)
    }
  }
  .cancellable(id: CancelID.timer)

case .stopTimerButtonTapped:
  return .cancel(id: CancelID.timer)
```

## Effect Dependencies

Effects use dependencies injected via TCA's dependency system:

```swift
@Reducer
struct Feature {
  @Dependency(\.numberFactClient) var numberFactClient
  @Dependency(\.continuousClock) var clock
  
  // State, Action, etc.
  
  var body: some ReducerOf<Self> {
    Reduce { state, action in
      switch action {
      case .numberFactButtonTapped:
        return .run { [count = state.count] send in
          do {
            let fact = try await numberFactClient.fetch(count)
            await send(.numberFactResponse(fact))
          } catch {
            await send(.numberFactFailed(error))
          }
        }
        
      case .startTimerButtonTapped:
        return .run { send in
          while true {
            try await clock.sleep(for: .seconds(1))
            await send(.timerTick)
          }
        }
        .cancellable(id: CancelID.timer)
        
      // Other cases...
      }
    }
  }
}
```

## Error Handling in Effects

Errors are handled within effects:

```swift
case .numberFactButtonTapped:
  return .run { [count = state.count] send in
    do {
      let fact = try await numberFactClient.fetch(count)
      await send(.numberFactResponse(fact))
    } catch {
      await send(.numberFactFailed(error))
    }
  }

case .numberFactResponse(let fact):
  state.numberFact = fact
  state.isLoading = false
  return .none

case .numberFactFailed(let error):
  state.error = error
  state.isLoading = false
  return .none
```

## CPU-Intensive Work in Effects

CPU-intensive work is handled with `Task.yield()`:

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

## Firebase Streaming in Effects

Firebase data is streamed using effects:

```swift
case .appDidLaunch:
  return .run { send in
    for await user in await authClient.authStateStream() {
      await send(.authStateChanged(user))
    }
  }
  .cancellable(id: CancelID.authStateStream)

case .authStateChanged(let user):
  state.user = user
  
  if let user = user {
    return .run { send in
      for await userData in await userClient.observeUser(user.id) {
        await send(.userDataChanged(userData))
      }
    }
    .cancellable(id: CancelID.userDataStream)
  } else {
    return .cancel(id: CancelID.userDataStream)
  }
```

## Multiple Asynchronous Operations

Multiple asynchronous operations are handled within a single effect:

```swift
case .refreshButtonTapped:
  state.isLoading = true
  return .run { send in
    do {
      let user = try await userClient.getCurrentUser()
      let items = try await itemsClient.getItems(user.id)
      await send(.refreshResponse(user: user, items: items))
    } catch {
      await send(.refreshFailed(error))
    }
  }
```

## Debouncing Effects

Effects are debounced using the clock dependency:

```swift
case .searchTextChanged(let text):
  state.searchText = text
  return .run { send in
    try await clock.sleep(for: .milliseconds(300))
    await send(.searchDebounced(text))
  }
  .cancellable(id: CancelID.search)

case .searchDebounced(let text):
  return .run { send in
    do {
      let results = try await searchClient.search(text)
      await send(.searchResponse(results))
    } catch {
      await send(.searchFailed(error))
    }
  }
```

## Throttling Effects

Effects are throttled using the clock dependency:

```swift
case .scrollPositionChanged(let position):
  state.scrollPosition = position
  
  if !state.isThrottling {
    state.isThrottling = true
    return .run { send in
      try await clock.sleep(for: .milliseconds(100))
      await send(.scrollThrottled(position))
    }
  }
  
  return .none

case .scrollThrottled(let position):
  state.isThrottling = false
  return .run { send in
    await analyticsClient.logScrollPosition(position)
  }
```

## Best Practices

1. **Use Structured Concurrency**: Use async/await for all asynchronous operations
2. **Handle Errors**: Handle errors within effects
3. **Use Cancellation IDs**: Use cancellation IDs for long-running or repeating effects
4. **Use Dependencies**: Use dependencies injected via TCA's dependency system
5. **Yield for CPU-Intensive Work**: Use `Task.yield()` for CPU-intensive work
6. **Return .none for Synchronous Updates**: Return `.none` for synchronous state updates with no side effects
7. **Combine Effects with .merge**: Use `.merge` to combine multiple effects
8. **Sequence Effects with .concatenate**: Use `.concatenate` to sequence effects
9. **Test Effects**: Test effects using `TestStore`
10. **Document Effects**: Document the purpose of each effect
