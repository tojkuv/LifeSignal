import SwiftUI
import Foundation
import PhotosUI
import ComposableArchitecture
import Perception
import UIKit

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
                        loadingView
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
    private var loadingView: some View {
        VStack {
            ProgressView()
            Text("Loading profile...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
