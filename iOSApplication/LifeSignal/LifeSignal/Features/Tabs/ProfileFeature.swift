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
        
        // Focus states for sync with SwiftUI
        var textEditorFocused = false
        var nameFieldFocused = false
        
        var isUsingDefaultAvatar: Bool {
            currentUser?.avatarImageData == nil
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
        
        // Phone number
        case showPhoneNumberChange
        
        // Authentication
        case confirmSignOut
        case signOut
        
        // Focus states
        case handleTextEditorFocusChange(Bool)
        case handleNameFieldFocusChange(Bool)
        
        // Network responses
        case updateResponse(Result<User, Error>)
        case uploadAvatarResponse(Result<URL, Error>)
    }
    
    @Dependency(\.userClient) var userClient
    @Dependency(\.authenticationClient) var authClient
    @Dependency(\.hapticClient) var haptics
    
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
                state.showPhoneNumberChangeSheet = true
                return .run { _ in
                    await haptics.impact(.light)
                }

            case .confirmSignOut:
                state.showSignOutConfirmation = true
                return .run { _ in
                    await haptics.impact(.medium)
                }

            case .signOut:
                state.showSignOutConfirmation = false
                return .run { _ in
                    await haptics.notification(.success)
                    // TODO: Implement sign out functionality when authentication is ready
                }

            case .saveEditedDescription:
                let trimmedDescription = state.newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                state.showEditDescriptionSheet = false
                state.isLoading = true
                
                return .run { send in
                    await haptics.notification(.success)
                    await send(.updateResponse(Result {
                        try await userClient.updateEmergencyNote(trimmedDescription)
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
                
                guard authClient.validateName(trimmedName).isValid else {
                    state.errorMessage = authClient.validateName(trimmedName).errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.showEditNameSheet = false
                state.isLoading = true
                
                return .run { send in
                    await haptics.notification(.success)
                    await send(.updateResponse(Result {
                        try await userClient.updateName(trimmedName)
                    }))
                }

            case .cancelEditName:
                state.showEditNameSheet = false
                state.newName = ""
                return .run { _ in
                    await haptics.impact(.light)
                }

            case let .setAvatarImage(image):
                state.showEditAvatarSheet = false
                state.showImagePicker = false
                state.isLoading = true
                
                return .run { send in
                    await haptics.notification(.success)
                    await send(.updateResponse(Result {
                        try await userClient.updateAvatar(image)
                    }))
                }

            case .deleteAvatarImage:
                state.showDeleteAvatarConfirmation = false
                state.showEditAvatarSheet = false
                state.isLoading = true
                
                return .run { send in
                    await haptics.notification(.success)
                    await send(.updateResponse(Result {
                        try await userClient.updateAvatar(nil)
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

            case let .updateResponse(.success(user)):
                state.isLoading = false
                state.$currentUser.withLock { $0 = user }
                state.errorMessage = nil
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .updateResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { _ in
                    await haptics.notification(.error)
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

    var body: some View {
        WithPerceptionTracking {
            ScrollView {
                VStack(spacing: 16) {
                    if let user = store.currentUser {
                        // Profile Header
                        VStack(spacing: 16) {
                            CommonAvatarView(
                                name: user.name,
                                image: user.avatarImage,
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
                // TODO: Phone number change sheet - complex implementation
                Text("Phone number change coming soon")
                    .padding()
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
}
