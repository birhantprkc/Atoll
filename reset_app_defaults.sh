#!/bin/bash

# Reset DynamicIsland App - Clear all defaults and app state
# This script simulates a fresh first launch of the app

set -e  # Exit on error

APP_NAME="DynamicIsland"
BUNDLE_ID="com.karthikinformationtechnology.DynamicIsland"

echo "🧹 Resetting $APP_NAME to factory defaults..."
echo ""

# Step 1: Kill the app if it's running
echo "1️⃣  Checking if $APP_NAME is running..."
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "   ⚠️  $APP_NAME is running. Terminating..."
    killall "$APP_NAME" 2>/dev/null || true
    sleep 1
    echo "   ✅ App terminated"
else
    echo "   ℹ️  $APP_NAME is not running"
fi

# Step 2: Clear UserDefaults
echo ""
echo "2️⃣  Clearing UserDefaults for $BUNDLE_ID..."
defaults delete "$BUNDLE_ID" 2>/dev/null && echo "   ✅ UserDefaults cleared" || echo "   ℹ️  No UserDefaults found (already clean)"

# Step 3: Remove Application Support files
echo ""
echo "3️⃣  Removing Application Support files..."
APP_SUPPORT_DIR="$HOME/Library/Application Support/$APP_NAME"
if [ -d "$APP_SUPPORT_DIR" ]; then
    rm -rf "$APP_SUPPORT_DIR"
    echo "   ✅ Removed: $APP_SUPPORT_DIR"
else
    echo "   ℹ️  No Application Support directory found"
fi

# Step 4: Remove Caches
echo ""
echo "4️⃣  Removing cached data..."
CACHE_DIR="$HOME/Library/Caches/$BUNDLE_ID"
if [ -d "$CACHE_DIR" ]; then
    rm -rf "$CACHE_DIR"
    echo "   ✅ Removed: $CACHE_DIR"
else
    echo "   ℹ️  No cache directory found"
fi

# Step 5: Remove Preferences plist (backup of defaults)
echo ""
echo "5️⃣  Removing preference files..."
PREF_FILE="$HOME/Library/Preferences/$BUNDLE_ID.plist"
if [ -f "$PREF_FILE" ]; then
    rm -f "$PREF_FILE"
    echo "   ✅ Removed: $PREF_FILE"
else
    echo "   ℹ️  No preference file found"
fi

# Step 6: Remove Saved Application State
echo ""
echo "6️⃣  Removing saved application state..."
SAVED_STATE_DIR="$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
if [ -d "$SAVED_STATE_DIR" ]; then
    rm -rf "$SAVED_STATE_DIR"
    echo "   ✅ Removed: $SAVED_STATE_DIR"
else
    echo "   ℹ️  No saved state found"
fi

# Done
echo ""
echo "✨ Reset complete! $APP_NAME will show onboarding on next launch."
echo ""
echo "To launch the app now, run:"
echo "  open -a $APP_NAME"
echo ""
