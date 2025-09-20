# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a SwiftUI-based iOS app for AI-powered food ingredient analysis with sugar detection. The app features dual camera modes: barcode scanning to fetch product data from Open Food Facts API, and OCR text scanning to capture ingredient lists directly from food packaging. Both input methods feed into an AI service that analyzes ingredients for sugar content.

## Architecture

The app follows MVVM pattern with two primary scanning modes:

### Core Structure
- **BarcodeScannerApp.swift**: Main app entry point
- **Screens/**: Feature-based screen organization
- **Views/**: Reusable UI components and camera integrations
- **Services/**: API integrations and business logic
- **Models/**: Data models for food data and AI responses
- **Utilities/**: Shared utilities and configurations

### Dual Camera System
1. **Barcode Scanner Mode**: 
   - Scans EAN-8/EAN-13 barcodes
   - Fetches product data from Open Food Facts API
   - Extracts ingredient list from API response

2. **Text Scanner Mode**: 
   - Uses Vision framework OCR for ingredient text recognition
   - Processes captured text from food packaging
   - Direct ingredient list input for AI analysis

### AI Integration Flow
1. **Data Collection**: Either barcode → API → ingredients OR OCR → ingredients
2. **AI Processing**: Send ingredients to AI service for sugar analysis
3. **Result Display**: Show sugar detection results with confidence levels

## Camera Integration

### Barcode Scanner
- `ScannerVC`: AVFoundation camera session for barcode detection
- Metadata output configured for EAN-8/EAN-13 formats
- Delegate pattern for scan result communication

### Text Scanner (New)
- Vision framework integration for OCR
- AVCapturePhotoOutput for high-quality text capture
- Text recognition preprocessing and cleanup

## API Integrations

### Open Food Facts API
- Endpoint: `https://world.openfoodfacts.org/api/v0/product/{barcode}.json`
- Extracts: product name, ingredients list, nutritional data
- Handles multiple languages and data formats

### AI Sugar Detection Service
- Processes ingredient lists for sugar content analysis
- Returns: sugar presence, types of sugars found, confidence scores
- Supports batch ingredient analysis

## Data Models

### Food Product
- Barcode, name, brand, ingredients
- Nutritional information
- Sugar analysis results

### AI Response
- Sugar detection boolean
- Sugar types identified
- Confidence percentages
- Detailed analysis breakdown

## Build Commands

This is an Xcode project. Common development tasks:
- Open project: `open ../BarcodeScanner.xcodeproj` 
- Build from command line: `xcodebuild -project ../BarcodeScanner.xcodeproj -scheme BarcodeScanner build`
- Run tests: `xcodebuild test -project ../BarcodeScanner.xcodeproj -scheme BarcodeScanner -destination 'platform=iOS Simulator,name=iPhone 15'`

Note: The Xcode project file is located one directory up from the source files.

## Key Dependencies

### Core Frameworks
- SwiftUI for UI layer
- AVFoundation for camera functionality
- Vision for OCR text recognition
- Combine for reactive data flow

### Network & AI
- URLSession for API calls
- JSONDecoder for response parsing
- AI service integration (OpenAI/Anthropic/Custom)

### Camera Integration
- UIViewControllerRepresentable for UIKit bridging
- AVCaptureSession for both barcode and photo capture
- AVCaptureMetadataOutput for barcode detection
- AVCapturePhotoOutput for OCR image capture

## Development Notes

### Camera Permissions
App requires camera permissions for both scanning modes. Handle authorization states properly.

### API Rate Limiting
Open Food Facts API has rate limits. Implement appropriate caching and retry logic.

### OCR Accuracy
Text recognition accuracy depends on image quality. Implement image preprocessing for better results.

### AI Service Costs
Monitor AI service usage costs. Consider implementing result caching for identical ingredient lists.