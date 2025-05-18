import SwiftUI
import Foundation
import PhotosUI
import Combine
import UIKit

// MARK: - Main Profile View
struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @Environment(\.presentationMode) private var presentationMode

    // Focus states
    @FocusState private var textEditorFocused: Bool
    @FocusState private var nameFieldFocused: Bool
    @FocusState private var phoneNumberFieldFocused: Bool
    @FocusState private var verificationCodeFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack {
                // Profile Header
                VStack(spacing: 16) {
                    CommonAvatarView(
                        name: viewModel.name,
                        image: viewModel.avatarImage,
                        size: 80,
                        backgroundColor: Color.blue.opacity(0.1),
                        textColor: .blue,
                        strokeWidth: 2,
                        strokeColor: .blue
                    )
                    Text(viewModel.name)
                        .font(.headline)
                    Text(viewModel.phone.isEmpty ? "(954) 234-5678" : viewModel.phone)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                // Description Setting Card
                Button(action: {
                    viewModel.prepareEditDescription()
                }) {
                    HStack(alignment: .top) {
                        Text(viewModel.profileDescription.isEmpty ? "This is simply a note for contacts." : viewModel.profileDescription)
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
                        viewModel.showAvatarEditor()
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
                        viewModel.prepareEditName()
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
                    viewModel.showPhoneNumberChange()
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
                    viewModel.confirmSignOut()
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
        .sheet(isPresented: $viewModel.showPhoneNumberChangeSheetView) {
            phoneNumberChangeSheetView
        }
        .alert(isPresented: $viewModel.showCheckInConfirmation) {
            Alert(
                title: Text("Confirm Check-in"),
                message: Text("Are you sure you want to check in now? This will reset your timer."),
                primaryButton: .default(Text("Check In")) {
                    // This would be handled by the view model in a real implementation
                },
                secondaryButton: .cancel()
            )
        }
        .alert("Sign Out", isPresented: $viewModel.showSignOutConfirmation) {
            Button("Cancel", role: .cancel) {
                // Do nothing
            }
            Button("Sign Out", role: .destructive) {
                viewModel.signOut()
                // Navigation to sign-in screen would be handled by a coordinator or parent view
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .sheet(isPresented: $viewModel.showEditDescriptionSheet) {
            emergencyNoteSheetView
        }
        .sheet(isPresented: $viewModel.showEditNameSheet) {
            nameEditSheetView
        }
        .sheet(isPresented: $viewModel.showEditAvatarSheet) {
            avatarEditSheetView
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePicker(sourceType: viewModel.imagePickerSourceType, selectedImage: { image in
                if let image = image {
                    viewModel.setAvatarImage(image)
                }
            })
        }
        .alert(isPresented: $viewModel.showDeleteAvatarConfirmation) {
            Alert(
                title: Text("Delete Avatar"),
                message: Text("Are you sure you want to delete your avatar photo?"),
                primaryButton: .destructive(Text("Delete")) {
                    viewModel.deleteAvatarImage()
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: - Private Computed Properties

    // Emergency Note Sheet View
    private var emergencyNoteSheetView: some View {
        var view: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextEditor(text: $viewModel.newDescription)
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
                        viewModel.cancelEditDescription()
                    },
                    trailing: Button("Save") {
                        viewModel.saveEditedDescription()
                        viewModel.showEditDescriptionSheet = false
                    }
                    .disabled(viewModel.newDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              viewModel.newDescription == viewModel.profileDescription)
                )
                .background(Color(UIColor.systemGroupedBackground))
                .onAppear {
                    // Bind the focus state to the view model's focus state
                    textEditorFocused = viewModel.isDescriptionFieldFocused
                }
                .onChange(of: textEditorFocused) { newValue in
                    viewModel.isDescriptionFieldFocused = newValue
                }
                .onChange(of: viewModel.isDescriptionFieldFocused) { newValue in
                    textEditorFocused = newValue
                }
            }
            .presentationDetents([.large])
        }
        return view
    }

    // Name Edit Sheet View
    private var nameEditSheetView: some View {
        var view: some View {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Name", text: $viewModel.newName)
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
                        viewModel.cancelEditName()
                    },
                    trailing: Button("Save") {
                        viewModel.saveEditedName()
                        viewModel.showEditNameSheet = false
                    }
                    .disabled(viewModel.newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              viewModel.newName == viewModel.name)
                )
                .onAppear {
                    // Bind the focus state to the view model's focus state
                    nameFieldFocused = viewModel.isNameFieldFocused
                }
                .onChange(of: nameFieldFocused) { newValue in
                    viewModel.isNameFieldFocused = newValue
                }
                .onChange(of: viewModel.isNameFieldFocused) { newValue in
                    nameFieldFocused = newValue
                }
            }
        }
        return view
    }

    // Avatar Edit Sheet View
    private var avatarEditSheetView: some View {
        var view: some View {

            VStack(spacing: 20) {
                Text("Avatar")
                    .font(.headline.bold())
                    .foregroundColor(.primary)
                VStack(spacing: 0) {
                    Button(action: {
                        viewModel.showImagePickerWithSourceType(.photoLibrary)
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
                    viewModel.showDeleteAvatarConfirmationDialog()
                    viewModel.closeAvatarEditor()
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
                .disabled(viewModel.isUsingDefaultAvatar)
                .opacity(viewModel.isUsingDefaultAvatar ? 0.5 : 1.0)
                Spacer(minLength: 0)
            }
            .padding(.top, 24)
            .background(Color(UIColor.systemGroupedBackground))
            .presentationDetents([.medium])
        }
        return view
    }

    // Phone Number Change View
    private var phoneNumberChangeSheetView: some View {
        NavigationStack {
            ScrollView {
                if !viewModel.isCodeSent {
                    // Initial phone number change view
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Current Phone Number")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        Text(viewModel.phone.isEmpty ? "(954) 234-5678" : viewModel.phone)
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

                            Picker("Region", selection: $viewModel.editingPhoneRegion) {
                                ForEach(viewModel.regions, id: \.0) { region in
                                    Text("\(region.0) (\(region.1))").tag(region.0)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .onChange(of: viewModel.editingPhoneRegion) { _, _ in
                                viewModel.handleRegionChange()
                            }
                        }
                        .padding(.horizontal, 4)

                        TextField(viewModel.phoneNumberPlaceholder, text: $viewModel.editingPhone)
                            .keyboardType(.phonePad)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.leading) // Left align the text
                            .focused($phoneNumberFieldFocused)
                            .onChange(of: viewModel.editingPhone) { _, newValue in
                                viewModel.handlePhoneNumberChange(newValue: newValue)
                            }

                        Text("Enter your new phone number. We'll send a verification code to confirm.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)

                        if let errorMessage = viewModel.phoneErrorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                        }

                        Button(action: {
                            HapticFeedback.triggerHaptic()
                            viewModel.sendPhoneChangeVerificationCode()
                        }) {
                            Text(viewModel.isLoading ? "Sending..." : "Send Verification Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.isLoading || !viewModel.isPhoneNumberValid ? Color.gray : Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(viewModel.isLoading || !viewModel.isPhoneNumberValid)
                        .padding(.top, 16)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                } else {
                    // Verification code view
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Verification Code")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        Text("Enter the verification code sent to \(PhoneFormatter.formatPhoneNumber(viewModel.editingPhone, region: viewModel.editingPhoneRegion))")
                            .font(.body)
                            .padding(.horizontal, 4)

                        TextField("XXX-XXX", text: $viewModel.verificationCode)
                            .keyboardType(.numberPad)
                            .font(.body)
                            .padding(.vertical, 12)
                            .padding(.horizontal)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                            .foregroundColor(.primary)
                            .focused($verificationCodeFieldFocused)
                            .onChange(of: viewModel.verificationCode) { _, newValue in
                                viewModel.handleVerificationCodeChange(newValue: newValue)
                            }

                        Button(action: {
                            HapticFeedback.triggerHaptic()
                            viewModel.verifyPhoneChange()
                        }) {
                            Text(viewModel.isLoading ? "Verifying..." : "Verify Code")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(viewModel.isLoading || !viewModel.isVerificationCodeValid ? Color.gray : Color.blue)
                                .cornerRadius(10)
                        }
                        .disabled(viewModel.isLoading || !viewModel.isVerificationCodeValid)
                        .padding(.top, 16)

                        Button(action: {
                            viewModel.cancelPhoneNumberChange()
                        }) {
                            Text("Cancel")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .frame(maxWidth: .infinity)
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal)
                    .padding(.top, 24)
                }

                Spacer(minLength: 0)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Change Phone Number")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.triggerHaptic()
                        viewModel.cancelPhoneNumberChange()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .onAppear {
                // Bind the focus states to the view model's focus states
                phoneNumberFieldFocused = viewModel.isPhoneNumberFieldFocused
                verificationCodeFieldFocused = viewModel.isVerificationCodeFieldFocused
            }
            .onChange(of: phoneNumberFieldFocused) { newValue in
                viewModel.isPhoneNumberFieldFocused = newValue
            }
            .onChange(of: viewModel.isPhoneNumberFieldFocused) { newValue in
                phoneNumberFieldFocused = newValue
            }
            .onChange(of: verificationCodeFieldFocused) { newValue in
                viewModel.isVerificationCodeFieldFocused = newValue
            }
            .onChange(of: viewModel.isVerificationCodeFieldFocused) { newValue in
                verificationCodeFieldFocused = newValue
            }
        }
    }
}
