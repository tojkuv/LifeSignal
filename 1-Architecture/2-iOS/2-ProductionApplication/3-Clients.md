# Production Application Clients

## Purpose

This document outlines the client architecture for the iOS Production Application using The Composable Architecture (TCA) and the @DependencyClient pattern from the swift-dependencies package. The architecture follows a layered approach with abstract clients that features use and platform-specific clients that abstract clients use.

## Core Principles

### Type Safety

- Define strongly typed client interfaces using @DependencyClient
- Implement type-safe request and response models
- Create typed error handling
- Use generics for reusable client components

### Modularity/Composability

- Organize clients by domain
- Implement layered client architecture
- Create composable client operations
- Design modular error handling

### Testability

- Leverage @DependencyClient for automatic test value generation
- Implement deterministic client behavior
- Design testable client interfaces
- Create test utilities for client verification

## Content Structure

### Client Architecture

#### Layered Client Architecture

The client architecture follows a layered approach:

1. **Feature Layer**: TCA features that use abstract clients via dependencies
2. **Abstract Client Layer**: Domain-specific clients defined using @DependencyClient
3. **Platform Client Layer**: Platform-specific implementations (Firebase, REST, etc.)

```
┌─────────────────┐
│  Feature Layer  │
└────────┬────────┘
         │ Uses
         ▼
┌─────────────────┐
│ Abstract Client │
│      Layer      │
└────────┬────────┘
         │ Uses
         ▼
┌─────────────────┐
│ Platform Client │
│      Layer      │
└─────────────────┘
```

#### @DependencyClient Pattern

Define abstract clients using the @DependencyClient macro:

```swift
import DependenciesMacros
import Dependencies

// Example: User client interface
@DependencyClient
struct UserClient {
    var getCurrentUser: () async throws -> User
    var getUser: (_ id: String) async throws -> User
    var updateUser: (_ id: String, _ displayName: String) async throws -> User
    var deleteUser: (_ id: String) async throws -> Void
    var observeCurrentUser: () -> AsyncStream<User>
}

// Register the dependency
extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}

// Define live implementation using DependencyKey
extension UserClient: DependencyKey {
    static let liveValue = UserClient(
        getCurrentUser: {
            return FirebaseUserClient.shared.getCurrentUser()
        },
        getUser: { id in
            return try await FirebaseUserClient.shared.getUser(id: id)
        },
        updateUser: { id, displayName in
            return try await FirebaseUserClient.shared.updateUser(id: id, displayName: displayName)
        },
        deleteUser: { id in
            try await FirebaseUserClient.shared.deleteUser(id: id)
        },
        observeCurrentUser: {
            return FirebaseUserClient.shared.observeCurrentUser()
        }
    )
}
```

#### Platform-Specific Clients

Implement platform-specific clients that abstract clients use:

```swift
// Example: Firebase user client implementation
class FirebaseUserClient {
    static let shared = FirebaseUserClient()

    private let auth = Auth.auth()
    private let db = Firestore.firestore()

    private init() {}

    func getCurrentUser() async throws -> User {
        guard let authUser = auth.currentUser else {
            throw ClientError.notAuthenticated
        }

        return try await getUser(id: authUser.uid)
    }

    func getUser(id: String) async throws -> User {
        let document = try await db.collection("users").document(id).getDocument()

        guard document.exists else {
            throw ClientError.notFound
        }

        guard let data = document.data() else {
            throw ClientError.invalidData
        }

        return try Firestore.Decoder().decode(User.self, from: data)
    }

    func updateUser(id: String, displayName: String) async throws -> User {
        try await db.collection("users").document(id).updateData([
            "displayName": displayName
        ])

        return try await getUser(id: id)
    }

    func deleteUser(id: String) async throws {
        try await db.collection("users").document(id).delete()
    }

    func observeCurrentUser() -> AsyncStream<User> {
        AsyncStream { continuation in
            guard let userId = auth.currentUser?.uid else {
                continuation.finish()
                return
            }

            let listener = db.collection("users").document(userId)
                .addSnapshotListener { snapshot, error in
                    if let error = error {
                        print("Error observing user: \(error)")
                        return
                    }

                    guard let document = snapshot, document.exists,
                          let data = document.data() else {
                        return
                    }

                    do {
                        let user = try Firestore.Decoder().decode(User.self, from: data)
                        continuation.yield(user)
                    } catch {
                        print("Error decoding user: \(error)")
                    }
                }

            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }
}
```

### Client Types

#### Authentication Client

Handle user authentication operations:

```swift
@DependencyClient
struct AuthClient {
    var signIn: (_ email: String, _ password: String) async throws -> User
    var signUp: (_ email: String, _ password: String, _ displayName: String) async throws -> User
    var signOut: () async throws -> Void
    var resetPassword: (_ email: String) async throws -> Void
    var observeAuthState: () -> AsyncStream<User?>
}

extension DependencyValues {
    var authClient: AuthClient {
        get { self[AuthClient.self] }
        set { self[AuthClient.self] = newValue }
    }
}

extension AuthClient: DependencyKey {
    static let liveValue = AuthClient(
        signIn: { email, password in
            return try await FirebaseAuthClient.shared.signIn(email: email, password: password)
        },
        signUp: { email, password, displayName in
            return try await FirebaseAuthClient.shared.signUp(
                email: email,
                password: password,
                displayName: displayName
            )
        },
        signOut: {
            try await FirebaseAuthClient.shared.signOut()
        },
        resetPassword: { email in
            try await FirebaseAuthClient.shared.resetPassword(email: email)
        },
        observeAuthState: {
            return FirebaseAuthClient.shared.observeAuthState()
        }
    )
}
```

#### Data Client

Handle domain-specific data operations:

```swift
@DependencyClient
struct PostClient {
    var getPosts: () async throws -> [Post]
    var getPost: (_ id: String) async throws -> Post
    var createPost: (_ title: String, _ content: String) async throws -> Post
    var updatePost: (_ id: String, _ title: String, _ content: String) async throws -> Post
    var deletePost: (_ id: String) async throws -> Void
    var observePosts: () -> AsyncStream<[Post]>
}

extension DependencyValues {
    var postClient: PostClient {
        get { self[PostClient.self] }
        set { self[PostClient.self] = newValue }
    }
}

extension PostClient: DependencyKey {
    static let liveValue = PostClient(
        getPosts: {
            return try await FirebasePostClient.shared.getPosts()
        },
        getPost: { id in
            return try await FirebasePostClient.shared.getPost(id: id)
        },
        createPost: { title, content in
            return try await FirebasePostClient.shared.createPost(title: title, content: content)
        },
        updatePost: { id, title, content in
            return try await FirebasePostClient.shared.updatePost(
                id: id,
                title: title,
                content: content
            )
        },
        deletePost: { id in
            try await FirebasePostClient.shared.deletePost(id: id)
        },
        observePosts: {
            return FirebasePostClient.shared.observePosts()
        }
    )
}
```

#### Storage Client

Handle file storage operations:

```swift
@DependencyClient
struct StorageClient {
    var uploadImage: (_ image: UIImage, _ path: String) async throws -> URL
    var downloadImage: (_ path: String) async throws -> UIImage
    var deleteFile: (_ path: String) async throws -> Void
}

extension DependencyValues {
    var storageClient: StorageClient {
        get { self[StorageClient.self] }
        set { self[StorageClient.self] = newValue }
    }
}

extension StorageClient: DependencyKey {
    static let liveValue = StorageClient(
        uploadImage: { image, path in
            return try await FirebaseStorageClient.shared.uploadImage(image, path: path)
        },
        downloadImage: { path in
            return try await FirebaseStorageClient.shared.downloadImage(path: path)
        },
        deleteFile: { path in
            try await FirebaseStorageClient.shared.deleteFile(path: path)
        }
    )
}
```

#### Notification Client

Handle notification operations:

```swift
@DependencyClient
struct NotificationClient {
    // Notification types
    enum NotificationType: Equatable {
        case localSilent       // Confirmation of local interactions
        case remoteRegular     // Regular events from backend
        case remoteHighPriority // High priority events from backend
    }

    struct NotificationItem: Identifiable, Equatable {
        let id: String
        let type: NotificationType
        let title: String
        let message: String
        let timestamp: Date
        var isRead: Bool

        // Equatable conformance
        static func == (lhs: NotificationItem, rhs: NotificationItem) -> Bool {
            return lhs.id == rhs.id
        }
    }

    // Client methods
    var getNotifications: () -> [NotificationItem]
    var addLocalNotification: (_ title: String, _ message: String) -> Void
    var addRemoteNotification: (_ title: String, _ message: String, _ highPriority: Bool) -> Void
    var markAsRead: (_ id: String) -> Void
    var clearAll: () -> Void
    var getUnreadCount: () -> Int
    var observeNotifications: () -> AsyncStream<[NotificationItem]>
}

extension DependencyValues {
    var notificationClient: NotificationClient {
        get { self[NotificationClient.self] }
        set { self[NotificationClient.self] = newValue }
    }
}

extension NotificationClient: DependencyKey {
    static let liveValue = NotificationClient(
        getNotifications: {
            return FirebaseNotificationClient.shared.getNotifications()
        },
        addLocalNotification: { title, message in
            FirebaseNotificationClient.shared.addLocalNotification(title: title, message: message)
        },
        addRemoteNotification: { title, message, highPriority in
            FirebaseNotificationClient.shared.addRemoteNotification(
                title: title,
                message: message,
                highPriority: highPriority
            )
        },
        markAsRead: { id in
            FirebaseNotificationClient.shared.markAsRead(id: id)
        },
        clearAll: {
            FirebaseNotificationClient.shared.clearAll()
        },
        getUnreadCount: {
            return FirebaseNotificationClient.shared.getUnreadCount()
        },
        observeNotifications: {
            return FirebaseNotificationClient.shared.observeNotifications()
        }
    )
}
```

### Using Clients in Features

Features use clients via dependencies:

```swift
@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable, Sendable {
        var user: User?
        var isLoading = false
        var error: Error?
    }

    enum Action: Equatable, Sendable {
        case onAppear
        case userResponse(Result<User, Error>)
        case updateDisplayName(String)
        case updateResponse(Result<User, Error>)
    }

    @Dependency(\.userClient) var userClient

    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true

                return .run { send in
                    do {
                        let user = try await userClient.getCurrentUser()
                        await send(.userResponse(.success(user)))
                    } catch {
                        await send(.userResponse(.failure(error)))
                    }
                }

            case let .userResponse(.success(user)):
                state.user = user
                state.isLoading = false
                return .none

            case let .userResponse(.failure(error)):
                state.error = error
                state.isLoading = false
                return .none

            case let .updateDisplayName(displayName):
                guard let userId = state.user?.id else { return .none }
                state.isLoading = true

                return .run { send in
                    do {
                        let updatedUser = try await userClient.updateUser(userId, displayName)
                        await send(.updateResponse(.success(updatedUser)))
                    } catch {
                        await send(.updateResponse(.failure(error)))
                    }
                }

            case let .updateResponse(.success(user)):
                state.user = user
                state.isLoading = false
                return .none

            case let .updateResponse(.failure(error)):
                state.error = error
                state.isLoading = false
                return .none
            }
        }
    }
}
```

### Client Composition

Compose clients for complex operations:

```swift
@DependencyClient
struct UserProfileClient {
    var updateUserProfile: (_ userId: String, _ displayName: String, _ profileImage: UIImage?) async throws -> User
}

extension DependencyValues {
    var userProfileClient: UserProfileClient {
        get { self[UserProfileClient.self] }
        set { self[UserProfileClient.self] = newValue }
    }
}

extension UserProfileClient: DependencyKey {
    static let liveValue = Self(
        updateUserProfile: { userId, displayName, profileImage in
            @Dependency(\.userClient) var userClient
            @Dependency(\.storageClient) var storageClient

            var updatedUser = try await userClient.getUser(userId)

            // Update display name
            updatedUser = try await userClient.updateUser(userId, displayName)

            // Update profile image if provided
            if let profileImage = profileImage {
                let imagePath = "users/\(userId)/profile/avatar.jpg"
                let imageURL = try await storageClient.uploadImage(profileImage, imagePath)

                // This would require an additional method in the userClient
                // that we're assuming exists for this example
                updatedUser = try await userClient.updateUserPhoto(userId, imageURL.absoluteString)
            }

            return updatedUser
        }
    )
}
```

### Migration from Mock Application

#### Mock to Real Data

Replace mock repositories with real clients using the @DependencyClient pattern:

#### Mock Repository:

```swift
// Example: Mock Repository
class MockUserRepository: UserRepository {
    private var users: [User]

    init(users: [User] = MockData.users) {
        self.users = users
    }

    func getUser(id: String) async throws -> User {
        guard let user = users.first(where: { $0.id == id }) else {
            throw MockError.notFound
        }

        return user
    }

    func updateUser(id: String, displayName: String) async throws -> User {
        guard let index = users.firstIndex(where: { $0.id == id }) else {
            throw MockError.notFound
        }

        users[index].displayName = displayName
        return users[index]
    }
}
```

#### TCA Client with @DependencyClient:

```swift
// Example: TCA Client Interface using @DependencyClient
import DependenciesMacros

@DependencyClient
struct UserClient {
    var getUser: (_ id: String) async throws -> User
    var updateUser: (_ id: String, _ displayName: String) async throws -> User
}

// Example: Live Implementation
extension UserClient: DependencyKey {
    static let liveValue = Self(
        getUser: { id in
            let docRef = Firestore.firestore().collection("users").document(id)
            let document = try await docRef.getDocument()

            guard let data = document.data(), document.exists else {
                throw FirestoreError.documentNotFound
            }

            return try Firestore.Decoder().decode(User.self, from: data)
        },
        updateUser: { id, displayName in
            let docRef = Firestore.firestore().collection("users").document(id)

            try await docRef.updateData([
                "displayName": displayName
            ])

            let updatedDoc = try await docRef.getDocument()

            guard let data = updatedDoc.data(), updatedDoc.exists else {
                throw FirestoreError.documentNotFound
            }

            return try Firestore.Decoder().decode(User.self, from: data)
        }
    )

    // Preview implementation
    static let previewValue = Self(
        getUser: { id in
            return MockData.users.first { $0.id == id } ?? MockData.users[0]
        },
        updateUser: { id, displayName in
            var user = MockData.users.first { $0.id == id } ?? MockData.users[0]
            user.displayName = displayName
            return user
        }
    )
}

// Register the dependency
extension DependencyValues {
    var userClient: UserClient {
        get { self[UserClient.self] }
        set { self[UserClient.self] = newValue }
    }
}
```

#### Client Implementation Strategy

1. **Use @DependencyClient**: Leverage the macro for cleaner client definitions
2. **Define Interface**: Define the client interface with clear method signatures
3. **Implement Live Value**: Create the live implementation using real services
4. **Implement Preview Value**: Create a preview implementation using mock data
5. **Register Dependency**: Register the client with DependencyValues

#### Dependency Registration

Register dependencies in the app:

```swift
// Example: Dependency Registration
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(
                store: Store(initialState: AppFeature.State()) {
                    AppFeature()
                }
            )
        }
    }

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Register dependencies
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            // Use preview dependencies for SwiftUI previews
            DependencyValues.registerPreviewValues()
        } else if NSClassFromString("XCTestCase") != nil {
            // Use test dependencies for unit tests
            DependencyValues.registerTestValues()
        } else {
            // Use live dependencies for debug builds
            DependencyValues.registerLiveValues()
        }
        #else
        // Use live dependencies for release builds
        DependencyValues.registerLiveValues()
        #endif
    }
}

extension DependencyValues {
    static func registerLiveValues() {
        // Register live dependencies
    }

    static func registerTestValues() {
        // Register test dependencies
    }

    static func registerPreviewValues() {
        // Register preview dependencies
    }
}
```

## Error Handling

### Error Types

The production application handles the following error types in clients:

- **Domain Errors**: Business logic errors specific to a domain (UserError, PaymentError)
- **Infrastructure Errors**: Technical errors from underlying systems (NetworkError, DatabaseError)
- **Validation Errors**: Input validation failures
- **Authentication Errors**: Issues with user authentication or authorization
- **System Errors**: Device or OS-level errors

### Error Categorization

We categorize errors into three main types to ensure consistent handling across the application:

1. **Domain Errors**: Business logic errors specific to a domain
2. **Infrastructure Errors**: Technical errors from underlying systems
3. **Validation Errors**: Input validation failures

### Error Design Principles

- **Type Safety**: All errors are strongly typed
- **Locality**: Errors are defined close to where they occur
- **Clarity**: Error messages are clear and actionable
- **Recoverability**: Errors include recovery information when possible
- **Traceability**: Errors include context for debugging

### Error Hierarchy

```swift
// Base application error protocol
protocol AppError: Error, Equatable, CustomStringConvertible {
    var errorCode: String { get }
    var errorDescription: String { get }
    var recoverySuggestion: String? { get }
    var isRetryable: Bool { get }
}

// Domain-specific error implementations
enum UserError: AppError {
    case userNotFound(id: String)
    case invalidUsername(reason: String)
    case insufficientPermissions
    case accountLocked

    var errorCode: String {
        switch self {
        case .userNotFound: return "USER_NOT_FOUND"
        case .invalidUsername: return "INVALID_USERNAME"
        case .insufficientPermissions: return "INSUFFICIENT_PERMISSIONS"
        case .accountLocked: return "ACCOUNT_LOCKED"
        }
    }

    var errorDescription: String {
        switch self {
        case .userNotFound(let id):
            return "User with ID \(id) was not found."
        case .invalidUsername(let reason):
            return "Invalid username: \(reason)"
        case .insufficientPermissions:
            return "You don't have permission to perform this action."
        case .accountLocked:
            return "This account has been locked."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .userNotFound:
            return "Check the user ID or create a new user."
        case .invalidUsername:
            return "Please use only letters, numbers, and underscores."
        case .insufficientPermissions:
            return "Contact an administrator to request access."
        case .accountLocked:
            return "Please contact support to unlock your account."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .userNotFound, .invalidUsername, .insufficientPermissions:
            return false
        case .accountLocked:
            return false
        }
    }

    var description: String {
        return "[\(errorCode)] \(errorDescription)"
    }
}
```

### Error Transformation

Transform low-level errors to domain-specific errors with context preservation:

```swift
// Error transformation utility
struct ErrorTransformer {
    static func transformNetworkError(_ error: Error, endpoint: String) -> AppError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return NetworkError.connectionFailed(endpoint: endpoint, underlyingError: urlError)
            case .timedOut:
                return NetworkError.timeout(endpoint: endpoint, underlyingError: urlError)
            default:
                return NetworkError.unknown(endpoint: endpoint, underlyingError: urlError)
            }
        } else if let httpError = error as? HTTPError {
            switch httpError.statusCode {
            case 400:
                return ValidationError.invalidRequest(details: httpError.message)
            case 401:
                return AuthError.unauthorized(reason: "Invalid or expired credentials")
            case 403:
                return AuthError.forbidden(reason: "Access denied to this resource")
            case 404:
                return NetworkError.resourceNotFound(endpoint: endpoint)
            case 429:
                return NetworkError.rateLimited(endpoint: endpoint, retryAfter: httpError.headers["Retry-After"])
            case 500...599:
                return NetworkError.serverError(statusCode: httpError.statusCode, endpoint: endpoint)
            default:
                return NetworkError.unknown(endpoint: endpoint, underlyingError: httpError)
            }
        }

        return NetworkError.unknown(endpoint: endpoint, underlyingError: error)
    }
}
```

### Advanced Retry Logic

```swift
// Configurable retry policy
struct RetryPolicy {
    let maxRetries: Int
    let initialDelay: TimeInterval
    let backoffFactor: Double
    let jitter: Double
    let retryableErrors: (Error) -> Bool

    static let `default` = RetryPolicy(
        maxRetries: 3,
        initialDelay: 0.5,
        backoffFactor: 2.0,
        jitter: 0.2,
        retryableErrors: { error in
            if let appError = error as? AppError {
                return appError.isRetryable
            }

            // Consider network connectivity errors retryable
            if let urlError = error as? URLError {
                return [.notConnectedToInternet, .networkConnectionLost, .timedOut].contains(urlError.code)
            }

            return false
        }
    )

    static let aggressive = RetryPolicy(
        maxRetries: 5,
        initialDelay: 0.2,
        backoffFactor: 1.5,
        jitter: 0.1,
        retryableErrors: { error in
            if let appError = error as? AppError {
                return appError.isRetryable
            }

            // Consider most errors retryable except for validation errors
            if let validationError = error as? ValidationError {
                return false
            }

            return true
        }
    )
}

// Retry execution utility
func withRetry<T>(
    operation: @escaping () async throws -> T,
    policy: RetryPolicy = .default,
    onRetry: ((Error, Int, TimeInterval) -> Void)? = nil
) async throws -> T {
    var currentRetry = 0

    while true {
        do {
            return try await operation()
        } catch let error where currentRetry < policy.maxRetries && policy.retryableErrors(error) {
            currentRetry += 1

            // Calculate delay with exponential backoff and jitter
            let baseDelay = policy.initialDelay * pow(policy.backoffFactor, Double(currentRetry - 1))
            let jitterRange = baseDelay * policy.jitter
            let actualDelay = baseDelay + Double.random(in: -jitterRange...jitterRange)

            // Notify about retry
            onRetry?(error, currentRetry, actualDelay)

            // Wait before retrying
            try await Task.sleep(nanoseconds: UInt64(actualDelay * 1_000_000_000))
        } catch {
            throw error
        }
    }
}
```

### Structured Error Logging

```swift
// Structured error logging
struct ErrorLogger {
    enum LogLevel: String {
        case debug, info, warning, error, critical
    }

    struct LogEntry: Encodable {
        let timestamp: Date
        let level: String
        let errorCode: String
        let message: String
        let context: [String: String]
        let stackTrace: String?

        init(level: LogLevel, error: Error, context: [String: String]) {
            self.timestamp = Date()
            self.level = level.rawValue

            if let appError = error as? AppError {
                self.errorCode = appError.errorCode
                self.message = appError.errorDescription
            } else {
                self.errorCode = "UNKNOWN"
                self.message = error.localizedDescription
            }

            self.context = context

            // Capture stack trace for non-production environments
            #if DEBUG
            self.stackTrace = Thread.callStackSymbols.joined(separator: "\n")
            #else
            self.stackTrace = nil
            #endif
        }
    }

    static func log(
        error: Error,
        level: LogLevel = .error,
        context: [String: String] = [:],
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Create log entry with file context
        var enrichedContext = context
        enrichedContext["file"] = URL(fileURLWithPath: file).lastPathComponent
        enrichedContext["function"] = function
        enrichedContext["line"] = String(line)

        let entry = LogEntry(level: level, error: error, context: enrichedContext)

        // Log to console in development
        #if DEBUG
        print("[\(entry.level.uppercased())] \(entry.errorCode): \(entry.message)")
        print("Context: \(entry.context)")
        if let stackTrace = entry.stackTrace {
            print("Stack trace:\n\(stackTrace)")
        }
        #endif

        // In production, would send to logging service
        #if !DEBUG
        // Send to logging service
        Task {
            do {
                try await LoggingService.shared.send(entry)
            } catch {
                // Fallback to local storage if logging service fails
                LocalLogStorage.store(entry)
            }
        }
        #endif
    }
}
```

### Domain Errors

Domain-specific errors that represent failures in business logic:

```swift
// Example: User domain errors
enum UserError: Error, Equatable {
    case userNotFound(id: String)
    case invalidUsername(reason: String)
    case insufficientPermissions
    case accountLocked
}

// Example: Payment domain errors
enum PaymentError: Error, Equatable {
    case insufficientFunds
    case paymentMethodExpired
    case paymentDeclined(reason: String)
    case serviceUnavailable
    case paymentMethodNotFound
}
```

### Infrastructure Errors

Errors from infrastructure components like networking, database, etc.:

```swift
// Example: Network errors
enum NetworkError: Error, Equatable {
    case connectionFailed
    case timeout
    case serverError(statusCode: Int)
    case invalidResponse
    case decodingFailed
}

// Example: Database errors
enum DatabaseError: Error, Equatable {
    case documentNotFound
    case permissionDenied
    case transactionFailed
    case corruptData
}

// Example: Authorization errors
enum AuthorizationError: Error, Equatable {
    case unauthorized
    case forbidden
    case tokenExpired
}
```

### Error Logging

Log errors for debugging and monitoring:

```swift
// Example: Error logging middleware
struct ErrorLoggingMiddleware {
    let log: (String, LogLevel) -> Void

    enum LogLevel {
        case debug, info, warning, error, critical
    }

    func handleError(_ error: Error, context: String) {
        switch error {
        case let networkError as NetworkError:
            log("Network error in \(context): \(networkError)", .error)

        case let userError as UserError:
            log("User error in \(context): \(userError)", .warning)

        case let decodingError as DecodingError:
            log("Decoding error in \(context): \(decodingError)", .error)

        default:
            log("Unknown error in \(context): \(error.localizedDescription)", .error)
        }
    }
}

// Usage in a client
extension UserClient: DependencyKey {
    static let liveValue = Self(
        getUser: { id in
            do {
                let docRef = Firestore.firestore().collection("users").document(id)
                let document = try await docRef.getDocument()

                guard let data = document.data(), document.exists else {
                    let error = UserError.userNotFound(id: id)
                    ErrorLogger.shared.handleError(error, context: "UserClient.getUser")
                    throw error
                }

                return try Firestore.Decoder().decode(User.self, from: data)
            } catch let error as UserError {
                ErrorLogger.shared.handleError(error, context: "UserClient.getUser")
                throw error
            } catch {
                let wrappedError = NetworkError.decodingFailed
                ErrorLogger.shared.handleError(wrappedError, context: "UserClient.getUser")
                throw wrappedError
            }
        }
    )
}
```

### Error Transformation

Transform low-level errors to domain-specific errors:

```swift
// Example: Error transformation in a client
extension PaymentClient: DependencyKey {
    static let liveValue = Self(
        processPayment: { payment in
            do {
                let result = try await apiClient.post("/payments", body: payment)
                return try JSONDecoder().decode(PaymentReceipt.self, from: result.data)
            } catch let error as URLError {
                switch error.code {
                case .notConnectedToInternet, .networkConnectionLost:
                    throw NetworkError.connectionFailed
                case .timedOut:
                    throw NetworkError.timeout
                default:
                    throw NetworkError.invalidResponse
                }
            } catch let error as HTTPError {
                switch error.statusCode {
                case 401:
                    throw AuthorizationError.unauthorized
                case 403:
                    throw AuthorizationError.forbidden
                case 404:
                    throw PaymentError.paymentMethodNotFound
                case 422:
                    if let apiError = error.apiError, apiError.code == "insufficient_funds" {
                        throw PaymentError.insufficientFunds
                    } else {
                        throw PaymentError.paymentDeclined(reason: error.apiError?.message ?? "Unknown reason")
                    }
                default:
                    throw NetworkError.serverError(statusCode: error.statusCode)
                }
            } catch {
                throw NetworkError.invalidResponse
            }
        }
    )
}
```

### Retry Logic

Implement retry logic for transient errors:

```swift
// Example: Retry logic for network operations
func performWithRetry<T>(
    maxRetries: Int = 3,
    retryDelay: TimeInterval = 1.0,
    operation: @escaping () async throws -> T
) async throws -> T {
    var currentRetry = 0

    while true {
        do {
            return try await operation()
        } catch let error as NetworkError {
            currentRetry += 1

            // Only retry for specific network errors
            switch error {
            case .connectionFailed, .timeout, .serverError:
                if currentRetry <= maxRetries {
                    // Exponential backoff
                    let delay = retryDelay * pow(2.0, Double(currentRetry - 1))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
            default:
                break
            }

            throw error
        } catch {
            throw error
        }
    }
}

// Usage in a client
extension UserClient: DependencyKey {
    static let liveValue = Self(
        getUser: { id in
            try await performWithRetry {
                let docRef = Firestore.firestore().collection("users").document(id)
                let document = try await docRef.getDocument()

                guard let data = document.data(), document.exists else {
                    throw UserError.userNotFound(id: id)
                }

                return try Firestore.Decoder().decode(User.self, from: data)
            }
        }
    )
}
```

## Testing

### Unit Testing Strategy

The production application implements a comprehensive testing strategy for clients:

1. **Unit Testing**: Test individual client methods in isolation
2. **Integration Testing**: Test client interactions with other components
3. **Mock Testing**: Test with mock implementations of external services
4. **Error Path Testing**: Verify correct handling of error conditions
5. **Performance Testing**: Verify client performance under load

### Comprehensive Testing Strategy

We implement a multi-layered testing approach for clients:

1. **Unit Tests**: Test individual client methods in isolation
2. **Integration Tests**: Test client interactions with other components
3. **Mock Tests**: Test with mock implementations of external services
4. **Error Path Tests**: Verify correct handling of error conditions
5. **Performance Tests**: Verify client performance under load

### Unit Testing with Dependencies

```swift
import XCTest
import Dependencies
import DependenciesMacros
@testable import MyApp

final class UserClientTests: XCTestCase {
    func testGetUser_Success() async throws {
        // Arrange
        let expectedUser = User(id: "test-id", displayName: "Test User", email: "test@example.com")

        let userClient = withDependencies { dependencies in
            dependencies.userClient.getUser = { id in
                XCTAssertEqual(id, "test-id")
                return expectedUser
            }
        } operation: {
            DependencyValues.live.userClient
        }

        // Act
        let user = try await userClient.getUser("test-id")

        // Assert
        XCTAssertEqual(user, expectedUser)
    }

    func testGetUser_NotFound() async {
        // Arrange
        let userClient = withDependencies { dependencies in
            dependencies.userClient.getUser = { id in
                throw UserError.userNotFound(id: id)
            }
        } operation: {
            DependencyValues.live.userClient
        }

        // Act & Assert
        do {
            _ = try await userClient.getUser("nonexistent-id")
            XCTFail("Expected error to be thrown")
        } catch let error as UserError {
            // Verify the correct error type and details
            if case let .userNotFound(id) = error {
                XCTAssertEqual(id, "nonexistent-id")
            } else {
                XCTFail("Expected UserError.userNotFound, got \(error)")
            }
        } catch {
            XCTFail("Expected UserError, got \(error)")
        }
    }
}
```

### Testing Retry Logic

```swift
func testGetUser_WithRetry() async {
    // Arrange
    var callCount = 0
    let expectedUser = User(id: "test-id", displayName: "Test User", email: "test@example.com")

    let userClient = withDependencies { dependencies in
        dependencies.userClient.getUser = { id in
            callCount += 1

            // Fail the first two attempts, succeed on the third
            if callCount < 3 {
                throw NetworkError.connectionFailed(endpoint: "/users/\(id)", underlyingError: nil)
            }

            return expectedUser
        }
    } operation: {
        DependencyValues.live.userClient
    }

    // Act
    let user = try await withRetry {
        try await userClient.getUser("test-id")
    }

    // Assert
    XCTAssertEqual(user, expectedUser)
    XCTAssertEqual(callCount, 3, "Expected 3 attempts before success")
}
```

### Testing Async Streams

```swift
func testObserveCurrentUser() async {
    // Arrange
    let user1 = User(id: "test-id", displayName: "Test User", email: "test@example.com")
    let user2 = User(id: "test-id", displayName: "Updated User", email: "test@example.com")

    let userClient = withDependencies { dependencies in
        dependencies.userClient.observeCurrentUser = {
            AsyncStream { continuation in
                // Emit initial user
                continuation.yield(user1)

                // Schedule updated user after delay
                Task {
                    try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    continuation.yield(user2)
                    continuation.finish()
                }
            }
        }
    } operation: {
        DependencyValues.live.userClient
    }

    // Act & Assert
    var receivedUsers: [User] = []

    for await user in userClient.observeCurrentUser() {
        receivedUsers.append(user)

        // Break after receiving both users
        if receivedUsers.count == 2 {
            break
        }
    }

    XCTAssertEqual(receivedUsers.count, 2)
    XCTAssertEqual(receivedUsers[0], user1)
    XCTAssertEqual(receivedUsers[1], user2)
}
```

### Integration Testing with Mock Server

```swift
func testUserClient_IntegrationWithMockServer() async throws {
    // Arrange
    let mockServer = MockServer()
    try await mockServer.start()
    defer { mockServer.stop() }

    // Configure mock responses
    mockServer.addResponse(
        for: "/users/test-id",
        statusCode: 200,
        headers: ["Content-Type": "application/json"],
        body: """
        {
            "id": "test-id",
            "displayName": "Test User",
            "email": "test@example.com"
        }
        """
    )

    // Create client with mock server URL
    let userClient = withDependencies { dependencies in
        dependencies.apiClient.baseURL = mockServer.baseURL
    } operation: {
        DependencyValues.live.userClient
    }

    // Act
    let user = try await userClient.getUser("test-id")

    // Assert
    XCTAssertEqual(user.id, "test-id")
    XCTAssertEqual(user.displayName, "Test User")
    XCTAssertEqual(user.email, "test@example.com")

    // Verify request was made correctly
    XCTAssertEqual(mockServer.requestCount(for: "/users/test-id"), 1)
}
```

### Performance Testing

```swift
func testUserClient_Performance() async throws {
    // Arrange
    let userClient = DependencyValues.live.userClient

    // Act & Assert
    measure(metrics: [XCTCPUMetric(), XCTMemoryMetric(), XCTClockMetric()]) {
        let expectation = expectation(description: "Get 100 users")

        Task {
            do {
                for i in 1...100 {
                    _ = try await userClient.getUser("user-\(i)")
                }
                expectation.fulfill()
            } catch {
                XCTFail("Error: \(error)")
            }
        }

        wait(for: [expectation], timeout: 10.0)
    }
}
```

## Best Practices

* Use @DependencyClient for all clients
* Implement proper error handling
* Create typed error enums
* Use async/await for asynchronous operations
* Keep clients focused on a single responsibility
* Document client interfaces
* Test all client methods
* Implement retry mechanisms for transient failures
* Use proper logging
* Create test values for all clients
* Use consistent naming conventions

## Anti-patterns

* Creating monolithic clients
* Not handling errors properly
* Using untyped request or response models
* Implementing business logic in clients
* Not testing error paths
* Using global state instead of dependencies
* Hardcoding configuration values
* Not documenting client interfaces
* Mixing UI and client logic