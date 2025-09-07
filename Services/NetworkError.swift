//
//  NetworkError.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Comprehensive error handling for all network and service operations
enum NetworkError: LocalizedError, Equatable {
    
    // MARK: - Network Errors
    case noInternetConnection
    case requestTimeout
    case invalidURL(String)
    case invalidResponse
    case serverError(Int, String?)
    case dataCorrupted
    case requestFailed(Error)
    
    // MARK: - API Specific Errors
    case rateLimitExceeded(retryAfter: TimeInterval?)
    case authenticationFailed
    case apiKeyMissing
    case apiKeyInvalid
    case quotaExceeded
    case serviceUnavailable
    
    // MARK: - Open Food Facts Errors
    case productNotFound(String)
    case invalidBarcode(String)
    case incompleteProductData
    
    // MARK: - AI Service Errors
    case aiServiceUnavailable
    case analysisTimeout
    case invalidIngredients
    case aiProcessingError(String)
    case insufficientTokens
    
    // MARK: - Cache Errors
    case cacheReadError
    case cacheWriteError
    case cacheCorrupted
    case diskSpaceInsufficient
    
    // MARK: - Validation Errors
    case invalidInput(String)
    case missingRequiredField(String)
    case dataValidationFailed
    
    // MARK: - Security Errors
    case certificatePinningFailed
    case insecureConnection
    case dataIntegrityCheckFailed
    
    // MARK: - LocalizedError Implementation
    
    var errorDescription: String? {
        switch self {
        // Network Errors
        case .noInternetConnection:
            return "No internet connection available. Please check your network settings."
        case .requestTimeout:
            return "The request timed out. Please try again."
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .invalidResponse:
            return "Invalid response received from server."
        case .serverError(let code, let message):
            if let message = message {
                return "Server error (\(code)): \(message)"
            } else {
                return "Server error (\(code))"
            }
        case .dataCorrupted:
            return "The received data is corrupted."
        case .requestFailed(let error):
            return "Request failed: \(error.localizedDescription)"
            
        // API Specific Errors
        case .rateLimitExceeded(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limit exceeded. Please try again in \(Int(retryAfter)) seconds."
            } else {
                return "Rate limit exceeded. Please try again later."
            }
        case .authenticationFailed:
            return "Authentication failed. Please check your API credentials."
        case .apiKeyMissing:
            return "API key is missing. Please configure your API credentials."
        case .apiKeyInvalid:
            return "API key is invalid. Please check your credentials."
        case .quotaExceeded:
            return "API quota exceeded. Please upgrade your plan or try again later."
        case .serviceUnavailable:
            return "Service is temporarily unavailable. Please try again later."
            
        // Open Food Facts Errors
        case .productNotFound(let barcode):
            return "Product not found for barcode: \(barcode)"
        case .invalidBarcode(let barcode):
            return "Invalid barcode format: \(barcode)"
        case .incompleteProductData:
            return "Product data is incomplete or missing ingredients."
            
        // AI Service Errors
        case .aiServiceUnavailable:
            return "AI service is currently unavailable. Please try again later."
        case .analysisTimeout:
            return "Analysis timed out. Please try with a shorter ingredient list."
        case .invalidIngredients:
            return "Invalid or empty ingredients provided for analysis."
        case .aiProcessingError(let message):
            return "AI processing error: \(message)"
        case .insufficientTokens:
            return "Insufficient tokens for AI analysis. Please upgrade your plan."
            
        // Cache Errors
        case .cacheReadError:
            return "Failed to read cached data."
        case .cacheWriteError:
            return "Failed to save data to cache."
        case .cacheCorrupted:
            return "Cache data is corrupted and will be cleared."
        case .diskSpaceInsufficient:
            return "Insufficient disk space for caching."
            
        // Validation Errors
        case .invalidInput(let field):
            return "Invalid input for field: \(field)"
        case .missingRequiredField(let field):
            return "Missing required field: \(field)"
        case .dataValidationFailed:
            return "Data validation failed."
            
        // Security Errors
        case .certificatePinningFailed:
            return "Certificate pinning validation failed."
        case .insecureConnection:
            return "Insecure connection detected."
        case .dataIntegrityCheckFailed:
            return "Data integrity check failed."
        }
    }
    
    var failureReason: String? {
        switch self {
        case .noInternetConnection:
            return "The device is not connected to the internet."
        case .requestTimeout:
            return "The server took too long to respond."
        case .serverError(let code, _):
            return "The server returned error code \(code)."
        case .rateLimitExceeded:
            return "Too many requests have been made in a short period."
        case .authenticationFailed:
            return "The provided API credentials are invalid."
        case .productNotFound:
            return "The scanned product is not in the database."
        case .aiServiceUnavailable:
            return "The AI analysis service is experiencing issues."
        case .cacheCorrupted:
            return "The cached data has been corrupted and needs to be cleared."
        default:
            return nil
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .noInternetConnection:
            return "Check your WiFi or cellular connection and try again."
        case .requestTimeout:
            return "Ensure you have a stable internet connection and try again."
        case .rateLimitExceeded:
            return "Wait a few minutes before making another request."
        case .authenticationFailed, .apiKeyInvalid:
            return "Check your API key in the app settings."
        case .productNotFound:
            return "Try scanning a different product or manually entering ingredients."
        case .aiServiceUnavailable:
            return "Try again in a few minutes, or contact support if the problem persists."
        case .cacheCorrupted:
            return "The app will clear corrupted data and rebuild the cache."
        case .diskSpaceInsufficient:
            return "Free up some storage space on your device."
        default:
            return "Please try again or contact support if the problem persists."
        }
    }
    
    // MARK: - Error Categories
    
    /// Determines if this error is recoverable through retry
    var isRetryable: Bool {
        switch self {
        case .requestTimeout, .serverError(let code, _) where code >= 500,
             .serviceUnavailable, .aiServiceUnavailable, .noInternetConnection:
            return true
        case .rateLimitExceeded:
            return true
        default:
            return false
        }
    }
    
    /// Determines if this error should be logged for debugging
    var shouldLog: Bool {
        switch self {
        case .productNotFound, .invalidBarcode:
            return false // These are expected in normal operation
        default:
            return true
        }
    }
    
    /// Returns the appropriate retry delay in seconds
    var retryDelay: TimeInterval {
        switch self {
        case .rateLimitExceeded(let retryAfter):
            return retryAfter ?? 60
        case .requestTimeout:
            return 2
        case .serverError(let code, _) where code >= 500:
            return 5
        case .serviceUnavailable, .aiServiceUnavailable:
            return 10
        default:
            return 1
        }
    }
    
    /// HTTP status code if applicable
    var httpStatusCode: Int? {
        switch self {
        case .serverError(let code, _):
            return code
        case .authenticationFailed:
            return 401
        case .rateLimitExceeded:
            return 429
        case .serviceUnavailable:
            return 503
        default:
            return nil
        }
    }
}

// MARK: - Convenience Initializers

extension NetworkError {
    /// Creates a NetworkError from URLError
    static func from(urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .noInternetConnection
        case .timedOut:
            return .requestTimeout
        case .badURL:
            return .invalidURL(urlError.failingURL?.absoluteString ?? "Unknown URL")
        case .cannotParseResponse, .badServerResponse:
            return .invalidResponse
        case .userAuthenticationRequired:
            return .authenticationFailed
        default:
            return .requestFailed(urlError)
        }
    }
    
    /// Creates a NetworkError from HTTPURLResponse
    static func from(httpResponse: HTTPURLResponse, data: Data?) -> NetworkError {
        let statusCode = httpResponse.statusCode
        var message: String?
        
        // Try to extract error message from response data
        if let data = data {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMessage = json["message"] as? String ?? json["error"] as? String {
                message = errorMessage
            } else if let stringMessage = String(data: data, encoding: .utf8) {
                message = stringMessage
            }
        }
        
        switch statusCode {
        case 401:
            return .authenticationFailed
        case 403:
            return .apiKeyInvalid
        case 404:
            return .productNotFound("Unknown")
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            return .rateLimitExceeded(retryAfter: retryAfter)
        case 503:
            return .serviceUnavailable
        default:
            return .serverError(statusCode, message)
        }
    }
}

// MARK: - Error Logging

extension NetworkError {
    /// Returns a dictionary suitable for error logging
    var loggingInfo: [String: Any] {
        var info: [String: Any] = [
            "error_type": String(describing: self),
            "is_retryable": isRetryable,
            "retry_delay": retryDelay
        ]
        
        if let statusCode = httpStatusCode {
            info["http_status_code"] = statusCode
        }
        
        if let description = errorDescription {
            info["description"] = description
        }
        
        return info
    }
}