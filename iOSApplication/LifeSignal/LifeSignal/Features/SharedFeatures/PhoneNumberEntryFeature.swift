import SwiftUI
import ComposableArchitecture
import UIKit

@Reducer
struct PhoneNumberEntryFeature: FeatureContext {
    @ObservableState
    struct State: Equatable {
        var selectedRegion: String
        var regions: [(String, String)]
        var phoneNumber: String = ""
        var buttonTitle: String
        var isLoading: Bool = false
        var canSendCode: Bool = false
        var showRegionPicker: Bool = false
        var phoneNumberFieldFocused: Bool = false
        
        static func == (lhs: State, rhs: State) -> Bool {
            lhs.selectedRegion == rhs.selectedRegion &&
            lhs.phoneNumber == rhs.phoneNumber &&
            lhs.buttonTitle == rhs.buttonTitle &&
            lhs.isLoading == rhs.isLoading &&
            lhs.canSendCode == rhs.canSendCode &&
            lhs.showRegionPicker == rhs.showRegionPicker &&
            lhs.phoneNumberFieldFocused == rhs.phoneNumberFieldFocused &&
            lhs.regions.map(\.0) == rhs.regions.map(\.0) &&
            lhs.regions.map(\.1) == rhs.regions.map(\.1)
        }
        
        var placeholderForRegion: String {
            switch selectedRegion {
            case "US", "CA":
                return "(000) 000-0000"
            case "UK":
                return "00000 000000"
            case "AU":
                return "0000 000 000"
            default:
                return "000 000 0000"
            }
        }
        
        var digitLimitForRegion: Int {
            switch selectedRegion {
            case "US", "CA":
                return 10
            case "UK":
                return 11
            case "AU":
                return 10
            default:
                return 15
            }
        }
        
        var isPhoneNumberValid: Bool {
            let digitCount = phoneNumber.filter { $0.isNumber }.count
            
            let expectedDigitCount: Int
            switch selectedRegion {
            case "US", "CA":
                expectedDigitCount = 10
            case "UK":
                expectedDigitCount = 11
            case "AU":
                expectedDigitCount = 10
            default:
                expectedDigitCount = 10
            }
            
            return digitCount == expectedDigitCount
        }
    }
    
    @CasePathable
    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toggleRegionPicker
        case selectRegion(String, String)
        case updatePhoneNumber(String)
        case buttonTapped
        case focusPhoneNumberField(Bool)
        
        // Parent communication actions
        case delegate(Delegate)
        
        @CasePathable
        enum Delegate: Equatable {
            case regionPickerToggled
            case regionSelected(String, String)
            case phoneNumberChanged(String)
            case buttonTapped
        }
    }
    
    @Dependency(\.phoneNumberFormatter) var phoneNumberFormatter
    
    var body: some ReducerOf<Self> {
        BindingReducer()
        
        Reduce { state, action in
            switch action {
            case .binding:
                return .none
                
            case .toggleRegionPicker:
                state.showRegionPicker.toggle()
                return .send(.delegate(.regionPickerToggled))
                
            case let .selectRegion(regionCode, regionName):
                state.selectedRegion = regionCode
                state.showRegionPicker = false
                return .send(.delegate(.regionSelected(regionCode, regionName)))
                
            case let .updatePhoneNumber(newValue):
                // Format the input (view already validated digit limits)
                let limitedValue = phoneNumberFormatter.limitPhoneNumberLengthForRegion(newValue, state.selectedRegion)
                let formattedValue = phoneNumberFormatter.formatAsYouTypeForRegion(limitedValue, state.selectedRegion)
                state.phoneNumber = formattedValue
                state.canSendCode = state.isPhoneNumberValid
                return .send(.delegate(.phoneNumberChanged(formattedValue)))
                
            case .buttonTapped:
                return .send(.delegate(.buttonTapped))
                
            case let .focusPhoneNumberField(focused):
                state.phoneNumberFieldFocused = focused
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

struct PhoneNumberEntryView: View {
    @Bindable var store: StoreOf<PhoneNumberEntryFeature>
    @FocusState private var phoneNumberFieldFocused: Bool
    @State private var localPhoneNumber: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Region picker
            HStack {
                Text("Region")
                    .font(.body)

                Spacer()

                Button(action: {
                    store.send(.toggleRegionPicker)
                }) {
                    HStack {
                        // Show the currently selected region
                        let selectedRegionInfo = store.regions.first { $0.0 == store.selectedRegion }!
                        Text("\(selectedRegionInfo.0) (\(selectedRegionInfo.1))")
                            .foregroundColor(.primary)

                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .popover(isPresented: Binding(
                    get: { store.showRegionPicker },
                    set: { _ in store.send(.toggleRegionPicker) }
                )) {
                    List {
                        ForEach(store.regions, id: \.0) { region in
                            Button(action: {
                                store.send(.selectRegion(region.0, region.1))
                            }) {
                                HStack {
                                    Text("\(region.0) (\(region.1))")

                                    Spacer()

                                    if store.selectedRegion == region.0 {
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
            LimitedDigitTextField(
                text: $localPhoneNumber,
                placeholder: store.placeholderForRegion,
                digitLimit: store.digitLimitForRegion,
                keyboardType: .phonePad,
                isDisabled: store.isLoading,
                onTextChange: { newValue in
                    store.send(.updatePhoneNumber(newValue))
                },
                isFocused: store.phoneNumberFieldFocused
            )
            .padding(.vertical, 12)
            .padding(.horizontal)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
            .focused($phoneNumberFieldFocused)
                .onChange(of: phoneNumberFieldFocused) { _, newValue in
                    store.send(.focusPhoneNumberField(newValue))
                }
                .onChange(of: store.phoneNumberFieldFocused) { _, newValue in
                    phoneNumberFieldFocused = newValue
                }
                .onAppear {
                    // Initialize local state with store value
                    localPhoneNumber = store.phoneNumber
                }
                .onChange(of: store.phoneNumber) { _, newValue in
                    // Always sync from store to local state to keep them in sync
                    if localPhoneNumber != newValue {
                        localPhoneNumber = newValue
                    }
                }
                .onChange(of: store.selectedRegion) { _, _ in
                    // When region changes, truncate and reformat the current number for the new region
                    if !localPhoneNumber.isEmpty {
                        // First clean the local number to just digits
                        let cleanedDigits = localPhoneNumber.filter { $0.isNumber }
                        // Then truncate to the new region's limit and send for formatting
                        let truncatedDigits = String(cleanedDigits.prefix(store.digitLimitForRegion))
                        store.send(.updatePhoneNumber(truncatedDigits))
                    }
                }

            Button(action: {
                store.send(.buttonTapped)
            }) {
                Text(store.buttonTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .disabled(store.isLoading)
            .background(store.isLoading || !store.canSendCode ? Color.gray : Color.blue)
            .cornerRadius(12)
            .disabled(store.isLoading || !store.canSendCode)
        }
    }
}


// Preview
#Preview {
    PhoneNumberEntryView(
        store: Store(initialState: PhoneNumberEntryFeature.State(
            selectedRegion: "US",
            regions: [("US", "+1"), ("CA", "+1"), ("UK", "+44"), ("AU", "+61")],
            buttonTitle: "Send Verification Code"
        )) {
            PhoneNumberEntryFeature()
        }
    )
    .padding()
}