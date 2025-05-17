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

    /// Format an interval for display
    private func formatInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval / 3600)

        // Special case for our specific hour values (8, 16, 32)
        if hours == 8 || hours == 16 || hours == 32 {
            return "\(hours) hours"
        }

        // For other values, use the standard formatting
        let days = hours / 24
        if days > 0 {
            return "\(days) day\(days == 1 ? "" : "s")"
        } else {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header (avatar, name, phone) - centered, stacked
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
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

                            // Name field - now non-editable
                            Text(viewModel.contact.name.isEmpty ? "Unknown" : viewModel.contact.name)
                            .font(.title3)
                            .multilineTextAlignment(.center)

                            // Phone field - now non-editable
                            Text(viewModel.contact.phone.isEmpty ? "No phone number" : viewModel.contact.phone)
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        }
                        .padding(.top)

                        // Role selection
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Contact Role")
                                .font(.headline)

                            // Responder toggle
                            Toggle(isOn: Binding(
                                get: { self.viewModel.contact.isResponder },
                                set: {
                                    HapticFeedback.selectionFeedback()
                                    self.viewModel.updateIsResponder($0)
                                }
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
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)

                            // Dependent toggle
                            Toggle(isOn: Binding(
                                get: { self.viewModel.contact.isDependent },
                                set: {
                                    HapticFeedback.selectionFeedback()
                                    self.viewModel.updateIsDependent($0)
                                }
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
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)

                        // Note section - styled to match profile tab
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Emergency Note")
                                .font(.headline)

                            Text("This is the contact managed emergency note")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text(viewModel.contact.note.isEmpty ? "No emergency note provided" : viewModel.contact.note)
                            .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
                            .padding(12)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(10)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
                .background(Color(UIColor.systemGroupedBackground))

                // No loading overlay - we just disable the button instead
            }
            .navigationTitle("Add Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticFeedback.triggerHaptic()
                        onClose()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        HapticFeedback.notificationFeedback(type: .success)
                        viewModel.addContact { success in
                            if success {
                                onAddContact(viewModel.contact)
                            }
                        }
                    }
                    .disabled(viewModel.isAddingContact || viewModel.contact.name.isEmpty || (!viewModel.contact.isResponder && !viewModel.contact.isDependent))
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
