//
//  ScanResult.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Represents a unified result from either barcode or OCR text scanning
struct ScanResult: Codable, Identifiable, Hashable {
    let id = UUID()
    
    // MARK: - Scan Information
    let scanMode: ScanMode
    let rawData: String
    let scanDuration: TimeInterval
    let timestamp: Date
    
    // MARK: - Results
    let isSuccessful: Bool
    let product: FoodProduct?
    let aiResponse: AIResponse?
    let confidence: Double
    
    // MARK: - Error Handling
    let errorMessage: String?
    let errorCode: ScanErrorCode?
    
    // MARK: - Additional Metadata
    let deviceInfo: DeviceInfo?
    let processingSteps: [ProcessingStep]
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case scanMode = "scan_mode"
        case rawData = "raw_data"
        case scanDuration = "scan_duration"
        case timestamp
        case isSuccessful = "is_successful"
        case product
        case aiResponse = "ai_response"
        case confidence
        case errorMessage = "error_message"
        case errorCode = "error_code"
        case deviceInfo = "device_info"
        case processingSteps = "processing_steps"
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if both product and AI analysis are available
    var hasCompleteResults: Bool {
        return product != nil && aiResponse != nil
    }
    
    /// Returns true if sugar analysis is available and reliable
    var hasReliableSugarAnalysis: Bool {
        return aiResponse?.isReliable ?? false
    }
    
    /// Returns a user-friendly status description
    var statusDescription: String {
        if isSuccessful {
            if hasCompleteResults {
                return "Complete analysis available"
            } else if product != nil {
                return "Product found, analysis pending"
            } else if aiResponse != nil {
                return "Analysis complete, product details limited"
            } else {
                return "Scan successful"
            }
        } else {
            return errorMessage ?? "Scan failed"
        }
    }
    
    /// Returns formatted scan duration
    var scanDurationText: String {
        if scanDuration < 1.0 {
            return String(format: "%.0fms", scanDuration * 1000)
        } else {
            return String(format: "%.1fs", scanDuration)
        }
    }
    
    /// Returns the primary data source
    var primaryDataSource: DataSource {
        return product?.dataSource ?? .unknown
    }
    
    /// Returns true if this scan result contains sugar detection
    var containsSugar: Bool {
        return aiResponse?.containsSugar ?? false
    }
    
    /// Returns sugar analysis summary
    var sugarSummary: String? {
        return aiResponse?.summaryText
    }
    
    /// Returns confidence level description
    var confidenceDescription: String {
        switch confidence {
        case 0.9...1.0:
            return "Very High"
        case 0.75..<0.9:
            return "High"
        case 0.5..<0.75:
            return "Medium"
        case 0.25..<0.5:
            return "Low"
        default:
            return "Very Low"
        }
    }
    
    /// Returns true if the scan result should be retried
    var shouldRetry: Bool {
        return !isSuccessful && 
               errorCode != .userCancelled && 
               errorCode != .unsupportedFormat
    }
    
    /// Returns display name for the scanned item
    var displayName: String {
        if let productName = product?.displayName {
            return productName
        } else {
            switch scanMode {
            case .barcode:
                return "Barcode: \(rawData.prefix(20))"
            case .textOCR:
                return "Ingredient Text"
            }
        }
    }
}

// MARK: - Supporting Models and Enums

/// Scan modes supported by the application
enum ScanMode: String, CaseIterable, Codable {
    case barcode = "barcode"
    case textOCR = "text_ocr"
    
    var displayName: String {
        switch self {
        case .barcode:
            return "Barcode Scan"
        case .textOCR:
            return "Text OCR Scan"
        }
    }
    
    var description: String {
        switch self {
        case .barcode:
            return "Scan product barcodes to look up ingredients and nutritional information"
        case .textOCR:
            return "Scan ingredient lists directly from product packaging"
        }
    }
    
    var icon: String {
        switch self {
        case .barcode:
            return "barcode.viewfinder"
        case .textOCR:
            return "text.viewfinder"
        }
    }
    
    var recommendedFor: String {
        switch self {
        case .barcode:
            return "Packaged products with visible barcodes"
        case .textOCR:
            return "Clear ingredient lists or when barcode isn't available"
        }
    }
}

/// Error codes for different scan failure scenarios
enum ScanErrorCode: String, CaseIterable, Codable {
    // Camera and scanning errors
    case cameraPermissionDenied = "camera_permission_denied"
    case cameraUnavailable = "camera_unavailable"
    case scanTimeout = "scan_timeout"
    case lowImageQuality = "low_image_quality"
    case userCancelled = "user_cancelled"
    
    // Data processing errors
    case barcodeNotFound = "barcode_not_found"
    case unsupportedFormat = "unsupported_format"
    case textRecognitionFailed = "text_recognition_failed"
    case invalidData = "invalid_data"
    
    // Network and API errors
    case networkError = "network_error"
    case apiError = "api_error"
    case productNotFound = "product_not_found"
    case aiAnalysisFailed = "ai_analysis_failed"
    case rateLimitExceeded = "rate_limit_exceeded"
    
    // System errors
    case unknownError = "unknown_error"
    case insufficientStorage = "insufficient_storage"
    
    var displayName: String {
        switch self {
        case .cameraPermissionDenied:
            return "Camera Permission Denied"
        case .cameraUnavailable:
            return "Camera Unavailable"
        case .scanTimeout:
            return "Scan Timeout"
        case .lowImageQuality:
            return "Low Image Quality"
        case .userCancelled:
            return "User Cancelled"
        case .barcodeNotFound:
            return "Barcode Not Found"
        case .unsupportedFormat:
            return "Unsupported Format"
        case .textRecognitionFailed:
            return "Text Recognition Failed"
        case .invalidData:
            return "Invalid Data"
        case .networkError:
            return "Network Error"
        case .apiError:
            return "API Error"
        case .productNotFound:
            return "Product Not Found"
        case .aiAnalysisFailed:
            return "AI Analysis Failed"
        case .rateLimitExceeded:
            return "Rate Limit Exceeded"
        case .unknownError:
            return "Unknown Error"
        case .insufficientStorage:
            return "Insufficient Storage"
        }
    }
    
    var userMessage: String {
        switch self {
        case .cameraPermissionDenied:
            return "Please grant camera permission in Settings to scan barcodes"
        case .cameraUnavailable:
            return "Camera is not available on this device"
        case .scanTimeout:
            return "Scan took too long. Please try again"
        case .lowImageQuality:
            return "Image quality is too low. Try improving lighting"
        case .userCancelled:
            return "Scan was cancelled"
        case .barcodeNotFound:
            return "No barcode detected. Try repositioning the camera"
        case .unsupportedFormat:
            return "This barcode format is not supported"
        case .textRecognitionFailed:
            return "Could not read text. Try improving lighting or clarity"
        case .invalidData:
            return "The scanned data appears to be invalid"
        case .networkError:
            return "Network connection issue. Please check your internet"
        case .apiError:
            return "Service temporarily unavailable. Please try again later"
        case .productNotFound:
            return "Product not found in database"
        case .aiAnalysisFailed:
            return "Sugar analysis failed. Please try again"
        case .rateLimitExceeded:
            return "Too many requests. Please wait a moment and try again"
        case .unknownError:
            return "An unexpected error occurred"
        case .insufficientStorage:
            return "Not enough storage space available"
        }
    }
    
    var isRetryable: Bool {
        switch self {
        case .cameraPermissionDenied, .cameraUnavailable, .userCancelled, .unsupportedFormat:
            return false
        default:
            return true
        }
    }
}

/// Device information captured during scanning
struct DeviceInfo: Codable, Hashable {
    let deviceModel: String
    let osVersion: String
    let appVersion: String
    let cameraModel: String?
    let flashEnabled: Bool
    let orientation: String
    
    enum CodingKeys: String, CodingKey {
        case deviceModel = "device_model"
        case osVersion = "os_version"
        case appVersion = "app_version"
        case cameraModel = "camera_model"
        case flashEnabled = "flash_enabled"
        case orientation
    }
}

/// Individual processing steps for debugging and analytics
struct ProcessingStep: Codable, Hashable, Identifiable {
    let id = UUID()
    let step: String
    let duration: TimeInterval
    let success: Bool
    let details: String?
    
    enum CodingKeys: String, CodingKey {
        case step
        case duration
        case success
        case details
    }
    
    var durationText: String {
        if duration < 1.0 {
            return String(format: "%.0fms", duration * 1000)
        } else {
            return String(format: "%.2fs", duration)
        }
    }
}

// MARK: - Extensions

extension ScanResult {
    /// Creates a successful barcode scan result sample
    static let successfulBarcodeSample = ScanResult(
        scanMode: .barcode,
        rawData: "3017620422003",
        scanDuration: 0.85,
        timestamp: Date(),
        isSuccessful: true,
        product: .sample,
        aiResponse: .sample,
        confidence: 0.92,
        errorMessage: nil,
        errorCode: nil,
        deviceInfo: DeviceInfo(
            deviceModel: "iPhone 15 Pro",
            osVersion: "17.0",
            appVersion: "1.0.0",
            cameraModel: "Main Camera",
            flashEnabled: false,
            orientation: "portrait"
        ),
        processingSteps: [
            ProcessingStep(step: "Camera Capture", duration: 0.12, success: true, details: nil),
            ProcessingStep(step: "Barcode Detection", duration: 0.08, success: true, details: "EAN-13"),
            ProcessingStep(step: "API Lookup", duration: 0.45, success: true, details: "Open Food Facts"),
            ProcessingStep(step: "AI Analysis", duration: 0.20, success: true, details: "Sugar detection complete")
        ]
    )
    
    /// Creates a successful OCR text scan result sample
    static let successfulOCRSample = ScanResult(
        scanMode: .textOCR,
        rawData: "Sugar, palm oil, hazelnuts (13%), skimmed milk powder (8.7%), fat-reduced cocoa (7.4%)",
        scanDuration: 2.15,
        timestamp: Date(),
        isSuccessful: true,
        product: nil,
        aiResponse: .sample,
        confidence: 0.87,
        errorMessage: nil,
        errorCode: nil,
        deviceInfo: DeviceInfo(
            deviceModel: "iPhone 15 Pro",
            osVersion: "17.0",
            appVersion: "1.0.0",
            cameraModel: "Main Camera",
            flashEnabled: true,
            orientation: "portrait"
        ),
        processingSteps: [
            ProcessingStep(step: "Photo Capture", duration: 0.25, success: true, details: nil),
            ProcessingStep(step: "Text Recognition", duration: 1.20, success: true, details: "Vision Framework"),
            ProcessingStep(step: "Text Processing", duration: 0.15, success: true, details: "Cleanup and validation"),
            ProcessingStep(step: "AI Analysis", duration: 0.55, success: true, details: "Sugar detection complete")
        ]
    )
    
    /// Creates a failed scan result sample
    static let failedScanSample = ScanResult(
        scanMode: .barcode,
        rawData: "",
        scanDuration: 5.0,
        timestamp: Date(),
        isSuccessful: false,
        product: nil,
        aiResponse: nil,
        confidence: 0.0,
        errorMessage: "No barcode detected in image",
        errorCode: .barcodeNotFound,
        deviceInfo: DeviceInfo(
            deviceModel: "iPhone 15 Pro",
            osVersion: "17.0",
            appVersion: "1.0.0",
            cameraModel: "Main Camera",
            flashEnabled: false,
            orientation: "portrait"
        ),
        processingSteps: [
            ProcessingStep(step: "Camera Capture", duration: 0.15, success: true, details: nil),
            ProcessingStep(step: "Barcode Detection", duration: 4.85, success: false, details: "Timeout reached")
        ]
    )
    
    /// Creates a network error scan result sample
    static let networkErrorSample = ScanResult(
        scanMode: .barcode,
        rawData: "1234567890123",
        scanDuration: 3.2,
        timestamp: Date(),
        isSuccessful: false,
        product: nil,
        aiResponse: nil,
        confidence: 0.0,
        errorMessage: "Unable to connect to product database",
        errorCode: .networkError,
        deviceInfo: DeviceInfo(
            deviceModel: "iPhone 15 Pro",
            osVersion: "17.0",
            appVersion: "1.0.0",
            cameraModel: "Main Camera",
            flashEnabled: false,
            orientation: "portrait"
        ),
        processingSteps: [
            ProcessingStep(step: "Camera Capture", duration: 0.10, success: true, details: nil),
            ProcessingStep(step: "Barcode Detection", duration: 0.05, success: true, details: "EAN-13"),
            ProcessingStep(step: "API Lookup", duration: 3.05, success: false, details: "Network timeout")
        ]
    )
}