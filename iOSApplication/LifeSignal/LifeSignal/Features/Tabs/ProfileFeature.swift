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
        var editingUser: User?
        var isLoading = false
        var errorMessage: String?

        var isEditing: Bool { editingUser != nil }
        var canSave: Bool {
            guard let editing = editingUser else { return false }
            return !editing.name.isEmpty && !editing.phoneNumber.isEmpty && editing != currentUser
        }
    }
    
    @CasePathable
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
    @Dependency(\.validationClient) var validation
    @Dependency(\.hapticClient) var haptics
    @Dependency(\.analytics) var analytics
    
    var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.editingUser):
                state.errorMessage = nil
                return .none

            case .binding:
                return .none

            case .edit:
                state.editingUser = state.currentUser
                return .run { _ in
                    await analytics.track(.featureUsed(feature: "profile_edit", context: [:]))
                }

            case .save:
                guard let user = state.editingUser else { return .none }
                
                // Validate inputs before saving
                guard validation.validateName(user.name).isValid else {
                    state.errorMessage = validation.validateName(user.name).errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                guard validation.validatePhoneNumber(user.phoneNumber).isValid else {
                    state.errorMessage = validation.validatePhoneNumber(user.phoneNumber).errorMessage
                    return .run { _ in
                        await haptics.notification(.error)
                    }
                }
                
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await haptics.selection()
                    await send(.response(Result {
                        try await userRepository.updateProfile(user)
                    }))
                }

            case .cancel:
                state.editingUser = nil
                return .none

            case let .uploadAvatar(data):
                state.isLoading = true
                return .run { [userId = state.currentUser?.id] send in
                    guard let userId = userId else {
                        await send(.uploadResponse(.failure(UserRepositoryError.userNotFound("No current user"))))
                        return
                    }
                    await send(.uploadResponse(Result {
                        try await userRepository.uploadAvatar(userId, data)
                    }))
                }

            case let .response(.success(user)):
                state.isLoading = false
                state.$currentUser.withLock { $0 = user }
                state.editingUser = nil
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .response(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .run { _ in
                    await haptics.notification(.error)
                }

            case let .uploadResponse(.success(url)):
                state.isLoading = false
                state.editingUser?.avatarURL = url.absoluteString
                return .run { _ in
                    await haptics.notification(.success)
                }

            case let .uploadResponse(.failure(error)):
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

    var body: some View {
        WithPerceptionTracking {
            NavigationStack {
                Group {
                    if let user = store.currentUser {
                        if store.isEditing {
                            editingView(user: user)
                        } else {
                            displayView(user: user)
                        }
                    } else {
                        loadingView()
                    }
                }
                .navigationTitle("Profile")
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    // MARK: - Display View
    @ViewBuilder
    private func displayView(user: User) -> some View {
        ScrollView {
            VStack(spacing: 16) {
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
                    Text(user.phoneNumber.isEmpty ? "No phone number" : user.phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top)

                // Profile Description Card
                VStack(alignment: .leading, spacing: 8) {
                    Text("Emergency Note")
                        .font(.headline)
                    Text(user.emergencyNote.isEmpty ? "Add an emergency note that contacts can see." : user.emergencyNote)
                        .font(.body)
                        .foregroundColor(user.emergencyNote.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)

                // Edit Button
                Button(action: {
                    store.send(.edit)
                }) {
                    Text("Edit Profile")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                .padding(.horizontal)

                // TODO: Add sign out functionality when authentication is implemented
                /*
                Button(action: {
                    // store.send(.signOut)
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
                */

                Spacer()
            }
        }
    }

    // MARK: - Editing View
    @ViewBuilder
    private func editingView(user: User) -> some View {
        Form {
            Section("Profile Information") {
                if let editingUser = store.editingUser {
                    TextField("Name", text: Binding(
                        get: { editingUser.name },
                        set: { store.editingUser = editingUser.withName($0) }
                    ))

                    TextField("Phone Number", text: Binding(
                        get: { editingUser.phoneNumber },
                        set: { store.editingUser = editingUser.withPhone($0) }
                    ))
                    .keyboardType(.phonePad)

                    TextField("Emergency Note", text: Binding(
                        get: { editingUser.emergencyNote },
                        set: { store.editingUser = editingUser.withEmergencyNote($0) }
                    ), axis: .vertical)
                    .lineLimit(3...6)
                }
            }

            // TODO: Add avatar editing when image picker is implemented
            /*
            Section("Avatar") {
                Button("Change Avatar") {
                    // store.send(.showAvatarPicker)
                }
            }
            */

            if let errorMessage = store.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Cancel") {
                    store.send(.cancel)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    store.send(.save)
                }
                .disabled(!store.canSave || store.isLoading)
            }
        }
        .disabled(store.isLoading)
    }

    // MARK: - Loading View
    @ViewBuilder
    private func loadingView() -> some View {
        VStack {
            ProgressView()
            Text("Loading profile...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
