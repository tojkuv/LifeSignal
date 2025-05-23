```swift
import SwiftUI
import ComposableArchitecture
import Dependencies
import DependenciesMacros

// MARK: - Domain Models

struct User: Codable, Equatable, Identifiable {
  let id: UUID
  let firebaseUID: String
  var name: String
  var phoneNumber: String
  var isNotificationsEnabled: Bool = true
  var avatarURL: String?
  var lastModified: Date = Date()
}

struct Contact: Codable, Equatable, Identifiable {
  let id: UUID
  let userID: UUID
  var name: String
  var phoneNumber: String
  var status: ContactStatus
  var lastUpdated: Date

  enum ContactStatus: String, Codable, CaseIterable {
    case active, away, busy, offline
  }
}

// MARK: - Navigation Types

enum Route: Hashable {
  case contactDetail(Contact.ID)
  case editProfile
  case settings
  case phoneVerification(String)
}

enum Sheet: Hashable {
  case imagePicker
  case contactActions(Contact.ID)
  case phoneNumberInput
}

// MARK: - Validation

enum ValidationResult: Equatable {
  case valid
  case invalid(String)

  var isValid: Bool {
    if case .valid = self { return true }
    return false
  }

  var errorMessage: String? {
    if case .invalid(let message) = self { return message }
    return nil
  }
}

// MARK: - Notification Types

struct LocalNotification: Codable, Equatable {
  let id: String
  let title: String
  let body: String
  let scheduledDate: Date
  let userInfo: [String: String]
}

// MARK: - gRPC Proto Types

struct User_Proto: Sendable {
  var id: String
  var firebaseUID: String
  var name: String
  var phoneNumber: String
  var isNotificationsEnabled: Bool
  var avatarURL: String
  var lastModified: Int64
}

struct Contact_Proto: Sendable {
  var id: String
  var userID: String
  var name: String
  var phoneNumber: String
  var status: Contact_ContactStatus
  var lastUpdated: Int64

  enum Contact_ContactStatus: Int32, CaseIterable, Sendable {
    case active = 0, away = 1, busy = 2, offline = 3
  }
}

// MARK: - gRPC Request/Response Types

struct GetUserRequest: Sendable { let firebaseUID: String }
struct CreateUserRequest: Sendable { let firebaseUID: String; let name: String; let phoneNumber: String; let isNotificationsEnabled: Bool }
struct UpdateUserRequest: Sendable { let firebaseUID: String; let name: String; let phoneNumber: String; let isNotificationsEnabled: Bool; let avatarURL: String }
struct UploadAvatarRequest: Sendable { let firebaseUID: String; let imageData: Data }
struct UploadAvatarResponse: Sendable { let url: String }
struct GetContactsRequest: Sendable { let firebaseUID: String }
struct GetContactsResponse: Sendable { let contacts: [Contact_Proto] }
struct AddContactRequest: Sendable { let firebaseUID: String; let phoneNumber: String }
struct UpdateContactStatusRequest: Sendable { let contactID: String; let status: Contact_Proto.Contact_ContactStatus }
struct RemoveContactRequest: Sendable { let contactID: String }
struct Empty_Proto: Sendable {}

// MARK: - gRPC Service Protocols

protocol UserServiceProtocol: Sendable {
  func getUser(_ request: GetUserRequest) async throws -> User_Proto
  func createUser(_ request: CreateUserRequest) async throws -> User_Proto
  func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto
  func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse
}

protocol ContactServiceProtocol: Sendable {
  func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse
  func addContact(_ request: AddContactRequest) async throws -> Contact_Proto
  func updateContactStatus(_ request: UpdateContactStatusRequest) async throws -> Contact_Proto
  func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto
}

// MARK: - Dependencies

@DependencyClient
struct ValidationClient {
  var validatePhoneNumber: @Sendable (String) -> ValidationResult = { _ in .valid }
  var validateName: @Sendable (String) -> ValidationResult = { _ in .valid }
  var validateVerificationCode: @Sendable (String) -> ValidationResult = { _ in .valid }
  var formatPhoneNumber: @Sendable (String) -> String = { $0 }
}

@DependencyClient
struct FirebaseAuthClient {
  var sendVerificationCode: @Sendable (String) async throws -> String
  var verifyCode: @Sendable (String, String) async throws -> String
  var signOut: @Sendable () async throws -> Void
  var getCurrentUID: @Sendable () -> String?
}

@DependencyClient
struct GRPCClient {
  var userService: UserServiceProtocol
  var contactService: ContactServiceProtocol
}

@DependencyClient
struct NotificationClient {
  var requestPermission: @Sendable () async throws -> Bool
  var scheduleLocal: @Sendable (LocalNotification) -> Void
  var registerForRemote: @Sendable () async throws -> String
}

@DependencyClient
struct HapticClient {
  var impact: @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
  var notification: @Sendable (UINotificationFeedbackGenerator.FeedbackType) -> Void
  var selection: @Sendable () -> Void
}

// MARK: - Repository

@DependencyClient
struct UserRepository {
  var getCurrentUser: @Sendable () async -> User?
  var authenticate: @Sendable (String, String) async throws -> User
  var sendVerificationCode: @Sendable (String) async throws -> String
  var createAccount: @Sendable (String, String, String) async throws -> User
  var updateProfile: @Sendable (User) async throws -> User
  var uploadAvatar: @Sendable (Data) async throws -> URL
  var signOut: @Sendable () async throws -> Void
}

@DependencyClient
struct ContactRepository {
  var getContacts: @Sendable () async throws -> [Contact]
  var addContact: @Sendable (String) async throws -> Contact
  var updateContactStatus: @Sendable (UUID, Contact.ContactStatus) async throws -> Contact
  var removeContact: @Sendable (UUID) async throws -> Void
}

// MARK: - Proto to Domain Mapping Extensions

extension User_Proto {
  func toDomain() -> User {
    User(
      id: UUID(uuidString: id) ?? UUID(),
      firebaseUID: firebaseUID,
      name: name,
      phoneNumber: phoneNumber,
      isNotificationsEnabled: isNotificationsEnabled,
      avatarURL: avatarURL.isEmpty ? nil : avatarURL,
      lastModified: Date(timeIntervalSince1970: TimeInterval(lastModified))
    )
  }
}

extension Contact_Proto {
  func toDomain() -> Contact {
    Contact(
      id: UUID(uuidString: id) ?? UUID(),
      userID: UUID(uuidString: userID) ?? UUID(),
      name: name,
      phoneNumber: phoneNumber,
      status: status.toDomain(),
      lastUpdated: Date(timeIntervalSince1970: TimeInterval(lastUpdated))
    )
  }
}

extension Contact_Proto.Contact_ContactStatus {
  func toDomain() -> Contact.ContactStatus {
    switch self {
    case .active: return .active
    case .away: return .away
    case .busy: return .busy
    case .offline: return .offline
    }
  }
}

extension Contact.ContactStatus {
  func toProto() -> Contact_Proto.Contact_ContactStatus {
    switch self {
    case .active: return .active
    case .away: return .away
    case .busy: return .busy
    case .offline: return .offline
    }
  }
}

// MARK: - Dependency Implementations

extension ValidationClient: DependencyKey {
  static let liveValue = ValidationClient(
    validatePhoneNumber: { phone in
      let cleaned = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
      guard !cleaned.isEmpty else { return .invalid("Phone number is required") }

      if cleaned.hasPrefix("+") {
        return cleaned.count >= 8 && cleaned.count <= 16 ? .valid : .invalid("Invalid international phone number")
      } else {
        return cleaned.count == 10 ? .valid : .invalid("Phone number must be 10 digits")
      }
    },

    validateName: { name in
      let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty { return .invalid("Name is required") }
      if trimmed.count < 2 { return .invalid("Name must be at least 2 characters") }
      if trimmed.count > 50 { return .invalid("Name must be less than 50 characters") }
      return .valid
    },

    validateVerificationCode: { code in
      let cleaned = code.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
      return cleaned.count == 6 ? .valid : .invalid("Verification code must be 6 digits")
    },

    formatPhoneNumber: { phone in
      let cleaned = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
      if cleaned.count == 10 {
        return String(format: "(%@) %@-%@",
                     String(cleaned.prefix(3)),
                     String(cleaned.dropFirst(3).prefix(3)),
                     String(cleaned.dropFirst(6)))
      }
      return phone
    }
  )
}

extension FirebaseAuthClient: DependencyKey {
  static let liveValue = FirebaseAuthClient(
    sendVerificationCode: { phone in "verification-id-\(phone.suffix(4))" },
    verifyCode: { id, code in "firebase-uid-\(id.suffix(4))" },
    signOut: { },
    getCurrentUID: { nil }
  )
}

extension GRPCClient: DependencyKey {
  static let liveValue = GRPCClient(
    userService: LiveUserService(),
    contactService: LiveContactService()
  )

  static let testValue = GRPCClient(
    userService: MockUserService(),
    contactService: MockContactService()
  )
}

extension APIClient: DependencyKey {
  static let liveValue = APIClient(
    getUser: { uid in
      User(id: UUID(), firebaseUID: uid, name: "Mock User", phoneNumber: "+1234567890")
    },
    createUser: { uid, name, phone in
      User(id: UUID(), firebaseUID: uid, name: name, phoneNumber: phone)
    },
    updateUser: { user in user },
    getContacts: {
      [
        Contact(id: UUID(), userID: UUID(), name: "John Doe", phoneNumber: "+1234567890", status: .active, lastUpdated: Date()),
        Contact(id: UUID(), userID: UUID(), name: "Jane Smith", phoneNumber: "+0987654321", status: .away, lastUpdated: Date())
      ]
    },
    addContact: { phone in
      Contact(id: UUID(), userID: UUID(), name: "New Contact", phoneNumber: phone, status: .active, lastUpdated: Date())
    },
    updateContactStatus: { id, status in
      Contact(id: id, userID: UUID(), name: "Updated Contact", phoneNumber: "+1234567890", status: status, lastUpdated: Date())
    },
    removeContact: { _ in },
    uploadAvatar: { _ in URL(string: "https://example.com/avatar.jpg")! }
  )
}

extension NotificationClient: DependencyKey {
  static let liveValue = NotificationClient(
    requestPermission: { true },
    scheduleLocal: { _ in },
    registerForRemote: { "mock-device-token" }
  )
}

extension HapticClient: DependencyKey {
  static let liveValue = HapticClient(
    impact: { style in
      let generator = UIImpactFeedbackGenerator(style: style)
      generator.impactOccurred()
    },
    notification: { type in
      let generator = UINotificationFeedbackGenerator()
      generator.notificationOccurred(type)
    },
    selection: {
      let generator = UISelectionFeedbackGenerator()
      generator.selectionChanged()
    }
  )
}

extension UserRepository: DependencyKey {
  static let liveValue: UserRepository = {
    @Dependency(\.grpcClient) var grpc
    @Dependency(\.firebaseAuth) var auth

    return UserRepository(
      getCurrentUser: {
        guard let uid = auth.getCurrentUID() else { return nil }
        let request = GetUserRequest(firebaseUID: uid)
        let proto = try await grpc.userService.getUser(request)
        return proto.toDomain()
      },
      authenticate: { phone, code in
        let uid = try await auth.verifyCode(phone, code)
        let request = GetUserRequest(firebaseUID: uid)
        let proto = try await grpc.userService.getUser(request)
        return proto.toDomain()
      },
      sendVerificationCode: { phone in
        try await auth.sendVerificationCode(phone)
      },
      createAccount: { phone, code, name in
        let uid = try await auth.verifyCode(phone, code)
        let request = CreateUserRequest(
          firebaseUID: uid,
          name: name,
          phoneNumber: phone,
          isNotificationsEnabled: true
        )
        let proto = try await grpc.userService.createUser(request)
        return proto.toDomain()
      },
      updateProfile: { user in
        let request = UpdateUserRequest(
          firebaseUID: user.firebaseUID,
          name: user.name,
          phoneNumber: user.phoneNumber,
          isNotificationsEnabled: user.isNotificationsEnabled,
          avatarURL: user.avatarURL ?? ""
        )
        let proto = try await grpc.userService.updateUser(request)
        return proto.toDomain()
      },
      uploadAvatar: { data in
        guard let uid = auth.getCurrentUID() else { throw UserRepositoryError.authenticationFailed }
        let request = UploadAvatarRequest(firebaseUID: uid, imageData: data)
        let response = try await grpc.userService.uploadAvatar(request)
        return URL(string: response.url)!
      },
      signOut: {
        try await auth.signOut()
      }
    )
  }()
}

extension ContactRepository: DependencyKey {
  static let liveValue: ContactRepository = {
    @Dependency(\.grpcClient) var grpc
    @Dependency(\.firebaseAuth) var auth

    return ContactRepository(
      getContacts: {
        let request = GetContactsRequest(firebaseUID: auth.getCurrentUID() ?? "")
        let response = try await grpc.contactService.getContacts(request)
        return response.contacts.map { $0.toDomain() }
      },
      addContact: { phone in
        let request = AddContactRequest(
          firebaseUID: auth.getCurrentUID() ?? "",
          phoneNumber: phone
        )
        let proto = try await grpc.contactService.addContact(request)
        return proto.toDomain()
      },
      updateContactStatus: { id, status in
        let request = UpdateContactStatusRequest(
          contactID: id.uuidString,
          status: status.toProto()
        )
        let proto = try await grpc.contactService.updateContactStatus(request)
        return proto.toDomain()
      },
      removeContact: { id in
        let request = RemoveContactRequest(contactID: id.uuidString)
        _ = try await grpc.contactService.removeContact(request)
      }
    )
  }()
}

// MARK: - Shared State

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<User?>> {
  static var currentUser: Self {
    PersistenceKeyDefault(.inMemory("currentUser"), nil)
  }
}

extension PersistenceKey where Self == PersistenceKeyDefault<InMemoryKey<[Contact]>> {
  static var contacts: Self {
    PersistenceKeyDefault(.inMemory("contacts"), [])
  }
}

// MARK: - Features

@Reducer
struct PhoneVerificationFeature {
  @ObservableState
  struct State: Equatable {
    var phoneNumber = ""
    var verificationCode = ""
    var isCodeSent = false
    var isLoading = false
    var errorMessage: String?
    var name = "" // For account creation
    var isCreatingAccount = false

    var canSendCode: Bool {
      !phoneNumber.isEmpty && !isLoading
    }

    var canVerifyCode: Bool {
      !verificationCode.isEmpty && !isLoading
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case sendVerificationCode
    case verifyCode
    case createAccount
    case response(Result<User, Error>)
  }

  @Dependency(\.userRepository) var userRepository
  @Dependency(\.validation) var validation
  @Dependency(\.haptics) var haptics

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        state.errorMessage = nil
        return .none

      case .sendVerificationCode:
        let phoneValidation = validation.validatePhoneNumber(state.phoneNumber)
        guard phoneValidation.isValid else {
          state.errorMessage = phoneValidation.errorMessage
          haptics.notification(.error)
          return .none
        }

        state.isLoading = true
        haptics.selection()

        return .run { [phone = state.phoneNumber] send in
          await send(.response(Result {
            _ = try await userRepository.sendVerificationCode(phone)
            return User(id: UUID(), firebaseUID: "", name: "", phoneNumber: phone) // Placeholder for success
          }))
        }

      case .verifyCode:
        let codeValidation = validation.validateVerificationCode(state.verificationCode)
        guard codeValidation.isValid else {
          state.errorMessage = codeValidation.errorMessage
          haptics.notification(.error)
          return .none
        }

        state.isLoading = true
        haptics.selection()

        return .run { [phone = state.phoneNumber, code = state.verificationCode] send in
          await send(.response(Result {
            try await userRepository.authenticate(phone, code)
          }))
        }

      case .createAccount:
        let nameValidation = validation.validateName(state.name)
        guard nameValidation.isValid else {
          state.errorMessage = nameValidation.errorMessage
          haptics.notification(.error)
          return .none
        }

        state.isLoading = true
        haptics.selection()

        return .run { [phone = state.phoneNumber, code = state.verificationCode, name = state.name] send in
          await send(.response(Result {
            try await userRepository.createAccount(phone, code, name)
          }))
        }

      case let .response(.success(user)):
        state.isLoading = false
        if user.firebaseUID.isEmpty {
          // Code sent successfully
          state.isCodeSent = true
        }
        haptics.notification(.success)
        return .none

      case let .response(.failure(error)):
        state.isLoading = false
        if error.localizedDescription.contains("not found") {
          state.isCreatingAccount = true
        } else {
          state.errorMessage = error.localizedDescription
          haptics.notification(.error)
        }
        return .none
      }
    }
  }
}

@Reducer
struct ContactFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.contacts) var contacts: [Contact]
    var newContactPhone = ""
    var isLoading = false
    var errorMessage: String?

    var sortedContacts: [Contact] {
      contacts.sorted { $0.name < $1.name }
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onAppear
    case addContact
    case removeContact(UUID)
    case updateStatus(UUID, Contact.ContactStatus)
    case response(Result<Contact, Error>)
    case loadResponse(Result<[Contact], Error>)
  }

  @Dependency(\.contactRepository) var contactRepository
  @Dependency(\.validation) var validation
  @Dependency(\.haptics) var haptics

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        state.errorMessage = nil
        return .none

      case .onAppear:
        state.isLoading = true
        return .run { send in
          await send(.loadResponse(Result {
            try await contactRepository.getContacts()
          }))
        }

      case .addContact:
        let phoneValidation = validation.validatePhoneNumber(state.newContactPhone)
        guard phoneValidation.isValid else {
          state.errorMessage = phoneValidation.errorMessage
          haptics.notification(.error)
          return .none
        }

        state.isLoading = true
        haptics.selection()

        return .run { [phone = state.newContactPhone] send in
          await send(.response(Result {
            try await contactRepository.addContact(phone)
          }))
        }

      case let .removeContact(id):
        state.contacts.removeAll { $0.id == id }
        haptics.impact(.medium)

        return .run { send in
          do {
            try await contactRepository.removeContact(id)
          } catch {
            await send(.response(.failure(error)))
          }
        }

      case let .updateStatus(id, status):
        return .run { send in
          await send(.response(Result {
            try await contactRepository.updateContactStatus(id, status)
          }))
        }

      case let .response(.success(contact)):
        state.isLoading = false
        state.newContactPhone = ""
        haptics.notification(.success)

        if let index = state.contacts.firstIndex(where: { $0.id == contact.id }) {
          state.contacts[index] = contact
        } else {
          state.contacts.append(contact)
        }
        return .none

      case let .response(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        haptics.notification(.error)
        return .none

      case let .loadResponse(.success(contacts)):
        state.isLoading = false
        state.contacts = contacts
        return .none

      case let .loadResponse(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        return .none
      }
    }
  }
}

@Reducer
struct ProfileFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.currentUser) var currentUser: User?
    var editingUser: User?
    var isLoading = false
    var errorMessage: String?

    var isEditing: Bool { editingUser != nil }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case edit
    case save
    case cancel
    case uploadAvatar(Data)
    case response(Result<User, Error>)
    case uploadResponse(Result<URL, Error>)
  }

  @Dependency(\.userRepository) var userRepository
  @Dependency(\.validation) var validation
  @Dependency(\.haptics) var haptics

  var body: some Reducer<State, Action> {
    BindingReducer()

    Reduce { state, action in
      switch action {
      case .binding:
        state.errorMessage = nil
        return .none

      case .edit:
        state.editingUser = state.currentUser
        return .none

      case .save:
        guard let user = state.editingUser else { return .none }

        let nameValidation = validation.validateName(user.name)
        let phoneValidation = validation.validatePhoneNumber(user.phoneNumber)

        guard nameValidation.isValid else {
          state.errorMessage = nameValidation.errorMessage
          haptics.notification(.error)
          return .none
        }

        guard phoneValidation.isValid else {
          state.errorMessage = phoneValidation.errorMessage
          haptics.notification(.error)
          return .none
        }

        state.isLoading = true
        haptics.selection()

        return .run { send in
          await send(.response(Result {
            try await userRepository.updateProfile(user)
          }))
        }

      case .cancel:
        state.editingUser = nil
        haptics.selection()
        return .none

      case let .uploadAvatar(data):
        state.isLoading = true
        haptics.selection()

        return .run { send in
          await send(.uploadResponse(Result {
            try await userRepository.uploadAvatar(data)
          }))
        }

      case let .response(.success(user)):
        state.isLoading = false
        state.currentUser = user
        state.editingUser = nil
        haptics.notification(.success)
        return .none

      case let .response(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        haptics.notification(.error)
        return .none

      case let .uploadResponse(.success(url)):
        state.isLoading = false
        state.editingUser?.avatarURL = url.absoluteString
        haptics.notification(.success)
        return .none

      case let .uploadResponse(.failure(error)):
        state.isLoading = false
        state.errorMessage = error.localizedDescription
        haptics.notification(.error)
        return .none
      }
    }
  }
}

@Reducer
struct AppFeature {
  @ObservableState
  struct State: Equatable {
    @Shared(.currentUser) var currentUser: User?
    var selectedTab: Tab = .contacts
    var phoneVerification = PhoneVerificationFeature.State()
    var contacts = ContactFeature.State()
    var profile = ProfileFeature.State()

    var isLoggedIn: Bool { currentUser != nil }

    enum Tab: CaseIterable {
      case contacts, profile

      var title: String {
        switch self {
        case .contacts: return "Contacts"
        case .profile: return "Profile"
        }
      }

      var icon: String {
        switch self {
        case .contacts: return "person.2"
        case .profile: return "person"
        }
      }
    }
  }

  enum Action: BindableAction {
    case binding(BindingAction<State>)
    case onAppear
    case phoneVerification(PhoneVerificationFeature.Action)
    case contacts(ContactFeature.Action)
    case profile(ProfileFeature.Action)
  }

  @Dependency(\.userRepository) var userRepository

  var body: some Reducer<State, Action> {
    BindingReducer()

    Scope(state: \.phoneVerification, action: \.phoneVerification) {
      PhoneVerificationFeature()
    }
    Scope(state: \.contacts, action: \.contacts) {
      ContactFeature()
    }
    Scope(state: \.profile, action: \.profile) {
      ProfileFeature()
    }

    Reduce { state, action in
      switch action {
      case .onAppear:
        return .run { send in
          if let user = await userRepository.getCurrentUser() {
            await send(.phoneVerification(.response(.success(user))))
          }
        }

      case .phoneVerification(.response(.success(let user))):
        if !user.firebaseUID.isEmpty {
          state.currentUser = user
        }
        return .none

      case .binding, .phoneVerification, .contacts, .profile:
        return .none
      }
    }
  }
}

// MARK: - Views

struct AppView: View {
  @Bindable var store: StoreOf<AppFeature>

  var body: some View {
    if store.isLoggedIn {
      TabView(selection: $store.selectedTab) {
        ContactView(store: store.scope(state: \.contacts, action: \.contacts))
          .tabItem { Label("Contacts", systemImage: "person.2") }
          .tag(AppFeature.State.Tab.contacts)

        ProfileView(store: store.scope(state: \.profile, action: \.profile))
          .tabItem { Label("Profile", systemImage: "person") }
          .tag(AppFeature.State.Tab.profile)
      }
    } else {
      PhoneVerificationView(
        store: store.scope(state: \.phoneVerification, action: \.phoneVerification)
      )
    }
  }
}

struct PhoneVerificationView: View {
  @Bindable var store: StoreOf<PhoneVerificationFeature>

  var body: some View {
    NavigationView {
      Form {
        if !store.isCodeSent {
          Section("Enter Your Phone Number") {
            TextField("Phone Number", text: $store.phoneNumber)
              .textContentType(.telephoneNumber)
              .keyboardType(.phonePad)
          }

          Section {
            Button("Send Verification Code") {
              store.send(.sendVerificationCode)
            }
            .disabled(!store.canSendCode)
          }
        } else {
          Section("Enter Verification Code") {
            TextField("000000", text: $store.verificationCode)
              .textContentType(.oneTimeCode)
              .keyboardType(.numberPad)
              .multilineTextAlignment(.center)
              .font(.title2.monospacedDigit())
          }

          if store.isCreatingAccount {
            Section("Create Account") {
              TextField("Full Name", text: $store.name)
                .textContentType(.name)
                .autocapitalization(.words)
            }

            Section {
              Button("Create Account") {
                store.send(.createAccount)
              }
            }
          } else {
            Section {
              Button("Verify Code") {
                store.send(.verifyCode)
              }
              .disabled(!store.canVerifyCode)
            }
          }
        }

        if let error = store.errorMessage {
          Section {
            Text(error).foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Sign In")
      .disabled(store.isLoading)
    }
  }
}

struct ContactView: View {
  @Bindable var store: StoreOf<ContactFeature>
  @Dependency(\.validation) var validation

  var body: some View {
    NavigationView {
      List {
        Section {
          HStack {
            TextField("Phone Number", text: $store.newContactPhone)
              .textContentType(.telephoneNumber)
              .keyboardType(.phonePad)
              .onChange(of: store.newContactPhone) { _, newValue in
                store.newContactPhone = validation.formatPhoneNumber(newValue)
              }

            Button("Add") {
              store.send(.addContact)
            }
            .disabled(store.newContactPhone.isEmpty || store.isLoading)
          }
        }

        Section("Contacts") {
          ForEach(store.sortedContacts) { contact in
            HStack {
              VStack(alignment: .leading) {
                Text(contact.name)
                  .font(.headline)
                Text(validation.formatPhoneNumber(contact.phoneNumber))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }

              Spacer()

              Menu {
                ForEach(Contact.ContactStatus.allCases, id: \.self) { status in
                  Button(status.rawValue.capitalized) {
                    store.send(.updateStatus(contact.id, status))
                  }
                }
              } label: {
                Text(contact.status.rawValue.capitalized)
                  .font(.caption)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(statusColor(for: contact.status))
                  .foregroundColor(.white)
                  .cornerRadius(8)
              }
            }
            .swipeActions(edge: .trailing) {
              Button("Remove") {
                store.send(.removeContact(contact.id))
              }
              .tint(.red)
            }
          }
        }

        if let error = store.errorMessage {
          Section {
            Text(error).foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Contacts")
      .disabled(store.isLoading)
      .onAppear { store.send(.onAppear) }
    }
  }

  private func statusColor(for status: Contact.ContactStatus) -> Color {
    switch status {
    case .active: return .green
    case .away: return .yellow
    case .busy: return .red
    case .offline: return .gray
    }
  }
}

struct ProfileView: View {
  @Bindable var store: StoreOf<ProfileFeature>
  @Dependency(\.validation) var validation

  var body: some View {
    NavigationView {
      Form {
        if let user = store.currentUser {
          Section("Profile") {
            LabeledContent("Name", value: user.name)
            LabeledContent("Phone", value: validation.formatPhoneNumber(user.phoneNumber))
            if let avatar = user.avatarURL {
              LabeledContent("Avatar", value: avatar)
            }
          }

          if !store.isEditing {
            Section {
              Button("Edit") { store.send(.edit) }
            }
          }
        }

        if let editing = Binding($store.editingUser) {
          Section("Edit Profile") {
            TextField("Name", text: editing.name)
              .textContentType(.name)
              .autocapitalization(.words)

            TextField("Phone Number", text: editing.phoneNumber)
              .textContentType(.telephoneNumber)
              .keyboardType(.phonePad)
              .onChange(of: editing.phoneNumber.wrappedValue) { _, newValue in
                editing.phoneNumber.wrappedValue = validation.formatPhoneNumber(newValue)
              }

            Button("Upload Avatar") {
              // Mock data for avatar upload
              store.send(.uploadAvatar(Data()))
            }
          }

          Section {
            HStack {
              Button("Cancel") { store.send(.cancel) }
                .foregroundColor(.red)
              Spacer()
              Button("Save") { store.send(.save) }
            }
          }
        }

        if let error = store.errorMessage {
          Section {
            Text(error).foregroundColor(.red)
          }
        }
      }
      .navigationTitle("Profile")
      .disabled(store.isLoading)
    }
  }
}

// MARK: - App Entry Point

@main
struct UserApp: App {
  var body: some Scene {
    WindowGroup {
      AppView(
        store: Store(initialState: AppFeature.State()) {
          AppFeature()
        }
      )
    }
  }
}

// MARK: - Error Types

enum UserRepositoryError: Error, LocalizedError, Equatable {
  case networkError, authenticationFailed, userNotFound, updateFailed

  var errorDescription: String? {
    switch self {
    case .networkError: return "Network error occurred"
    case .authenticationFailed: return "Authentication failed"
    case .userNotFound: return "User not found"
    case .updateFailed: return "Update failed"
    }
  }
}

enum ContactRepositoryError: Error, LocalizedError {
  case networkError, contactNotFound, addFailed, updateFailed

  var errorDescription: String? {
    switch self {
    case .networkError: return "Network error occurred"
    case .contactNotFound: return "Contact not found"
    case .addFailed: return "Failed to add contact"
    case .updateFailed: return "Failed to update contact"
    }
  }
}

// MARK: - Mock gRPC Services

class MockUserService: UserServiceProtocol {
  func getUser(_ request: GetUserRequest) async throws -> User_Proto {
    User_Proto(
      id: UUID().uuidString,
      firebaseUID: request.firebaseUID,
      name: "Mock User",
      phoneNumber: "+1234567890",
      isNotificationsEnabled: true,
      avatarURL: "",
      lastModified: Int64(Date().timeIntervalSince1970)
    )
  }

  func createUser(_ request: CreateUserRequest) async throws -> User_Proto {
    User_Proto(
      id: UUID().uuidString,
      firebaseUID: request.firebaseUID,
      name: request.name,
      phoneNumber: request.phoneNumber,
      isNotificationsEnabled: request.isNotificationsEnabled,
      avatarURL: "",
      lastModified: Int64(Date().timeIntervalSince1970)
    )
  }

  func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto {
    User_Proto(
      id: UUID().uuidString,
      firebaseUID: request.firebaseUID,
      name: request.name,
      phoneNumber: request.phoneNumber,
      isNotificationsEnabled: request.isNotificationsEnabled,
      avatarURL: request.avatarURL,
      lastModified: Int64(Date().timeIntervalSince1970)
    )
  }

  func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse {
    UploadAvatarResponse(url: "https://test.com/avatar.jpg")
  }
}

class MockContactService: ContactServiceProtocol {
  func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
    GetContactsResponse(contacts: [
      Contact_Proto(
        id: UUID().uuidString,
        userID: UUID().uuidString,
        name: "John Doe",
        phoneNumber: "+1234567890",
        status: .active,
        lastUpdated: Int64(Date().timeIntervalSince1970)
      ),
      Contact_Proto(
        id: UUID().uuidString,
        userID: UUID().uuidString,
        name: "Jane Smith",
        phoneNumber: "+0987654321",
        status: .away,
        lastUpdated: Int64(Date().timeIntervalSince1970)
      )
    ])
  }

  func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
    Contact_Proto(
      id: UUID().uuidString,
      userID: UUID().uuidString,
      name: "New Contact",
      phoneNumber: request.phoneNumber,
      status: .active,
      lastUpdated: Int64(Date().timeIntervalSince1970)
    )
  }

  func updateContactStatus(_ request: UpdateContactStatusRequest) async throws -> Contact_Proto {
    Contact_Proto(
      id: request.contactID,
      userID: UUID().uuidString,
      name: "Updated Contact",
      phoneNumber: "+1234567890",
      status: request.status,
      lastUpdated: Int64(Date().timeIntervalSince1970)
    )
  }

  func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto {
    Empty_Proto()
  }
}

class LiveUserService: UserServiceProtocol {
  func getUser(_ request: GetUserRequest) async throws -> User_Proto {
    fatalError("Implement with real gRPC client")
  }

  func createUser(_ request: CreateUserRequest) async throws -> User_Proto {
    fatalError("Implement with real gRPC client")
  }

  func updateUser(_ request: UpdateUserRequest) async throws -> User_Proto {
    fatalError("Implement with real gRPC client")
  }

  func uploadAvatar(_ request: UploadAvatarRequest) async throws -> UploadAvatarResponse {
    fatalError("Implement with real gRPC client")
  }
}

class LiveContactService: ContactServiceProtocol {
  func getContacts(_ request: GetContactsRequest) async throws -> GetContactsResponse {
    fatalError("Implement with real gRPC client")
  }

  func addContact(_ request: AddContactRequest) async throws -> Contact_Proto {
    fatalError("Implement with real gRPC client")
  }

  func updateContactStatus(_ request: UpdateContactStatusRequest) async throws -> Contact_Proto {
    fatalError("Implement with real gRPC client")
  }

  func removeContact(_ request: RemoveContactRequest) async throws -> Empty_Proto {
    fatalError("Implement with real gRPC client")
  }
}
  var validation: ValidationClient {
    get { self[ValidationClient.self] }
    set { self[ValidationClient.self] = newValue }
  }

  var firebaseAuth: FirebaseAuthClient {
    get { self[FirebaseAuthClient.self] }
    set { self[FirebaseAuthClient.self] = newValue }
  }

  var apiClient: APIClient {
    get { self[APIClient.self] }
    set { self[APIClient.self] = newValue }
  }

  var notifications: NotificationClient {
    get { self[NotificationClient.self] }
    set { self[NotificationClient.self] = newValue }
  }

  var haptics: HapticClient {
    get { self[HapticClient.self] }
    set { self[HapticClient.self] = newValue }
  }

  var userRepository: UserRepository {
    get { self[UserRepository.self] }
    set { self[UserRepository.self] = newValue }
  }

  var contactRepository: ContactRepository {
    get { self[ContactRepository.self] }
    set { self[ContactRepository.self] = newValue }
  }
}

// MARK: - Preview

#Preview("Logged In") {
  AppView(
    store: Store(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.grpcClient = GRPCClient(
        userService: MockUserService(),
        contactService: MockContactService()
      )
      $0[PersistenceKey.currentUser] = User(
        id: UUID(),
        firebaseUID: "preview",
        name: "Preview User",
        phoneNumber: "+1234567890"
      )
      $0[PersistenceKey.contacts] = [
        Contact(id: UUID(), userID: UUID(), name: "Alice", phoneNumber: "+1234567890", status: .active, lastUpdated: Date()),
        Contact(id: UUID(), userID: UUID(), name: "Bob", phoneNumber: "+0987654321", status: .away, lastUpdated: Date())
      ]
    }
  )
}

#Preview("Auth") {
  AppView(
    store: Store(initialState: AppFeature.State()) {
      AppFeature()
    } withDependencies: {
      $0.grpcClient = GRPCClient(
        userService: MockUserService(),
        contactService: MockContactService()
      )
    }
  )
}
```