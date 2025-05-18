# Mock Application

This directory contains a mock version of the LifeSignal iOS application, designed for UI iteration purposes without business logic.

## Purpose

The mock application serves as a sandbox for UI development and iteration, allowing designers and developers to:

1. Test UI components in isolation
2. Iterate on UI designs without affecting the production codebase
3. Demonstrate UI flows without requiring backend integration
4. Serve as a reference for implementing the production app

## Structure

The mock application follows a similar structure to the production app, but uses vanilla Swift (not TCA) with mock data instead of real business logic:

```
MockApplication/
├── App/ (App-wide components)
│   ├── MockApplicationApp.swift (App entry point)
│   ├── AppView.swift (Main app view that handles authentication state)
│   └── ContentView.swift (Tab-based navigation)
│
├── Core/ (Shared core functionality)
│   ├── Domain/ (Domain models and view models)
│   │   ├── User/ (User-related models and view models)
│   │   ├── Contacts/ (Contact-related models and view models)
│   │   └── App/ (App-wide state)
│   │
│   ├── Services/ (Mock services)
│   │   ├── UserService.swift (User-related operations)
│   │   ├── ContactsService.swift (Contact-related operations)
│   │   └── QRCodeService.swift (QR code operations)
│   │
│   ├── Utilitites/ (Shared utilities)
│   │   ├── TimeFormatting.swift (Time formatting utilities)
│   │   ├── HapticFeedback.swift (Haptic feedback utilities)
│   │   └── QRCodeViewModel.swift (QR code utilities)
│   │
│   ├── Extensions/ (Swift extensions)
│   │   └── Views/ (View extensions)
│   │
│   └── Styles/ (SwiftUI styles and shapes)
│
└── Features/ (Feature modules)
    ├── SignInSignUp/ (Authentication features)
    │   ├── Authentication/ (Sign-in feature)
    │   └── Onboarding/ (Onboarding feature)
    │
    ├── TabScreens/ (Main tab screens)
    │   ├── Home/ (Home feature)
    │   ├── Responders/ (Responders feature)
    │   ├── Dependents/ (Dependents feature)
    │   └── Profile/ (Profile feature)
    │
    ├── QRCodeSystem/ (QR code features)
    │   ├── QRCode/ (QR code generation)
    │   └── QRScanner/ (QR code scanning)
    │
    └── ContactDetailsSheetView/ (Contact details sheet)
```

## Key Components

### View Models

The mock application uses simple ObservableObject view models instead of TCA features:

- **UserViewModel**: Manages user data and operations
- **AppState**: Manages global app state

### Mock Data

The mock application uses hardcoded mock data instead of fetching from a backend:

- **Contact.mockContacts()**: Returns a list of mock contacts
- **UserViewModel**: Contains mock user data

### UI Components

The mock application includes all the UI components from the production app, but with simplified functionality:

- **QRCodeView**: Displays a QR code
- **QRScannerView**: Scans QR codes
- **HomeView**: Displays the home screen
- **RespondersView**: Displays the responders screen
- **DependentsView**: Displays the dependents screen
- **ProfileView**: Displays the profile screen

## Usage

The mock application can be run in the iOS simulator or on a physical device. It does not require any backend services to function.

## Transition to Production

When transitioning from the mock app to the production app, the UI components can be reused with minimal changes. The main differences are:

1. The production app uses TCA (The Composable Architecture) instead of vanilla Swift
2. The production app uses real backend services instead of mock data
3. The production app has more robust error handling and state management

## Future Improvements

- Add more comprehensive mock data to cover a wider range of test cases
- Implement more UI components from the production app
- Add more realistic error handling and loading states
