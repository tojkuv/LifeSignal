import SwiftUI

/// A SwiftUI view for adding contacts
struct AddContactSheetView: View {
    // MARK: - Properties
    
    /// The view model for adding contacts
    @ObservedObject var viewModel: AddContactSheetViewModel
    
    /// The callback for when a contact is added
    var onAddContact: (Contact) -> Void
    
    /// The callback for when the sheet is closed
    var onClose: () -> Void
    
    // MARK: - Initialization
    
    /// Initialize with a QR code ID and callbacks
    /// - Parameters:
    ///   - qrCodeId: The QR code ID
    ///   - onAddContact: The callback for when a contact is added
    ///   - onClose: The callback for when the sheet is closed
    init(
        qrCodeId: String,
        onAddContact: @escaping (Contact) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = AddContactSheetViewModel(qrCodeId: qrCodeId)
        self.onAddContact = onAddContact
        self.onClose = onClose
    }
    
    /// Initialize with a view model and callbacks
    /// - Parameters:
    ///   - viewModel: The view model
    ///   - onAddContact: The callback for when a contact is added
    ///   - onClose: The callback for when the sheet is closed
    init(
        viewModel: AddContactSheetViewModel,
        onAddContact: @escaping (Contact) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onAddContact = onAddContact
        self.onClose = onClose
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header (avatar, name, phone) - centered, stacked
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color(UIColor.systemBackground))
                                .frame(width: 100, height: 100)
                                .overlay(
                                    Text(String(viewModel.contact.name.isEmpty ? "?" : viewModel.contact.name.prefix(1)))
                                        .foregroundColor(.blue)
                                        .font(.title)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                            
                            // Name field
                            TextField("Name", text: Binding(
                                get: { self.viewModel.contact.name },
                                set: { self.viewModel.updateName($0) }
                            ))
                            .font(.title3)
                            .multilineTextAlignment(.center)
                            .disabled(viewModel.isAddingContact)
                            
                            // Phone field
                            TextField("Phone", text: Binding(
                                get: { self.viewModel.contact.phone },
                                set: { self.viewModel.updatePhone($0) }
                            ))
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .keyboardType(.phonePad)
                            .disabled(viewModel.isAddingContact)
                        }
                        .padding(.top)
                        
                        // Role selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact Role")
                                .font(.headline)
                            
                            // Responder toggle
                            Toggle(isOn: Binding(
                                get: { self.viewModel.contact.isResponder },
                                set: { self.viewModel.updateIsResponder($0) }
                            )) {
                                HStack {
                                    Image(systemName: "person.2.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Responder")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text("Can see your status and respond if you need help")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            
                            // Dependent toggle
                            Toggle(isOn: Binding(
                                get: { self.viewModel.contact.isDependent },
                                set: { self.viewModel.updateIsDependent($0) }
                            )) {
                                HStack {
                                    Image(systemName: "person.3.fill")
                                        .foregroundColor(.blue)
                                    
                                    VStack(alignment: .leading) {
                                        Text("Dependent")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text("You can see their status and respond if they need help")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                        }
                        .padding(.horizontal)
                        
                        // Note section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Note")
                                .font(.headline)
                            
                            Text("This note will be visible to responders if you need help")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextEditor(text: Binding(
                                get: { self.viewModel.contact.note },
                                set: { self.viewModel.contact.note = $0 }
                            ))
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .disabled(viewModel.isAddingContact)
                        }
                        .padding(.horizontal)
                        
                        // Add button
                        Button(action: {
                            viewModel.addContact { success in
                                if success {
                                    onAddContact(viewModel.contact)
                                }
                            }
                        }) {
                            if viewModel.isAddingContact {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            } else {
                                Text("Add Contact")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                        .disabled(viewModel.isAddingContact || viewModel.contact.name.isEmpty)
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    .padding(.bottom, 40)
                }
                
                // Loading overlay
                if viewModel.isAddingContact {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        )
                }
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onClose()
                    }
                }
            }
            .alert(isPresented: $viewModel.showErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
        }
    }
}

#Preview {
    AddContactSheetView(
        qrCodeId: "mock-qr-code-1234",
        onAddContact: { _ in },
        onClose: {}
    )
}
