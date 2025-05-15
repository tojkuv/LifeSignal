# View Model Changes for TCA Migration

This document summarizes the changes made to the view models in the MockApplication to better align with TCA patterns.

## 1. AppViewModel (formerly AppState)

- Renamed `AppState` to `AppViewModel` with a typealias for backward compatibility
- Added properties that mirror TCA's `AppFeature.State`:
  - `error: String?` for error handling
  - `isLoading: Bool` for loading state
  - `showContactDetails: Bool` and `selectedContactId: String?` for presentation state
- Added methods that will become TCA actions:
  - `setError(_ message: String?)`
  - `setLoading(_ loading: Bool)`
  - `showContactDetails(for contactId: String)`
  - `hideContactDetails()`

## 2. UserViewModel

- Added documentation to indicate TCA alignment
- Existing properties already align well with TCA's `UserFeature.State`
- Methods are well-structured for conversion to TCA actions

## 3. CheckInViewModel

- Added documentation to indicate TCA alignment
- Updated to better sync with UserViewModel
- Added timer functionality that will be handled by TCA effects
- Modified CheckInView to properly sync with UserViewModel on appear and when checking in

## 4. MainTabViewModel (new)

- Created a new view model for MainTabView
- Added properties that mirror TCA's tab state:
  - `selectedTab: Int`
  - `isAlertActive: Bool`
  - `pendingPingsCount: Int`
  - `nonResponsiveDependentsCount: Int`
- Added methods that will become TCA actions:
  - `setSelectedTab(_ tab: Int)`
  - `updateAlertStatus(_ isActive: Bool)`
  - `updatePendingPingsCount(_ count: Int)`
  - `updateNonResponsiveDependentsCount(_ count: Int)`
- Updated MainTabView to use MainTabViewModel and sync with UserViewModel

## Future Improvements

1. **QRScannerViewModel**: Create a dedicated view model for QRScannerView
2. **IntervalPickerViewModel**: Create a dedicated view model for IntervalPickerView
3. **AddContactSheetViewModel**: Create a dedicated view model for AddContactSheetView
4. **HomeViewModel**: Ensure HomeView has a dedicated view model
5. **RespondersViewModel**: Ensure RespondersView has a dedicated view model
6. **DependentsViewModel**: Ensure DependentsView has a dedicated view model
7. **ProfileViewModel**: Ensure ProfileView has a dedicated view model

## TCA Migration Guide

A comprehensive TCA migration guide has been created in `TCAMigrationGuide.md` that provides detailed steps for converting the current MVVM architecture to TCA.
