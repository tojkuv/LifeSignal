import SwiftUI
import Foundation
import PhotosUI

// MARK: - Emergency Note Sheet View
struct EmergencyNoteSheetView: View {
    @Binding var isPresented: Bool
    @Binding var description: String
    let originalDescription: String
    @FocusState private var textEditorFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: $description)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(minHeight: 240) // Doubled the height
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
                    HapticFeedback.triggerHaptic()
                    isPresented = false
                },
                trailing: Button("Save") {
                    HapticFeedback.notificationFeedback(type: .success)
                    isPresented = false
                }
                .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || description == originalDescription)
            )
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                // Focus the text editor when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    textEditorFocused = true
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Name Edit Sheet View
struct NameEditSheetView: View {
    @Binding var isPresented: Bool
    @Binding var name: String
    let originalName: String
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Name", text: $name)
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
                    HapticFeedback.triggerHaptic()
                    isPresented = false
                },
                trailing: Button("Save") {
                    HapticFeedback.notificationFeedback(type: .success)
                    isPresented = false
                }
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name == originalName)
            )
            .onAppear {
                // Focus the text field when the view appears
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    nameFieldFocused = true
                }
            }
        }
    }
}

// MARK: - Avatar Edit Sheet View
struct AvatarEditSheetView: View {
    @Binding var isPresented: Bool
    @Binding var showImagePicker: Bool
    @Binding var showDeleteConfirmation: Bool
    @Binding var imagePickerSourceType: UIImagePickerController.SourceType
    let isUsingDefaultAvatar: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Avatar")
                .font(.headline.bold())
                .foregroundColor(.primary)
            VStack(spacing: 0) {
                Button(action: {
                    HapticFeedback.triggerHaptic()
                    isPresented = false
                    imagePickerSourceType = .photoLibrary
                    showImagePicker = true
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
                HapticFeedback.triggerHaptic()
                print("Delete avatar button tapped, setting showDeleteAvatarConfirmation to true")
                // First dismiss the sheet, then show the alert
                isPresented = false
                // Use a slight delay to ensure the sheet is dismissed before showing the alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    showDeleteConfirmation = true
                    print("showDeleteAvatarConfirmation is now: \(showDeleteConfirmation)")
                }
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
            .disabled(isUsingDefaultAvatar)
            .opacity(isUsingDefaultAvatar ? 0.5 : 1.0)
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .background(Color(UIColor.systemGroupedBackground))
        .presentationDetents([.medium])
    }
}

// MARK: - Main Profile View
struct ProfileView: View {
    @EnvironmentObject private var userViewModel: UserViewModel
    @Environment(\.presentationMode) private var presentationMode
    @EnvironmentObject private var appState: AppState
    @State private var showPhoneNumberChangeView = false
    @State private var showSignOutConfirmation = false
    @State private var showCheckInConfirmation = false
    @State private var showEditDescriptionSheet = false
    @State private var newDescription = ""
    @State private var showEditNameSheet = false
    @State private var newName = ""
    @State private var showEditAvatarSheet = false
    @State private var showImagePicker = false
    @State private var showCamera = false
    @State private var showDeleteAvatarConfirmation = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @FocusState private var nameFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack {
                // Profile Header
                VStack(spacing: 16) {
                    CommonAvatarView(
                        name: userViewModel.name,
                        image: userViewModel.avatarImage,
                        size: 80,
                        backgroundColor: Color.blue.opacity(0.1),
                        textColor: .blue,
                        strokeWidth: 2,
                        strokeColor: .blue
                    )
                    Text(userViewModel.name)
                        .font(.headline)
                    Text(userViewModel.phone.isEmpty ? "(954) 234-5678" : userViewModel.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Description Setting Card
                Button(action: {
                    HapticFeedback.triggerHaptic()
                    newDescription = userViewModel.profileDescription
                    showEditDescriptionSheet = true
                }) {
                    HStack(alignment: .top) {
                        Text(userViewModel.profileDescription.isEmpty ? "This is simply a note for contacts." : userViewModel.profileDescription)
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
                        HapticFeedback.triggerHaptic()
                        showEditAvatarSheet = true
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
                        HapticFeedback.triggerHaptic()
                        newName = userViewModel.name
                        showEditNameSheet = true
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

                // Phone Number Card
                Button(action: {
                    HapticFeedback.triggerHaptic()
                    showPhoneNumberChangeView = true
                }) {
                    HStack {
                        Text("Change Phone Number")
                            .font(.body)
                            .foregroundColor(.green)
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
                    HapticFeedback.triggerHaptic()
                    print("Sign out button tapped, setting showSignOutConfirmation to true")
                    showSignOutConfirmation = true
                    print("showSignOutConfirmation is now: \(showSignOutConfirmation)")
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
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .fullScreenCover(isPresented: $showPhoneNumberChangeView) {
            PhoneNumberChangeView()
                .environmentObject(userViewModel)
        }
        .alert(isPresented: $showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    userViewModel.checkIn()
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {
                print("Sign out cancelled")
            }
            Button("Sign Out", role: .destructive) {
                print("Sign out confirmed")
                // Reset user data first
                userViewModel.resetUserData()

                // Print debug information
                print("Before sign out: isAuthenticated = \(appState.isAuthenticated)")

                // Then sign out the user and navigate back to the sign-in view
                DispatchQueue.main.async {
                    appState.signOut()
                    print("After sign out: isAuthenticated = \(appState.isAuthenticated)")
                }
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $showEditDescriptionSheet) {
            EmergencyNoteSheetView(
                isPresented: $showEditDescriptionSheet,
                description: $newDescription,
                originalDescription: userViewModel.profileDescription
            )
            .onDisappear {
                if newDescription != userViewModel.profileDescription &&
                   !newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userViewModel.profileDescription = newDescription
                }
            }
        }
        .sheet(isPresented: $showEditNameSheet) {
            NameEditSheetView(
                isPresented: $showEditNameSheet,
                name: $newName,
                originalName: userViewModel.name
            )
            .onDisappear {
                if newName != userViewModel.name &&
                   !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userViewModel.name = newName
                }
            }
        }
        .sheet(isPresented: $showEditAvatarSheet) {
            AvatarEditSheetView(
                isPresented: $showEditAvatarSheet,
                showImagePicker: $showImagePicker,
                showDeleteConfirmation: $showDeleteAvatarConfirmation,
                imagePickerSourceType: $imagePickerSourceType,
                isUsingDefaultAvatar: userViewModel.isUsingDefaultAvatar
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imagePickerSourceType, selectedImage: { image in
                if let image = image {
                    userViewModel.setAvatarImage(image)
                }
            })
        }
        .alert(isPresented: $showDeleteAvatarConfirmation) {
            print("Delete avatar confirmation alert is being presented")
            return Alert(
                title: Text("Delete Avatar Photo"),
                message: Text("Are you sure you want to delete your avatar photo? This action cannot be undone."),
                primaryButton: .destructive(Text("Delete")) {
                    print("Delete avatar confirmed")
                    HapticFeedback.triggerHaptic()
                    userViewModel.deleteAvatarImage()
                    // Sheet is already dismissed, no need to dismiss it again
                },
                secondaryButton: .cancel() {
                    print("Delete avatar cancelled")
                }
            )
        }
    }
}
