#!/usr/bin/env bash
# setup_project.sh
# Run this AFTER creating your Xcode project to organize source files.
# Usage: chmod +x setup_project.sh && ./setup_project.sh /path/to/YourXcodeProject

DEST="${1:-.}"

echo "📁 Creating folder structure in $DEST..."

mkdir -p "$DEST/Vaulted/App"
mkdir -p "$DEST/Vaulted/Models"
mkdir -p "$DEST/Vaulted/Persistence"
mkdir -p "$DEST/Vaulted/Services/Audio"
mkdir -p "$DEST/Vaulted/Services/Security"
mkdir -p "$DEST/Vaulted/Repositories"
mkdir -p "$DEST/Vaulted/ViewModels"
mkdir -p "$DEST/Vaulted/Views/Screens"
mkdir -p "$DEST/Vaulted/Views/Components"
mkdir -p "$DEST/Vaulted/Theme"

echo "✅ Folder structure created."
echo ""
echo "Next steps:"
echo "1. Drag all .swift files from each folder into the corresponding Xcode group"
echo "2. Replace the auto-generated .xcdatamodeld with Vaulted.xcdatamodeld"
echo "3. Replace Info.plist with the provided one (or merge the keys manually)"
echo "4. Set iOS Deployment Target to 16.0"
echo "5. Build & Run — first launch seeds drawers automatically"
echo ""
echo "📱 The app requires a device or simulator with Face ID enrolled for Private drawer."
echo "   In Simulator: Features → Face ID → Enrolled, then Matching Face to authenticate."
