import SwiftUI
import Foundation
import PhotosUI
import ComposableArchitecture
import Perception
import UIKit


@Reducer
struct ProfileFeature {
    @ObservableState
    struct State: Equatable {
        @Shared(.userState) var userState: ReadOnlyUserState
        @Shared(.authenticationInternalState) var authState: ReadOnlyAuthenticationState
        
        var currentUser: User? { userState.currentUser }
        var avatarImageData: AvatarImageWithMetadata? { userState.avatarImage }
        
        
        // Sheet states to match mock UI
        var showEditDescriptionSheet = false
        var showEditNameSheet = false
        var showEditAvatarSheet = false
        var showPhoneNumberChangeSheet = false
        var showSignOutConfirmation = false
        var showDeleteAccountConfirmation = false
        var showDeleteAvatarConfirmation = false
        var showImagePicker = false
        
        // Editing states
        var newDescription = ""
        var newName = ""
        var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.currentUser == rhs.currentUser &&
            lhs.authState == rhs.authState &&
            lhs.avatarImageData == rhs.avatarImageData &&
            lhs.showEditDescriptionSheet == rhs.showEditDescriptionSheet &&
            lhs.showEditNameSheet == rhs.showEditNameSheet &&
            lhs.showEditAvatarSheet == rhs.showEditAvatarSheet &&
            lhs.showPhoneNumberChangeSheet == rhs.showPhoneNumberChangeSheet &&
            lhs.showSignOutConfirmation == rhs.showSignOutConfirmation &&
            lhs.showDeleteAccountConfirmation == rhs.showDeleteAccountConfirmation &&
            lhs.showDeleteAvatarConfirmation == rhs.showDeleteAvatarConfirmation &&
            lhs.showImagePicker == rhs.showImagePicker &&
            lhs.newDescription == rhs.newDescription &&
            lhs.newName == rhs.newName &&
            lhs.imagePickerSourceType.rawValue == rhs.imagePickerSourceType.rawValue &&
            lhs.phoneVerificationID == rhs.phoneVerificationID &&
            lhs.isPhoneVerificationStep == rhs.isPhoneVerificationStep &&
            lhs.textEditorFocused == rhs.textEditorFocused &&
            lhs.nameFieldFocused == rhs.nameFieldFocused &&
            lhs.phoneNumberEntry == rhs.phoneNumberEntry &&
            lhs.verificationCodeEntry == rhs.verificationCodeEntry
        }
        
        // Phone number change states
        var phoneVerificationID: String? = nil
        var isPhoneVerificationStep = false
        
        // Focus states for sync with SwiftUI
        var textEditorFocused = false
        var nameFieldFocused = false
        
        // Available regions for phone number
        static let phoneRegions: [(String, String)] = [
            ("US", "+1"),
            ("CA", "+1"),
            ("UK", "+44"),
            ("AU", "+61")
        ]
        
        // Child feature states for phone number change
        var phoneNumberEntry = PhoneNumberEntryFeature.State(
            selectedRegion: "US",
            regions: ProfileFeature.State.phoneRegions,
            buttonTitle: "Send Verification Code"
        )
        
        var verificationCodeEntry = VerificationCodeEntryFeature.State(
            buttonTitle: "Verify Code"
        )
        
        var isUsingDefaultAvatar: Bool {
            avatarImageData == nil
        }
        
        var currentAvatarImage: UIImage? {
            guard let imageData = avatarImageData?.image else { return nil }
            return UIImage(data: imageData)
        }
        
        
    }
    
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        
        // Profile editing
        case prepareEditDescription
        case saveEditedDescription
        case cancelEditDescription
        case prepareEditName  
        case saveEditedName
        case cancelEditName
        
        // Avatar management
        case showAvatarEditor
        case setAvatarImage(UIImage)
        case deleteAvatarImage
        case showImagePickerWithSourceType(UIImagePickerController.SourceType)
        
        // Phone number management
        case showPhoneNumberChange
        case cancelPhoneNumberChange
        case resetPhoneNumberFlow
        
        // Child feature actions
        case phoneNumberEntry(PhoneNumberEntryFeature.Action)
        case verificationCodeEntry(VerificationCodeEntryFeature.Action)
        
        // Authentication
        case confirmSignOut
        case signOut
        case confirmDeleteAccount
        case deleteAccount
        
        // Focus states
        case handleTextEditorFocusChange(Bool)
        case handleNameFieldFocusChange(Bool)
        
        // Network responses
        case updateResponse(Result<Void, Error>)
        case uploadAvatarResponse(Result<URL, Error>)
        case phoneVerificationSent(Result<String, Error>)
        case phoneNumberChanged(Result<Void, Error>)
        
        // Delegate actions
        @CasePathable
        enum Delegate {
            case signOutRequested
            case deleteAccountRequested
        }
        case delegate(Delegate)
    }
    
    @Dependency(\.userClient) var userClient
    @Dependency(\.authenticationClient) var authenticationClient
    @Dependency(\.onboardingClient) var onboardingClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationClient) var notificationClient
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter
    
    var body: some ReducerOf<Self> {
        Scope(state: \.phoneNumberEntry, action: \.phoneNumberEntry) {
            PhoneNumberEntryFeature()
        }
        
        Scope(state: \.verificationCodeEntry, action: \.verificationCodeEntry) {
            VerificationCodeEntryFeature()
        }
        
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .prepareEditDescription:
                state.newDescription = state.currentUser?.emergencyNote ?? ""
                state.showEditDescriptionSheet = true
                state.textEditorFocused = true
                return .run { _ in
                    await haptics.impact(.light)
                }

            case .prepareEditName:
                state.newName = state.currentUser?.name ?? ""
                state.showEditNameSheet = true
                state.nameFieldFocused = true
                return .run { _ in
                    await haptics.impact(.light)
                }

            case .showAvatarEditor:
                state.showEditAvatarSheet = true
                return .run { _ in
                    await haptics.impact(.light)
                }

            case .showPhoneNumberChange:
                state.phoneNumberEntry.phoneNumber = ""
                state.verificationCodeEntry.verificationCode = ""
                state.phoneVerificationID = nil
                state.isPhoneVerificationStep = false
                state.phoneNumberEntry.selectedRegion = "US"
                state.showPhoneNumberChangeSheet = true
                state.phoneNumberEntry.phoneNumberFieldFocused = true
                return .run { _ in
                    await haptics.impact(.light)
                }
                
            case .cancelPhoneNumberChange:
                state.showPhoneNumberChangeSheet = false
                state.phoneNumberEntry.phoneNumber = ""
                state.verificationCodeEntry.verificationCode = ""
                state.phoneVerificationID = nil
                state.isPhoneVerificationStep = false
                return .run { _ in
                    await haptics.impact(.light)
                }
                
            case .resetPhoneNumberFlow:
                state.isPhoneVerificationStep = false
                state.verificationCodeEntry.verificationCode = ""
                state.phoneVerificationID = nil
                return .none
                
            // Handle child feature delegate actions
            case .phoneNumberEntry(.delegate(.buttonTapped)):
                guard !state.phoneNumberEntry.phoneNumber.isEmpty else {
                    return .run { [notificationClient, haptics] _ in
                        try? await notificationClient.sendSystemNotification(
                            "Phone Number Required",
                            "Please enter a phone number to continue."
                        )
                        await haptics.notification(.error)
                    }
                }
                
                return .run { [phoneNumber = state.phoneNumberEntry.phoneNumber, authenticationClient] send in
                    await send(.phoneVerificationSent(
                        Result {
                            try await authenticationClient.sendPhoneChangeVerificationCode(phoneNumber)
                        }
                    ))
                }
                
            case .verificationCodeEntry(.delegate(.buttonTapped)):
                guard !state.verificationCodeEntry.verificationCode.isEmpty else {
                    return .run { [notificationClient, haptics] _ in
                        try? await notificationClient.sendSystemNotification(
                            "Verification Code Required",
                            "Please enter the 6-digit verification code."
                        )
                        await haptics.notification(.error)
                    }
                }
                
                guard let verificationID = state.phoneVerificationID else {
                    return .run { [notificationClient, haptics] _ in
                        try? await notificationClient.sendSystemNotification(
                            "Session Expired",
                            "Verification session expired. Please request a new code."
                        )
                        await haptics.notification(.error)
                    }
                }
                
                return .run { [verificationID = verificationID, code = state.verificationCodeEntry.verificationCode, authenticationClient] send in
                    await send(.phoneNumberChanged(
                        Result {
                            try await authenticationClient.changePhoneNumber(verificationID, code)
                        }
                    ))
                }
                
            case .phoneNumberEntry:
                return .none
                
            case .verificationCodeEntry:
                return .none

            case .confirmSignOut:
                state.showSignOutConfirmation = true
                return .run { _ in
                    await haptics.impact(.medium)
                }

            case .signOut:
                state.showSignOutConfirmation = false
                return .send(.delegate(.signOutRequested))
                
            case .confirmDeleteAccount:
                state.showDeleteAccountConfirmation = true
                return .run { _ in
                    await haptics.impact(.heavy)
                }

            case .deleteAccount:
                state.showDeleteAccountConfirmation = false
                return .send(.delegate(.deleteAccountRequested))

            case .saveEditedDescription:
                let trimmedDescription = state.newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard var user = state.currentUser else {
                    return .run { [notificationClient, haptics] _ in
                        try? await notificationClient.sendSystemNotification(
                            "Profile Update Issue",
                            "Unable to update emergency note. Please try again."
                        )
                        await haptics.notification(.error)
                    }
                }
                
                user.emergencyNote = trimmedDescription
                user.lastModified = Date()
                
                state.showEditDescriptionSheet = false
                
                return .run { [userClient, user, authToken = state.authState.authenticationToken] send in
                    await send(.updateResponse(Result {
                        guard let token = authToken else {
                            throw UserClientError.authenticationFailed("Missing authentication token")
                        }
                        try await userClient.updateUser(user, token)
                    }))
                }

            case .cancelEditDescription:
                state.showEditDescriptionSheet = false
                state.newDescription = ""
                return .run { _ in
                    await haptics.impact(.light)
                }

            case .saveEditedName:
                let trimmedName = state.newName.trimmingCharacters(in: .whitespacesAndNewlines)
                
                let validationResult = onboardingClient.validateName(trimmedName)
                guard validationResult.isValid else {
                    return .run { [notificationClient, haptics, errorMessage = validationResult.errorMessage] _ in
                        try? await notificationClient.sendSystemNotification(
                            "Name Validation Issue",
                            errorMessage ?? "Please check your name format."
                        )
                        await haptics.notification(.error)
                    }
                }
                
                guard var user = state.currentUser else {
                    return .run { [haptics] _ in
                        await haptics.notification(.error)
                    }
                }
                
                user.name = trimmedName
                user.lastModified = Date()
                
                state.showEditNameSheet = false
                
                return .run { [userClient, user, authToken = state.authState.authenticationToken] send in
                    await send(.updateResponse(Result {
                        guard let token = authToken else {
                            throw UserClientError.authenticationFailed("Missing authentication token")
                        }
                        try await userClient.updateUser(user, token)
                    }))
                }

            case .cancelEditName:
                state.showEditNameSheet = false
                state.newName = ""
                return .run { _ in
                    await haptics.impact(.light)
                }

            case let .setAvatarImage(image):
                guard let user = state.currentUser else {
                    return .run { [haptics] _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.showEditAvatarSheet = false
                state.showImagePicker = false
                
                return .run { [userClient, notificationClient, userID = user.id, authToken = state.authState.authenticationToken] send in
                    await send(.updateResponse(Result {
                        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                            throw UserClientError.operationFailed
                        }
                        
                        guard let token = authToken else {
                            throw UserClientError.authenticationFailed("Missing authentication token")
                        }
                        
                        try await userClient.updateAvatarData(userID, imageData, token)
                        
                        try? await notificationClient.sendSystemNotification(
                            "Avatar Updated",
                            "Your profile avatar has been successfully updated."
                        )
                        
                    }))
                }

            case .deleteAvatarImage:
                guard let user = state.currentUser else {
                    return .run { [haptics] _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.showDeleteAvatarConfirmation = false
                state.showEditAvatarSheet = false
                
                return .run { [userClient, notificationClient, userID = user.id, authToken = state.authState.authenticationToken] send in
                    await send(.updateResponse(Result {
                        guard let token = authToken else {
                            throw UserClientError.authenticationFailed("Missing authentication token")
                        }
                        
                        try await userClient.deleteAvatarData(userID, token)
                        
                        try? await notificationClient.sendSystemNotification(
                            "Avatar Deleted",
                            "Your profile avatar has been successfully deleted."
                        )
                        
                    }))
                }

            case let .showImagePickerWithSourceType(sourceType):
                state.imagePickerSourceType = sourceType
                state.showEditAvatarSheet = false // Dismiss avatar sheet first
                state.showImagePicker = true
                return .run { _ in
                    await haptics.impact(.light)
                }

            case let .handleTextEditorFocusChange(focused):
                state.textEditorFocused = focused
                return .none

            case let .handleNameFieldFocusChange(focused):
                state.nameFieldFocused = focused
                return .none
                

            case .updateResponse(.success):
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    
                    try? await notificationClient.sendSystemNotification(
                        "Profile Updated",
                        "Your profile information has been successfully updated."
                    )
                }

            case let .updateResponse(.failure(error)):
                return .run { [errorMessage = error.localizedDescription, haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    
                    try? await notificationClient.sendSystemNotification(
                        "Profile Update Failed",
                        "Failed to update profile: \(errorMessage)"
                    )
                }

            case let .uploadAvatarResponse(.success(url)):
                guard var user = state.currentUser else { return .none }
                user.avatarURL = url.absoluteString
                let updatedUser = user
                return .run { [userClient, authToken = state.authState.authenticationToken] send in
                    await send(.updateResponse(Result {
                        guard let token = authToken else {
                            throw UserClientError.authenticationFailed("Missing authentication token")
                        }
                        try await userClient.updateUser(updatedUser, token)
                    }))
                }

            case .uploadAvatarResponse(.failure(_)):
                return .run { [haptics] _ in
                    await haptics.notification(.error)
                }
                
            case let .phoneVerificationSent(.success(verificationID)):
                state.phoneVerificationID = verificationID
                state.isPhoneVerificationStep = true
                state.verificationCodeEntry.verificationCodeFieldFocused = true
                return .run { [phoneNumber = state.phoneNumberEntry.phoneNumber, haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    
                    try? await notificationClient.sendSystemNotification(
                        "Verification Code Sent",
                        "A verification code has been sent to \(phoneNumber)"
                    )
                }
                
            case let .phoneVerificationSent(.failure(error)):
                return .run { [errorMessage = error.localizedDescription, haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    
                    try? await notificationClient.sendSystemNotification(
                        "Verification Failed",
                        "Failed to send verification code: \(errorMessage)"
                    )
                }
                
            case .phoneNumberChanged(.success):
                state.showPhoneNumberChangeSheet = false
                let changedPhoneNumber = state.phoneNumberEntry.phoneNumber
                state.phoneNumberEntry.phoneNumber = ""
                state.verificationCodeEntry.verificationCode = ""
                state.phoneVerificationID = nil
                state.isPhoneVerificationStep = false
                return .run { [haptics, notificationClient] _ in
                    await haptics.notification(.success)
                    
                    try? await notificationClient.sendSystemNotification(
                        "Phone Number Updated",
                        "Your phone number has been successfully changed to \(changedPhoneNumber)"
                    )
                }
                
            case let .phoneNumberChanged(.failure(error)):
                return .run { [errorMessage = error.localizedDescription, haptics, notificationClient] _ in
                    await haptics.notification(.error)
                    
                    try? await notificationClient.sendSystemNotification(
                        "Phone Number Change Failed",
                        "Failed to change phone number: \(errorMessage)"
                    )
                }
                
            case .delegate:
                return .none
            }
        }
    }
}

/// A UIViewControllerRepresentable for picking images from the photo library or camera
struct ImagePicker: UIViewControllerRepresentable {
    /// The source type for the image picker (camera or photo library)
    var sourceType: UIImagePickerController.SourceType

    /// Callback for when an image is selected
    var selectedImage: (UIImage?) -> Void

    /// Create the UIImagePickerController
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        return picker
    }

    /// Update the UIImagePickerController (not used)
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    /// Create the coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    /// Coordinator class for handling UIImagePickerController delegate methods
    class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        /// The parent ImagePicker
        let parent: ImagePicker

        /// Initialize with the parent ImagePicker
        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        /// Handle image picker controller did finish picking media
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage(image)
            } else {
                parent.selectedImage(nil)
            }
            picker.dismiss(animated: true)
        }

        /// Handle image picker controller did cancel
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.selectedImage(nil)
            picker.dismiss(animated: true)
        }
    }
}


// MARK: - Main Profile View
struct ProfileView: View {
    @Bindable var store: StoreOf<ProfileFeature>
    
    // Focus states bound to store
    @FocusState private var textEditorFocused: Bool
    @FocusState private var nameFieldFocused: Bool
    @State private var textEditorHeight: CGFloat = 72
    
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter


    @ViewBuilder
    private func profileHeader() -> some View {
        VStack(spacing: 16) {
            if let user = store.currentUser {
                CommonAvatarView(
                    name: user.name,
                    image: store.currentAvatarImage,
                    size: 100,
                    backgroundColor: Color.blue.opacity(0.1),
                    textColor: .blue,
                    strokeWidth: 2,
                    strokeColor: .blue
                )
                .padding(.top)
                Text(user.name)
                    .font(.headline)
                Text(user.phoneNumber.isEmpty ? "(954) 234-5678" : phoneNumberFormatter.formatPhoneNumberForDisplay(user.phoneNumber))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func descriptionCard(_ user: User) -> some View {
        Button(action: {
            store.send(.prepareEditDescription, animation: .default)
        }) {
            HStack(alignment: .top) {
                Text(user.emergencyNote.isEmpty ? "Your emergency note is empty" : user.emergencyNote)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func updateCards() -> some View {
        VStack(spacing: 0) {
            Button(action: {
                store.send(.showAvatarEditor, animation: .default)
            }) {
                HStack {
                    Text("Update Avatar")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
            }
            Divider().padding(.leading)
            Button(action: {
                store.send(.prepareEditName, animation: .default)
            }) {
                HStack {
                    Text("Update Name")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func mainContent(_ user: User) -> some View {
        VStack(spacing: 16) {
            profileHeader()
            descriptionCard(user)
            updateCards()
            
            Button(action: {
                store.send(.showPhoneNumberChange, animation: .default)
            }) {
                HStack {
                    Text("Change Phone Number")
                        .font(.body)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Button(action: {
                store.send(.confirmSignOut, animation: .default)
            }) {
                Text("Sign Out")
                    .font(.body)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            
            Button(action: {
                store.send(.confirmDeleteAccount, animation: .default)
            }) {
                Text("Delete Account")
                    .font(.body)
                    .foregroundColor(.red)
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }

    var body: some View {
        WithPerceptionTracking {
            setupLifecycle()
        }
    }
    
    @ViewBuilder
    private var contentView: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
            
            ScrollView {
                if let user = store.currentUser {
                    mainContent(user)
                } else {
                    VStack {
                        ProgressView()
                        Text("Loading profile...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - View Extensions
extension View {
    @ViewBuilder
    fileprivate func setupSheets() -> some View {
        self
    }
    
    @ViewBuilder
    fileprivate func setupAlerts() -> some View {
        self
    }
    
    @ViewBuilder
    fileprivate func setupLifecycle() -> some View {
        self
    }
}

extension ProfileView {
    @ViewBuilder
    private func setupSheets() -> some View {
        contentView
            .sheet(isPresented: $store.showEditDescriptionSheet) {
                emergencyNoteSheetView()
            }
            .sheet(isPresented: $store.showEditNameSheet) {
                nameEditSheetView()
            }
            .sheet(isPresented: $store.showEditAvatarSheet) {
                avatarEditSheetView()
            }
            .sheet(isPresented: $store.showPhoneNumberChangeSheet) {
                phoneNumberChangeSheetView()
            }
            .sheet(isPresented: $store.showImagePicker) {
                ImagePicker(sourceType: store.imagePickerSourceType, selectedImage: { image in
                    if let image = image {
                        store.send(.setAvatarImage(image))
                    }
                })
            }
    }
    
    @ViewBuilder
    private func setupAlerts() -> some View {
        setupSheets()
            .alert("Sign Out", isPresented: $store.showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    store.send(.signOut, animation: .default)
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $store.showDeleteAccountConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Account", role: .destructive) {
                    store.send(.deleteAccount, animation: .default)
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
            .alert("Delete Avatar", isPresented: $store.showDeleteAvatarConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    store.send(.deleteAvatarImage, animation: .default)
                }
            } message: {
                Text("Are you sure you want to delete your avatar photo?")
            }
    }
    
    @ViewBuilder
    private func setupLifecycle() -> some View {
        setupAlerts()
            .onAppear {
                textEditorFocused = store.textEditorFocused
                nameFieldFocused = store.nameFieldFocused
            }
            .onChange(of: textEditorFocused) { _, newValue in
                store.send(.handleTextEditorFocusChange(newValue))
            }
            .onChange(of: store.textEditorFocused) { _, newValue in
                textEditorFocused = newValue
            }
            .onChange(of: nameFieldFocused) { _, newValue in
                store.send(.handleNameFieldFocusChange(newValue))
            }
            .onChange(of: store.nameFieldFocused) { _, newValue in
                nameFieldFocused = newValue
            }
    }

    // MARK: - Emergency Note Sheet View
    @ViewBuilder
    private func emergencyNoteSheetView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $store.newDescription)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(minHeight: max(72, textEditorHeight))
                        .padding(.vertical, 4)
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .focused($textEditorFocused)
                        .onAppear {
                            updateTextEditorHeight(for: store.newDescription)
                        }
                        .onChange(of: store.newDescription) { _, newValue in
                            updateTextEditorHeight(for: newValue)
                        }
                    Text("This note is visible to your contacts when they view your profile.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                Spacer(minLength: 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Emergency Note")
            .navigationBarItems(
                leading: Button("Cancel") {
                    store.send(.cancelEditDescription, animation: .default)
                },
                trailing: Button("Save") {
                    store.send(.saveEditedDescription, animation: .default)
                }
                .disabled(store.newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          store.newDescription == (store.currentUser?.emergencyNote ?? ""))
            )
            .background(Color(UIColor.systemGroupedBackground))
        }
        .presentationDetents([.large])
    }

    // MARK: - Name Edit Sheet View
    @ViewBuilder
    private func nameEditSheetView() -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $store.newName)
                        .font(.body)
                        .padding(.vertical, 12)
                        .padding(.horizontal)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .foregroundColor(.primary)
                        .focused($nameFieldFocused)
                    Text("People will see this name if you interact with them and they don't have you saved as a contact.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal)
                .padding(.top, 24)
                Spacer(minLength: 0)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Name")
            .navigationBarItems(
                leading: Button("Cancel") {
                    store.send(.cancelEditName, animation: .default)
                },
                trailing: Button("Save") {
                    store.send(.saveEditedName, animation: .default)
                }
                .disabled(store.newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                          store.newName == (store.currentUser?.name ?? ""))
            )
        }
    }

    // MARK: - Avatar Edit Sheet View
    @ViewBuilder
    private func avatarEditSheetView() -> some View {
        VStack(spacing: 20) {
            Text("Avatar")
                .font(.headline.bold())
                .foregroundColor(.primary)
            VStack(spacing: 0) {
                Button(action: {
                    store.send(.showImagePickerWithSourceType(.photoLibrary), animation: .default)
                }) {
                    HStack {
                        Text("Choose photo")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "photo")
                            .foregroundColor(.primary)
                    }
                    .padding()
                }
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .padding(.horizontal)
            Button(action: {
                store.showDeleteAvatarConfirmation = true
            }) {
                HStack {
                    Text("Delete avatar photo")
                        .foregroundColor(.red)
                    Spacer()
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .padding(.horizontal)
            .disabled(store.isUsingDefaultAvatar)
            .opacity(store.isUsingDefaultAvatar ? 0.5 : 1.0)
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .background(Color(UIColor.systemGroupedBackground))
        .presentationDetents([.medium])
    }
    
    // MARK: - Phone Number Change Sheet View
    @ViewBuilder
    private func phoneNumberChangeSheetView() -> some View {
        NavigationStack {
            ZStack {
                // Background that fills the entire view
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack {
                        // Main content container
                        if !store.isPhoneVerificationStep {
                            phoneNumberEntryView()
                        } else {
                            phoneVerificationView()
                        }

                        Spacer(minLength: 0)

                        // Add extra padding at the bottom to ensure content doesn't overlap with keyboard
                        Spacer().frame(height: 50)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Change Phone Number")
            .toolbarBackground(Color(UIColor.systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        store.send(.cancelPhoneNumberChange, animation: .default)
                    }
                }
            }
        }
        .ignoresSafeArea(.keyboard)
    }
    
    @ViewBuilder
    private func phoneNumberEntryView() -> some View {
        // Initial phone number change view
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Phone Number")
                .font(.headline)
                .padding(.horizontal, 4)

            Text(store.currentUser?.phoneNumber.isEmpty == false ? phoneNumberFormatter.formatPhoneNumberWithRegionCode(store.currentUser!.phoneNumber) : "+1 (954) 234-5678")
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)

            Text("New Phone Number")
                .font(.headline)
                .padding(.horizontal, 4)
                .padding(.top, 8)

            PhoneNumberEntryView(
                store: store.scope(state: \.phoneNumberEntry, action: \.phoneNumberEntry)
            )
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private func phoneVerificationView() -> some View {
        // Verification code view
        VStack(alignment: .leading, spacing: 16) {
            Text("Verification Code")
                .font(.headline)
                .padding(.horizontal, 4)

            Text("Sent to \(store.phoneNumberEntry.phoneNumber)")
                .font(.body)
                .padding(.horizontal, 4)

            VerificationCodeEntryView(
                store: store.scope(state: \.verificationCodeEntry, action: \.verificationCodeEntry)
            )
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
    
    private func updateTextEditorHeight(for text: String) {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let lineHeight = font.lineHeight
        let padding: CGFloat = 16 // Account for internal padding
        
        // Calculate approximate height based on text content
        let size = text.boundingRect(
            with: CGSize(width: UIScreen.main.bounds.width - 64, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        
        let calculatedHeight = max(72, size.height + padding)
        textEditorHeight = calculatedHeight
    }
}
