# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

LifeSignal is a multi-platform emergency response application with iOS production app, iOS mock app, Android app, and backend components.

## Architecture Patterns

**iOS Production App** (`iOSApplication/`): Uses The Composable Architecture (TCA)
- Features use `@Reducer` with `@ObservableState` for state management
- Dependencies injected via `@DependencyClient` from swift-dependencies
- Navigation handled by swift-navigation
- Testing with TCA's testing tools

**iOS Mock App** (`iOSMockApplication/`): Uses vanilla SwiftUI MVVM
- View models use `@StateObject` and `@ObservableObject`
- Simpler state management for learning/prototyping

**Android App** (`AndroidApplication/`): Uses Jetpack Compose with MVVM
- Firebase integration for authentication and backend services
- CameraX and ML Kit for QR code scanning

## Common Commands

### iOS Development
```bash
# Build iOS production app
cd iOSApplication/LifeSignal && xcodebuild -scheme LifeSignal build

# Build iOS mock app  
cd iOSMockApplication && xcodebuild -scheme MockApplication build

# Run iOS tests
cd iOSApplication/LifeSignal && xcodebuild test -scheme LifeSignal -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Android Development
```bash
# Build Android app
cd AndroidApplication/LifeSignal && ./gradlew build

# Run Android tests
cd AndroidApplication/LifeSignal && ./gradlew test

# Generate debug APK
cd AndroidApplication/LifeSignal && ./gradlew assembleDebug
```

### Backend/MCP Server
```bash
# Build TypeScript MCP server
cd vertex-ai-mcp-server-main && bun run build

# Development mode with watch
cd vertex-ai-mcp-server-main && bun run watch

# Test MCP server with inspector
cd vertex-ai-mcp-server-main && bunx @modelcontextprotocol/inspector build/index.js
```

## Key Dependencies

**iOS Production**: SwiftUI, TCA, swift-dependencies, swift-navigation, Firebase SDK
**iOS Mock**: SwiftUI, Firebase SDK  
**Android**: Jetpack Compose, Firebase SDK, CameraX, ML Kit, kotlinx.serialization
**Backend**: TypeScript, Vertex AI SDK, Model Context Protocol SDK

## Architecture Documentation

Comprehensive architecture documentation exists in `Architecture/` following strict formatting guidelines:
- `Architecture/Backend/` - Firebase auth, Supabase database/storage, Fly.io APIs
- `Architecture/iOS/MockApplication/` - MVVM patterns and simple state management
- `Architecture/iOS/ProductionApplication/` - TCA patterns, features, and dependency clients

## Code Conventions

- Follow existing patterns within each application
- iOS Production: Use TCA's `@Reducer` and dependency injection patterns
- iOS Mock: Keep state management simple with basic view models
- Android: Follow modern Android architecture with Compose
- All apps use Firebase for authentication and backend services