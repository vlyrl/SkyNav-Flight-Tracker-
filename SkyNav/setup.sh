#!/bin/bash
set -e

echo "SkyNav — Xcode project setup"
echo "=============================="

# Install xcodegen if needed
if ! command -v xcodegen &> /dev/null; then
    echo "Installing xcodegen via Homebrew..."
    brew install xcodegen
fi

# Generate Xcode project from project.yml
echo "Generating SkyNav.xcodeproj..."
xcodegen generate

echo ""
echo "Done! Open SkyNav.xcodeproj in Xcode."
echo ""
echo "Next steps:"
echo "  1. Set your Development Team in Signing & Capabilities"
echo "  2. Add an App Group: group.com.skynav.shared (main app + widget targets)"
echo "  3. Enable Push Notifications capability on the main target"
echo "  4. To use real flight data: implement FlightDataProvider and swap"
echo "       MockFlightDataService() for your real provider in SkyNavApp.swift"
echo "  5. For StoreKit: add a StoreKit Configuration file and set the product IDs:"
echo "       com.skynav.app.premium.monthly"
echo "       com.skynav.app.premium.annual"
