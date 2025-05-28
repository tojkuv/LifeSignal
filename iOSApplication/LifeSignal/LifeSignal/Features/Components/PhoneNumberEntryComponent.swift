import SwiftUI
import ComposableArchitecture

struct PhoneNumberEntryComponent: View {
    let selectedRegion: String
    let regions: [(String, String)]
    let phoneNumber: String
    let phoneNumberPlaceholder: String
    let buttonTitle: String
    let isLoading: Bool
    let canSendCode: Bool
    let showRegionPicker: Bool
    
    let onRegionPickerToggle: () -> Void
    let onRegionSelection: ((String, String)) -> Void
    let onPhoneNumberChange: (String) -> Void
    let onButtonTap: () -> Void
    
    @FocusState private var phoneNumberFieldFocused: Bool
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Region picker
            HStack {
                Text("Region")
                    .font(.body)

                Spacer()

                Button(action: onRegionPickerToggle) {
                    HStack {
                        // Show the currently selected region
                        let selectedRegionInfo = regions.first { $0.0 == selectedRegion }!
                        Text("\(selectedRegionInfo.0) (\(selectedRegionInfo.1))")
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .popover(isPresented: Binding(
                    get: { showRegionPicker },
                    set: { _ in onRegionPickerToggle() }
                )) {
                    List {
                        ForEach(regions, id: \.0) { region in
                            Button(action: {
                                onRegionSelection(region)
                            }) {
                                HStack {
                                    Text("\(region.0) (\(region.1))")

                                    Spacer()

                                    if selectedRegion == region.0 {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                    .presentationDetents([.medium])
                }
            }
            .padding(.horizontal, 4)

            // Phone number field with formatting
            TextField(phoneNumberPlaceholder, text: Binding(
                get: { phoneNumber },
                set: { newValue in
                    let limitedValue = phoneNumberFormatter.limitPhoneNumberLength(newValue)
                    let formattedValue = phoneNumberFormatter.formatAsYouType(limitedValue)
                    onPhoneNumberChange(formattedValue)
                }
            ))
                .keyboardType(.phonePad)
                .font(.body)
                .padding(.vertical, 12)
                .padding(.horizontal)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .focused($phoneNumberFieldFocused)
                .disabled(isLoading)

            Button(action: onButtonTap) {
                Text(buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .disabled(isLoading)
            .background(isLoading || !canSendCode ? Color.gray : Color.blue)
            .cornerRadius(12)
            .disabled(isLoading || !canSendCode)
        }
    }
}

// Preview
#Preview {
    PhoneNumberEntryComponent(
        selectedRegion: "United States",
        regions: [("United States", "+1"), ("Canada", "+1")],
        phoneNumber: "",
        phoneNumberPlaceholder: "(000) 000-0000",
        buttonTitle: "Send Verification Code",
        isLoading: false,
        canSendCode: false,
        showRegionPicker: false,
        onRegionPickerToggle: {},
        onRegionSelection: { _, _ in },
        onPhoneNumberChange: { _ in },
        onButtonTap: {}
    )
    .padding()
}