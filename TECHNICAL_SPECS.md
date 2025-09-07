# Technical Specifications - AI Sugar Detection App

This document provides detailed technical specifications for the AI-powered food ingredient analyzer with sugar detection capabilities.

## System Architecture

### High-Level Architecture
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   SwiftUI UI    │    │   Business Logic │    │  External APIs  │
│                 │    │                  │    │                 │
│ • Scanner Views │◄──►│ • Data Models    │◄──►│ • Open Food API │
│ • Result Views  │    │ • View Models    │    │ • AI Service    │
│ • Settings      │    │ • Services       │    │ • Cache Storage │
└─────────────────┘    └──────────────────┘    └─────────────────┘
           │                       │
           ▼                       ▼
┌─────────────────┐    ┌──────────────────┐
│  Camera System  │    │   Data Storage   │
│                 │    │                  │
│ • Barcode Scan  │    │ • CoreData/SQLite│
│ • OCR Text Scan │    │ • Keychain       │
│ • AVFoundation  │    │ • UserDefaults   │
└─────────────────┘    └──────────────────┘
```

## Data Models Specification

### FoodProduct
```swift
struct FoodProduct: Codable, Identifiable, Hashable {
    let id: UUID
    let barcode: String?
    let productName: String?
    let brands: String?
    let quantity: String?
    let packaging: String?
    let categories: [String]
    let ingredientsText: String?
    let allergens: [String]
    let traces: [String]
    let nutritionFacts: NutritionFacts?
    let labels: [String]
    let stores: [String]
    let countries: [String]
    let imageURL: URL?
    let ingredientsImageURL: URL?
    let nutritionImageURL: URL?
    let completenessScore: Double
    let dataSource: DataSource
    let lastModified: Date
    let createdAt: Date
}
```

### AIResponse
```swift
struct AIResponse: Codable, Identifiable {
    let id: UUID
    let requestId: String
    let ingredientsAnalyzed: String
    let containsSugar: Bool
    let sugarTypes: [SugarType]
    let sugarAnalysis: SugarAnalysis
    let confidence: Double
    let processingTime: TimeInterval
    let warnings: [String]
    let createdAt: Date
}

enum SugarType: String, CaseIterable, Codable {
    case sucrose = "sucrose"
    case glucose = "glucose"
    case fructose = "fructose"
    case lactose = "lactose"
    case maltose = "maltose"
    case highFructoseCornSyrup = "high_fructose_corn_syrup"
    case brownSugar = "brown_sugar"
    case honeyMaple = "honey_maple"
    case artificialSweetener = "artificial_sweetener"
    case sugarAlcohol = "sugar_alcohol"
}
```

### ScanResult
```swift
struct ScanResult: Codable, Identifiable {
    let id: UUID
    let scanMode: ScanMode
    let rawData: String
    let product: FoodProduct?
    let aiResponse: AIResponse?
    let scanDuration: TimeInterval
    let isSuccessful: Bool
    let errorMessage: String?
    let confidence: Double
    let timestamp: Date
}

enum ScanMode: String, CaseIterable, Codable {
    case barcode = "barcode"
    case textOCR = "text_ocr"
}
```

## API Specifications

### Open Food Facts API

#### Base Configuration
```
Base URL: https://world.openfoodfacts.org/api/v0/
Content-Type: application/json
User-Agent: AI-Sugar-Detection-iOS/1.0
Rate Limit: 100 requests/minute
```

#### Product Lookup Endpoint
```
GET /product/{barcode}.json

Parameters:
- barcode: String (EAN-8, EAN-13, UPC-A, UPC-E)

Response:
{
  "status": 1,
  "status_verbose": "product found",
  "product": {
    "product_name": "String",
    "brands": "String",
    "quantity": "String",
    "ingredients_text": "String",
    "allergens": "String",
    "traces": "String",
    "categories": "String",
    "labels": "String",
    "nutrition_grade_fr": "String",
    "nutriments": {
      "energy-kcal_100g": Number,
      "sugars_100g": Number,
      "carbohydrates_100g": Number,
      "fat_100g": Number,
      "proteins_100g": Number,
      "salt_100g": Number
    },
    "image_url": "String",
    "image_ingredients_url": "String",
    "image_nutrition_url": "String"
  }
}
```

### AI Service API

#### Configuration
```
Provider: OpenAI GPT-4 / Anthropic Claude / Custom
Authentication: Bearer Token
Rate Limit: Provider-specific
Cost: ~$0.001-0.01 per analysis
```

#### Sugar Analysis Endpoint
```
POST /analyze-ingredients

Headers:
- Authorization: Bearer {api_key}
- Content-Type: application/json

Request:
{
  "ingredients": "String (comma-separated ingredient list)",
  "language": "en|es|fr|de|it",
  "analysis_type": "sugar_detection",
  "detail_level": "basic|detailed|comprehensive"
}

Response:
{
  "analysis_id": "String",
  "contains_sugar": Boolean,
  "confidence": Number (0-1),
  "sugar_types": [
    {
      "type": "sucrose|glucose|fructose|...",
      "confidence": Number,
      "sources": ["ingredient_name"]
    }
  ],
  "sugar_analysis": {
    "total_sugar_indicators": Number,
    "hidden_sugars": ["ingredient_name"],
    "sugar_alternatives": ["ingredient_name"],
    "health_impact": "low|medium|high",
    "recommendations": ["String"]
  },
  "processing_time_ms": Number,
  "warnings": ["String"]
}
```

## Camera System Specifications

### Barcode Scanner Configuration
```swift
// AVCaptureSession Configuration
session.sessionPreset = .high
metadataObjectTypes = [
    .ean8,
    .ean13,
    .upce,
    .code128,
    .code39,
    .code93,
    .pdf417,
    .qr
]

// Performance Settings
session.automaticallyConfiguresApplicationAudioSession = false
videoInput.device.focusMode = .continuousAutoFocus
videoInput.device.exposureMode = .continuousAutoExposure
```

### OCR Text Scanner Configuration
```swift
// Vision Framework Configuration
let textRequest = VNRecognizeTextRequest()
textRequest.recognitionLevel = .accurate
textRequest.recognitionLanguages = ["en-US", "es-ES", "fr-FR", "de-DE"]
textRequest.usesLanguageCorrection = true

// Image Processing
compressionQuality = 0.8
maxImageSize = CGSize(width: 1920, height: 1080)
contrastEnhancement = true
```

## Data Storage Specifications

### Core Data Schema
```swift
// ProductEntity
@NSManaged var barcode: String?
@NSManaged var productName: String?
@NSManaged var ingredientsText: String?
@NSManaged var sugarAnalysis: Data? // Encoded AIResponse
@NSManaged var lastScanned: Date
@NSManaged var scanCount: Int32

// ScanHistoryEntity
@NSManaged var scanId: UUID
@NSManaged var scanMode: String
@NSManaged var rawData: String
@NSManaged var isSuccessful: Bool
@NSManaged var timestamp: Date
@NSManaged var product: ProductEntity?
```

### Cache Configuration
```swift
// URLCache for API responses
URLCache.shared = URLCache(
    memoryCapacity: 50 * 1024 * 1024,    // 50MB memory
    diskCapacity: 200 * 1024 * 1024,     // 200MB disk
    diskPath: "api_cache"
)

// Cache policies
openFoodFactsCache = 24.hours
aiResponseCache = 7.days
imageCache = 3.days
```

### Keychain Storage
```swift
// API Keys Storage
struct KeychainKeys {
    static let openFoodFactsKey = "off_api_key"
    static let aiServiceKey = "ai_service_key"
    static let userPreferences = "user_preferences"
}
```

## Performance Specifications

### Response Time Targets
- Barcode scan detection: < 500ms
- OCR text recognition: < 2 seconds
- API response (Open Food Facts): < 3 seconds
- AI analysis response: < 5 seconds
- App launch time: < 2 seconds

### Memory Usage Targets
- Base memory usage: < 50MB
- Peak memory (during scanning): < 100MB
- Image processing: < 150MB
- Background memory: < 30MB

### Battery Usage Targets
- Camera usage: < 5% battery drain per 10 minutes
- Background processing: Minimal impact
- Network requests: Batched and optimized

## Error Handling Specifications

### Error Types
```swift
enum AppError: LocalizedError {
    // Camera Errors
    case cameraPermissionDenied
    case cameraUnavailable
    case scanningFailed(String)
    
    // Network Errors
    case networkUnavailable
    case apiRateLimitExceeded
    case invalidAPIResponse(String)
    case authenticationFailed
    
    // AI Service Errors
    case aiServiceUnavailable
    case analysisTimeout
    case invalidIngredients
    case quotaExceeded
    
    // Data Errors
    case dataCorruption
    case storageSpaceLow
    case invalidBarcode
}
```

### Retry Logic
```swift
// Network requests
maxRetries = 3
retryDelay = [1, 2, 4] // Exponential backoff
timeoutInterval = 30.seconds

// AI analysis
maxRetries = 2
retryDelay = [5, 10] // seconds
timeoutInterval = 45.seconds
```

## Security Specifications

### Data Protection
```swift
// File Protection
NSFileProtectionComplete for user data
NSFileProtectionCompleteUntilFirstUserAuthentication for cache

// Network Security
URLSessionConfiguration.default.urlCredentialStorage = nil
certificate_pinning = true
tls_minimum_version = "1.2"
```

### Privacy Compliance
```swift
// Data Retention
scanHistory = 30.days
cachedImages = 7.days
apiResponses = 24.hours
analytics = opt_in_only

// Data Anonymization
removePersonalData = true
hashSensitiveData = true
localProcessingPreferred = true
```

## Testing Specifications

### Unit Test Coverage
- Data Models: 95%+
- Business Logic: 90%+
- API Services: 85%+
- View Models: 80%+

### Performance Test Targets
- Camera initialization: < 1 second
- Barcode detection accuracy: > 95%
- OCR accuracy (clean text): > 90%
- API response parsing: 100% success rate
- Memory leaks: 0 tolerance

### Integration Test Scenarios
1. End-to-end barcode scanning flow
2. End-to-end OCR scanning flow
3. Network failure recovery
4. Cache invalidation and refresh
5. Permission handling flows

## Deployment Specifications

### iOS Requirements
- Minimum iOS version: 15.0
- Xcode version: 15.0+
- Swift version: 5.9+
- Target architectures: arm64

### Build Configuration
```swift
// Release Configuration
SWIFT_OPTIMIZATION_LEVEL = -O
ENABLE_BITCODE = NO
VALIDATE_PRODUCT = YES
DEBUG_INFORMATION_FORMAT = dwarf-with-dsym

// Code Signing
DEVELOPMENT_TEAM = "Your Team ID"
CODE_SIGN_STYLE = Automatic
```

### App Store Metadata
```
App Category: Health & Fitness
Age Rating: 4+
Required Device Capabilities: camera-flash, front-facing-camera
Privacy Usage Descriptions:
- NSCameraUsageDescription
- NSPhotoLibraryUsageDescription (optional)
```

## Monitoring & Analytics

### Key Metrics
```swift
// Performance Metrics
scanSuccessRate: Double
averageScanTime: TimeInterval
aiAnalysisAccuracy: Double
crashRate: Double
appLaunchTime: TimeInterval

// Business Metrics
dailyActiveUsers: Int
scansPerSession: Double
sugarDetectionRate: Double
userRetentionRate: Double
```

### Error Tracking
```swift
// Crash Reporting
crashlytics_enabled = true
crash_reports = anonymized
performance_monitoring = opt_in

// Custom Events
scanAttempt(mode: ScanMode, success: Bool)
aiAnalysisCompleted(confidence: Double, processingTime: TimeInterval)
userInteraction(action: String, screen: String)
```

---

## Version History
- v1.0.0: Initial technical specifications
- Future versions will track specification updates

## Dependencies
- iOS 15.0+
- SwiftUI 3.0+
- AVFoundation
- Vision Framework
- Core Data
- Network Framework
- CryptoKit