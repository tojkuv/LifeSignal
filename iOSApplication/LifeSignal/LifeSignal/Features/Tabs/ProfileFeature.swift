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
        @Shared(.currentUser) var currentUser: User? = nil
        @Shared(.sessionState) var sessionState: SessionState = .unauthenticated
        @Shared(.userAvatarImage) var avatarImageData: AvatarImageWithMetadata? = nil
        
        var isLoading = false
        var errorMessage: String?
        
        // Sheet states to match mock UI
        var showEditDescriptionSheet = false
        var showEditNameSheet = false
        var showEditAvatarSheet = false
        var showPhoneNumberChangeSheet = false
        var showSignOutConfirmation = false
        var showDeleteAvatarConfirmation = false
        var showImagePicker = false
        
        // Editing states
        var newDescription = ""
        var newName = ""
        var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
        
        // Phone number change states
        var newPhoneNumber = ""
        var phoneVerificationCode = ""
        var phoneVerificationID: String? = nil
        var isPhoneVerificationStep = false
        var selectedPhoneRegion = "US"
        var showPhoneRegionPicker = false
        
        // Focus states for sync with SwiftUI
        var textEditorFocused = false
        var nameFieldFocused = false
        var phoneNumberFieldFocused = false
        var phoneVerificationCodeFieldFocused = false
        
        // Available regions for phone number
        static let phoneRegions: [(String, String)] = [
            ("US", "+1"),
            ("CA", "+1"),
            ("UK", "+44"),
            ("AU", "+61")
        ]
        
        var isUsingDefaultAvatar: Bool {
            avatarImageData == nil
        }
        
        var currentAvatarImage: UIImage? {
            guard let imageData = avatarImageData?.image else { return nil }
            return UIImage(data: imageData)
        }
        
        var phoneNumberPlaceholder: String {
            let selectedRegionInfo = Self.phoneRegions.first { $0.0 == selectedPhoneRegion }!
            return "\(selectedRegionInfo.1) (000) 000-0000"
        }
        
        var canSendPhoneVerification: Bool {
            isPhoneNumberValid && !isLoading
        }
        
        var canVerifyPhoneCode: Bool {
            isVerificationCodeValid && !isLoading
        }
        
        var isPhoneNumberValid: Bool {
            let digitCount = newPhoneNumber.filter { $0.isNumber }.count
            return digitCount == 10 || newPhoneNumber == "+11234567890" // Allow dev testing
        }
        
        var isVerificationCodeValid: Bool {
            phoneVerificationCode.filter { $0.isNumber }.count == 6
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
        case togglePhoneRegionPicker
        case updateSelectedPhoneRegion((String, String))
        case handlePhoneNumberChange(String)
        case sendPhoneVerificationCode
        case handlePhoneVerificationCodeChange(String)
        case verifyPhoneNumber
        case resetPhoneNumberFlow
        
        // Authentication
        case confirmSignOut
        case signOut
        
        // Focus states
        case handleTextEditorFocusChange(Bool)
        case handleNameFieldFocusChange(Bool)
        case handlePhoneNumberFieldFocusChange(Bool)
        case handlePhoneVerificationCodeFieldFocusChange(Bool)
        
        // Network responses
        case updateResponse(Result<User, Error>)
        case uploadAvatarResponse(Result<URL, Error>)
        case phoneVerificationSent(Result<String, Error>)
        case phoneNumberChanged(Result<Void, Error>)
    }
    
    @Dependency(\.userClient) var userClient
    @Dependency(\.sessionClient) var sessionClient
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.notificationClient) var notificationClient
    
    var body: some ReducerOf<Self> {
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
                state.newPhoneNumber = ""
                state.phoneVerificationCode = ""
                state.phoneVerificationID = nil
                state.isPhoneVerificationStep = false
                state.selectedPhoneRegion = "US"
                state.showPhoneNumberChangeSheet = true
                state.phoneNumberFieldFocused = true
                return .run { _ in
                    await haptics.impact(.light)
                }
                
            case .cancelPhoneNumberChange:
                state.showPhoneNumberChangeSheet = false
                state.newPhoneNumber = ""
                state.phoneVerificationCode = ""
                state.phoneVerificationID = nil
                state.isPhoneVerificationStep = false
                state.errorMessage = nil
                return .run { _ in
                    await haptics.impact(.light)
                }
                
            case .togglePhoneRegionPicker:
                state.showPhoneRegionPicker.toggle()
                return .none
                
            case let .updateSelectedPhoneRegion(region):
                state.selectedPhoneRegion = region.0
                state.showPhoneRegionPicker = false
                return .none
                
            case let .handlePhoneNumberChange(newValue):
                state.newPhoneNumber = newValue
                return .none
                
            case .sendPhoneVerificationCode:
                guard !state.newPhoneNumber.isEmpty else {
                    state.errorMessage = "Please enter a phone number"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                // Validate phone number using SessionClient
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [phoneNumber = state.newPhoneNumber] send in
                    await send(.phoneVerificationSent(
                        Result {
                            try await sessionClient.sendPhoneChangeVerificationCode(phoneNumber)
                        }
                    ))
                }
                
            case let .handlePhoneVerificationCodeChange(newValue):
                state.phoneVerificationCode = newValue
                return .none
                
            case .verifyPhoneNumber:
                guard !state.phoneVerificationCode.isEmpty else {
                    state.errorMessage = "Please enter the verification code"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                guard let verificationID = state.phoneVerificationID else {
                    state.errorMessage = "Verification session expired. Please try again."
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.isLoading = true
                state.errorMessage = nil
                
                return .run { [verificationID = verificationID, code = state.phoneVerificationCode] send in
                    await send(.phoneNumberChanged(
                        Result {
                            try await sessionClient.changePhoneNumber(verificationID, code)
                        }
                    ))
                }
                
            case .resetPhoneNumberFlow:
                state.isPhoneVerificationStep = false
                state.phoneVerificationCode = ""
                state.phoneVerificationID = nil
                state.errorMessage = nil
                return .none

            case .confirmSignOut:
                state.showSignOutConfirmation = true
                return .run { _ in
                    await haptics.impact(.medium)
                }

            case .signOut:
                state.showSignOutConfirmation = false
                return .run { _ in
                    do {
                        try await sessionClient.endSession()
                        await haptics.notification(.success)
                        
                        // Send notification for successful sign out
                        let notification = NotificationItem(
                            title: "Signed Out",
                            message: "You have been successfully signed out of your account.",
                            type: .system
                        )
                        try? await notificationClient.sendNotification(notification)
                    } catch {
                        // Handle error silently, session cleanup should still happen
                        await haptics.notification(.error)
                        
                        // Send notification for sign out error
                        let notification = NotificationItem(
                            title: "Sign Out Issue",
                            message: "There was an issue signing out, but you have been logged out locally.",
                            type: .system
                        )
                        try? await notificationClient.sendNotification(notification)
                    }
                }

            case .saveEditedDescription:
                let trimmedDescription = state.newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                guard var user = state.currentUser else {
                    state.errorMessage = "User not found"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                user.emergencyNote = trimmedDescription
                user.lastModified = Date()
                
                state.showEditDescriptionSheet = false
                state.isLoading = true
                
                return .run { send in
                    await send(.updateResponse(Result {
                        try await userClient.updateUser(user)
                        return user
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
                
                let validationResult = sessionClient.validateName(trimmedName)
                guard validationResult.isValid else {
                    state.errorMessage = validationResult.errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                guard var user = state.currentUser else {
                    state.errorMessage = "User not found"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                user.name = trimmedName
                user.lastModified = Date()
                
                state.showEditNameSheet = false
                state.isLoading = true
                
                return .run { send in
                    await send(.updateResponse(Result {
                        try await userClient.updateUser(user)
                        return user
                    }))
                }

            case .cancelEditName:
                state.showEditNameSheet = false
                state.newName = ""
                return .run { _ in
                    await haptics.impact(.light)
                }

            case let .setAvatarImage(image):
                guard var user = state.currentUser else {
                    state.errorMessage = "User not found"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.showEditAvatarSheet = false
                state.showImagePicker = false
                state.isLoading = true
                
                return .run { send in
                    await send(.updateResponse(Result {
                        // Upload avatar via UserClient's avatar upload method
                        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                            throw UserClientError.operationFailed
                        }
                        
                        try await userClient.updateAvatarData(user.id, imageData)
                        
                        // Send notification for successful avatar upload
                        let notification = NotificationItem(
                            title: "Avatar Updated",
                            message: "Your profile avatar has been successfully updated.",
                            type: .system
                        )
                        try? await notificationClient.sendNotification(notification)
                        
                        // Get updated user from shared state after avatar upload
                        @Shared(.currentUser) var currentUser
                        guard let updatedUser = currentUser else {
                            throw UserClientError.userNotFound
                        }
                        
                        return updatedUser
                    }))
                }

            case .deleteAvatarImage:
                guard let user = state.currentUser else {
                    state.errorMessage = "User not found"
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.showDeleteAvatarConfirmation = false
                state.showEditAvatarSheet = false
                state.isLoading = true
                
                return .run { send in
                    await send(.updateResponse(Result {
                        try await userClient.deleteAvatarData(user.id)
                        
                        // Send notification for successful avatar deletion
                        let notification = NotificationItem(
                            title: "Avatar Deleted",
                            message: "Your profile avatar has been successfully deleted.",
                            type: .system
                        )
                        try? await notificationClient.sendNotification(notification)
                        
                        // Get updated user from shared state after avatar deletion
                        @Shared(.currentUser) var currentUser
                        guard let updatedUser = currentUser else {
                            throw UserClientError.userNotFound
                        }
                        
                        return updatedUser
                    }))
                }

            case let .showImagePickerWithSourceType(sourceType):
                state.imagePickerSourceType = sourceType
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
                
            case let .handlePhoneNumberFieldFocusChange(focused):
                state.phoneNumberFieldFocused = focused
                return .none
                
            case let .handlePhoneVerificationCodeFieldFocusChange(focused):
                state.phoneVerificationCodeFieldFocused = focused
                return .none

            case let .updateResponse(.success(user)):
                state.isLoading = false
                state.$currentUser.withLock { $0 = user }
                state.errorMessage = nil
                return .run { _ in
                    await haptics.notification(.success)
                    
                    // Send silent notification for profile update success
                    let notification = NotificationItem(
                        title: "Profile Updated",
                        message: "Your profile information has been successfully updated.",
                        type: .system
                    )
                    try? await notificationClient.sendNotification(notification)
                }

            case let .updateResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { [errorMessage = error.localizedDescription] _ in
                    await haptics.notification(.error)
                    
                    // Send silent notification for profile update failure
                    let notification = NotificationItem(
                        title: "Profile Update Failed",
                        message: "Failed to update profile: \(errorMessage)",
                        type: .system
                    )
                    try? await notificationClient.sendNotification(notification)
                }

            case let .uploadAvatarResponse(.success(url)):
                guard var user = state.currentUser else { return .none }
                user.avatarURL = url.absoluteString
                state.isLoading = false
                return .send(.updateResponse(.success(user)))

            case let .uploadAvatarResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { _ in
                    await haptics.notification(.error)
                }
                
            case let .phoneVerificationSent(.success(verificationID)):
                state.isLoading = false
                state.phoneVerificationID = verificationID
                state.isPhoneVerificationStep = true
                state.phoneVerificationCodeFieldFocused = true
                return .run { [phoneNumber = state.newPhoneNumber] _ in
                    await haptics.notification(.success)
                    
                    // Send silent notification for verification code sent
                    let notification = NotificationItem(
                        title: "Verification Code Sent",
                        message: "A verification code has been sent to \(phoneNumber)",
                        type: .system
                    )
                    try? await notificationClient.sendNotification(notification)
                }
                
            case let .phoneVerificationSent(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { [errorMessage = error.localizedDescription] _ in
                    await haptics.notification(.error)
                    
                    // Send silent notification for verification failure
                    let notification = NotificationItem(
                        title: "Verification Failed",
                        message: "Failed to send verification code: \(errorMessage)",
                        type: .system
                    )
                    try? await notificationClient.sendNotification(notification)
                }
                
            case let .phoneNumberChanged(.success):
                state.isLoading = false
                state.showPhoneNumberChangeSheet = false
                let changedPhoneNumber = state.newPhoneNumber
                state.newPhoneNumber = ""
                state.phoneVerificationCode = ""
                state.phoneVerificationID = nil
                state.isPhoneVerificationStep = false
                state.errorMessage = nil
                return .run { _ in
                    await haptics.notification(.success)
                    
                    // Send silent notification for successful phone number change
                    let notification = NotificationItem(
                        title: "Phone Number Updated",
                        message: "Your phone number has been successfully changed to \(changedPhoneNumber)",
                        type: .system
                    )
                    try? await notificationClient.sendNotification(notification)
                }
                
            case let .phoneNumberChanged(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { [errorMessage = error.localizedDescription] _ in
                    await haptics.notification(.error)
                    
                    // Send silent notification for phone number change failure
                    let notification = NotificationItem(
                        title: "Phone Number Change Failed",
                        message: "Failed to change phone number: \(errorMessage)",
                        type: .system
                    )
                    try? await notificationClient.sendNotification(notification)
                }
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
    @FocusState private var phoneNumberFieldFocused: Bool
    @FocusState private var phoneVerificationCodeFieldFocused: Bool

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 16) {
                    if let user = store.currentUser {
                        // Profile Header
                        VStack(spacing: 16) {
                            CommonAvatarView(
                                name: user.name,
                                image: store.currentAvatarImage,
                                size: 80,
                                backgroundColor: Color.blue.opacity(0.1),
                                textColor: .blue,
                                strokeWidth: 2,
                                strokeColor: .blue
                            )
                            Text(user.name)
                                .font(.headline)
                            Text(user.phoneNumber.isEmpty ? "(954) 234-5678" : user.phoneNumber)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        // Description Setting Card
                        Button(action: {
                            store.send(.prepareEditDescription, animation: .default)
                        }) {
                            HStack(alignment: .top) {
                                Text(user.emergencyNote.isEmpty ? "This is simply a note for contacts." : user.emergencyNote)
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
                        .padding(.top, 8)
                        .padding(.bottom, 8)

                        // Grouped Update Cards
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
                        .padding(.bottom, 8)

                        // Phone Number Setting Card
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
                        .padding(.bottom, 8)

                        // Sign Out Setting Card
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

                        Spacer()
                    } else {
                        ProgressView()
                        Text("Loading profile...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .sheet(isPresented: $store.showEditDescriptionSheet) {
                emergencyNoteSheetView
            }
            .sheet(isPresented: $store.showEditNameSheet) {
                nameEditSheetView
            }
            .sheet(isPresented: $store.showEditAvatarSheet) {
                avatarEditSheetView
            }
            .sheet(isPresented: $store.showPhoneNumberChangeSheet) {
                phoneNumberChangeSheetView
            }
            .sheet(isPresented: $store.showImagePicker) {
                ImagePicker(sourceType: store.imagePickerSourceType, selectedImage: { image in
                    if let image = image {
                        store.send(.setAvatarImage(image))
                    }
                })
            }
            .alert("Sign Out", isPresented: $store.showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    store.send(.signOut, animation: .default)
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Avatar", isPresented: $store.showDeleteAvatarConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    store.send(.deleteAvatarImage, animation: .default)
                }
            } message: {
                Text("Are you sure you want to delete your avatar photo?")
            }
            .onAppear {
                // Sync focus states
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
            .onChange(of: phoneNumberFieldFocused) { _, newValue in
                store.send(.handlePhoneNumberFieldFocusChange(newValue))
            }
            .onChange(of: store.phoneNumberFieldFocused) { _, newValue in
                phoneNumberFieldFocused = newValue
            }
            .onChange(of: phoneVerificationCodeFieldFocused) { _, newValue in
                store.send(.handlePhoneVerificationCodeFieldFocusChange(newValue))
            }
            .onChange(of: store.phoneVerificationCodeFieldFocused) { _, newValue in
                phoneVerificationCodeFieldFocused = newValue
            }
        }
    }

    // MARK: - Emergency Note Sheet View
    @ViewBuilder
    private var emergencyNoteSheetView: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $store.newDescription)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(minHeight: 240)
                        .padding(.vertical, 4)
                        .padding(.horizontal)
                        .scrollContentBackground(.hidden)
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                        .focused($textEditorFocused)
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
    private var nameEditSheetView: some View {
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
    private var avatarEditSheetView: some View {
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
    private var phoneNumberChangeSheetView: some View {
        NavigationStack {
            ZStack {
                // Background that fills the entire view
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {
                    VStack {
                        // Main content container
                        if !store.isPhoneVerificationStep {
                            phoneNumberEntryView
                        } else {
                            phoneVerificationView
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
    private var phoneNumberEntryView: some View {
        // Initial phone number change view
        VStack(alignment: .leading, spacing: 16) {
            Text("Current Phone Number")
                .font(.headline)
                .padding(.horizontal, 4)

            Text(store.currentUser?.phoneNumber.isEmpty == false ? store.currentUser!.phoneNumber : "(954) 234-5678")
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

            // Region picker
            HStack {
                Text("Region")
                    .font(.body)

                Spacer()

                Picker("Region", selection: $store.selectedPhoneRegion) {
                    ForEach(ProfileFeature.State.phoneRegions, id: \.0) { region in
                        Text("\(region.0) (\(region.1))").tag(region.0)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.horizontal, 4)

            TextField(store.phoneNumberPlaceholder, text: $store.newPhoneNumber)
                .keyboardType(.phonePad)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)
                .multilineTextAlignment(.leading) // Left align the text
                .focused($phoneNumberFieldFocused)
                .onChange(of: store.newPhoneNumber) { _, newValue in
                    store.send(.handlePhoneNumberChange(newValue))
                }

            Text("Enter your new phone number. We'll send a verification code to confirm.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            if let errorMessage = store.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }

            Button(action: {
                store.send(.sendPhoneVerificationCode, animation: .default)
            }) {
                Text(store.isLoading ? "Sending..." : "Send Verification Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.isLoading || !store.isPhoneNumberValid ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(store.isLoading || !store.isPhoneNumberValid)
            .padding(.top, 16)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
    
    @ViewBuilder
    private var phoneVerificationView: some View {
        // Verification code view
        VStack(alignment: .leading, spacing: 16) {
            Text("Verification Code")
                .font(.headline)
                .padding(.horizontal, 4)

            Text("Enter the verification code sent to \(store.newPhoneNumber)")
                .font(.body)
                .padding(.horizontal, 4)

            TextField("XXX-XXX", text: $store.phoneVerificationCode)
                .keyboardType(.numberPad)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)
                .focused($phoneVerificationCodeFieldFocused)
                .onChange(of: store.phoneVerificationCode) { _, newValue in
                    store.send(.handlePhoneVerificationCodeChange(newValue))
                }

            Button(action: {
                store.send(.verifyPhoneNumber, animation: .default)
            }) {
                Text(store.isLoading ? "Verifying..." : "Verify Code")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(store.isLoading || !store.isVerificationCodeValid ? Color.gray : Color.blue)
                    .cornerRadius(10)
            }
            .disabled(store.isLoading || !store.isVerificationCodeValid)
            .padding(.top, 16)
        }
        .padding(.horizontal)
        .padding(.top, 24)
    }
}
