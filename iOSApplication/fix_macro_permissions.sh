#!/bin/bash

echo "🔧 LifeSignal Macro Permission Fix Script"
echo "========================================"
echo ""

# Navigate to project directory
cd "$(dirname "$0")/LifeSignal"

echo "📍 Current directory: $(pwd)"
echo ""

# Step 1: Clean everything
echo "🧹 Step 1: Cleaning project..."
xcodebuild clean -quiet 2>/dev/null || true
rm -rf ~/Library/Developer/Xcode/DerivedData/LifeSignal-* 2>/dev/null || true
echo "   ✅ Cleaned build artifacts and derived data"
echo ""

# Step 2: Open Xcode
echo "📱 Step 2: Opening Xcode..."
open LifeSignal.xcodeproj
echo "   ✅ Xcode should now be opening..."
echo ""

# Step 3: Wait and provide instructions
echo "⏳ Waiting 5 seconds for Xcode to load..."
sleep 5
echo ""

echo "🚨 CRITICAL: MANUAL ACTION REQUIRED IN XCODE"
echo "============================================"
echo ""
echo "In Xcode, you MUST do the following:"
echo ""
echo "1. 📋 Go to Product → Build (or press Cmd+B)"
echo "2. 🔍 Look for build errors about macros needing to be enabled"
echo "3. 🔒 You should see errors like:"
echo "   'Macro \"ComposableArchitectureMacros\" must be enabled before it can be used'"
echo ""
echo "4. ✅ For EACH macro error, click the 'Trust & Enable' button"
echo "   - ComposableArchitectureMacros (from swift-composable-architecture)"
echo "   - LifeSignalMacros (local macros)"
echo "   - Any other macro packages that appear"
echo ""
echo "5. 🔄 After enabling all macros, build again (Cmd+B)"
echo ""
echo "Alternative if no 'Trust & Enable' buttons appear:"
echo "- Go to Xcode → Settings → Locations → Advanced"
echo "- Try switching Build System to 'Legacy Build System'"
echo "- Or check Security & Privacy settings for macros"
echo ""
echo "Once you've enabled all macros in Xcode, press ENTER here to test..."
read -r

# Step 4: Test the build
echo ""
echo "🔨 Step 4: Testing build after macro enablement..."
echo ""

BUILD_OUTPUT=$(xcodebuild -scheme LifeSignal -destination 'platform=iOS Simulator,name=iPhone 15' build 2>&1)
BUILD_RESULT=$?

if [ $BUILD_RESULT -eq 0 ]; then
    echo "🎉 SUCCESS! Build completed successfully!"
    echo "✅ All macros are now properly enabled."
    echo ""
    echo "Your project is ready to use! 🚀"
else
    echo "❌ Build still failing. Analyzing errors..."
    echo ""
    
    # Check for specific macro errors
    if echo "$BUILD_OUTPUT" | grep -q "must be enabled before it can be used"; then
        echo "🔍 Still seeing macro permission errors:"
        echo "$BUILD_OUTPUT" | grep "must be enabled before it can be used"
        echo ""
        echo "💡 Solutions:"
        echo "1. Go back to Xcode and look for more 'Trust & Enable' buttons"
        echo "2. Try Product → Clean Build Folder, then build again"
        echo "3. Restart Xcode completely and try again"
        echo "4. Check Xcode → Settings → Locations → Advanced for macro settings"
    else
        echo "🔍 Different build errors found:"
        echo "$BUILD_OUTPUT" | tail -20
        echo ""
        echo "💡 This might be a different issue. Check the build output above."
    fi
fi

exit $BUILD_RESULT