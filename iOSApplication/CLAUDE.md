# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LifeSignal is an iOS application built using The Composable Architecture (TCA) with Firebase integration for emergency response and contact management.

## Architecture Pattern

The application uses **The Composable Architecture (TCA)** v1.19.1:
- Features use `@Reducer` with `@ObservableState` for state management
- Dependencies are injected via `@DependencyClient` from swift-dependencies
- Navigation is handled using `@Presents` and `PresentationAction` from swift-navigation
- Shared state is managed with `@Shared` and persistence keys from swift-sharing

## Key Dependencies

- **ComposableArchitecture** (v1.19.1) - Core TCA framework
- **swift-dependencies** (v1.9.2) - Dependency injection
- **swift-navigation** (v2.3.0) - Navigation helpers
- **swift-sharing** (v2.5.2) - Shared state management
- **Firebase** (v11.12.0) - Auth, Firestore, Messaging, Functions, AppCheck

## Build Commands

```bash
# Build the app and review errors, if any
xcodebuild -scheme LifeSignal -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1 | tail -100

# Run tests
xcodebuild test -scheme LifeSignal -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for specific configuration
xcodebuild -scheme LifeSignal -configuration Debug
xcodebuild -scheme LifeSignal -configuration Release

# Clean build folder
xcodebuild -scheme LifeSignal clean
```

## Development Guidelines

ensure that our views UI do not deviate from our reference views in the following ReferenceViews folder: iOSApplication/ReferenceViews

## Project Configuration

- **Bundle ID:** com.tojkuv.LifeSignal
- **Deployment Target:** iOS 17.6
- **Swift Version:** 6.0
- **Team ID:** 5WK7M4ZSVR
- **Firebase Config:** GoogleService-Info.plist