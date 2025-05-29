#!/bin/bash

# Script to enable macros and build the LifeSignal project

echo "🔧 Enabling Swift macros for LifeSignal project..."

# Change to project directory
cd "$(dirname "$0")"

# Clean any existing build artifacts
echo "🧹 Cleaning build artifacts..."
xcodebuild clean -quiet 2>/dev/null || true

# Remove derived data to start fresh
echo "🗑️  Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/LifeSignal-* 2>/dev/null || true

# Open Xcode to trigger macro approval dialogs
echo "📱 Opening Xcode for macro approval..."
open LifeSignal.xcodeproj

# Wait a moment for Xcode to load
sleep 3

# Display instructions
echo ""
echo "🚨 MANUAL ACTION REQUIRED:"
echo "1. Xcode should now be open with macro trust dialogs"
echo "2. Click 'Trust & Enable' for ALL macros:"
echo "   - ComposableArchitectureMacros"
echo "   - LifeSignalMacros"
echo "   - Any other macro dependencies"
echo "3. If no dialog appears, try building (Cmd+B) to trigger them"
echo ""
echo "Once you've approved the macros, press ENTER to continue with the build..."
read -r

# Attempt to build the project
echo "🔨 Building project..."
echo "If this fails with macro errors, you may need to approve more macros in Xcode"
echo ""

xcodebuild -scheme LifeSignal -destination 'platform=iOS Simulator,name=iPhone 15' build

BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    echo ""
    echo "✅ BUILD SUCCEEDED! Macros are now properly enabled."
else
    echo ""
    echo "❌ Build failed. Possible solutions:"
    echo "1. Check Xcode for additional macro approval dialogs"
    echo "2. Go to Xcode → Settings → Locations → Advanced → Build System → Legacy"
    echo "3. Restart Xcode and try again"
    echo "4. Check the build output above for specific macro errors"
fi

exit $BUILD_RESULT