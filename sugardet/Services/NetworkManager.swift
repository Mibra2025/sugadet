//
//  NetworkManager.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation
import Network
import CryptoKit

/// Base networking service providing secure, reliable HTTP communication
@MainActor
final class NetworkManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = NetworkManager()
    
    // MARK: - Properties
    private let session: URLSession
    private let networkMonitor: NWPathMonitor
    private let monitorQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published private(set) var isNetworkAvailable = true
    @Published private(set) var connectionType: NWInterface.InterfaceType?
    
    // Security configuration
    private let pinnedCertificates: Set<String> = []  // Add certificate hashes in production
    private let trustedHosts: Set<String> = [
        "world.openfoodfacts.org",
        "api.openai.com",
        "api.anthropic.com"
    ]
    
    // Request configuration
    private let defaultTimeout: TimeInterval = 30
    private let defaultCachePolicy: URLRequest.CachePolicy = .returnCacheDataElseLoad
    
    // MARK: - Initialization
    
    private init() {
        // Configure URLSession for security and performance
        let configuration = URLSessionConfiguration.default
        
        // Security settings
        configuration.urlCredentialStorage = nil
        configuration.urlCache = URLCache(
            memoryCapacity: 50 * 1024 * 1024,    // 50MB memory
            diskCapacity: 200 * 1024 * 1024,     // 200MB disk
            diskPath: "network_cache"
        )
        configuration.requestCachePolicy = defaultCachePolicy
        configuration.timeoutIntervalForRequest = defaultTimeout
        configuration.timeoutIntervalForResource = defaultTimeout * 2
        
        // HTTP settings
        configuration.httpMaximumConnectionsPerHost = 5
        configuration.httpShouldUsePipelining = true
        configuration.httpShouldSetCookies = false
        
        // TLS settings
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        
        self.session = URLSession(
            configuration: configuration,
            delegate: NetworkSessionDelegate(),
            delegateQueue: nil
        )
        
        // Network monitoring
        self.networkMonitor = NWPathMonitor()
        setupNetworkMonitoring()
    }
    
    deinit {
        networkMonitor.cancel()
    }
    
    // MARK: - Network Monitoring
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type
            }
        }
        networkMonitor.start(queue: monitorQueue)
    }
    
    // MARK: - Core Networking Methods
    
    /// Performs a generic network request with comprehensive error handling and retry logic
    func performRequest<T: Codable>(
        _ request: URLRequest,
        responseType: T.Type,
        retryCount: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> T {
        
        // Check network availability
        guard isNetworkAvailable else {
            throw NetworkError.noInternetConnection
        }
        
        // Validate request
        try validateRequest(request)
        
        // Perform request with retry logic
        return try await performRequestWithRetry(
            request,
            responseType: responseType,
            retryCount: retryCount,
            retryDelay: retryDelay
        )
    }
    
    /// Performs a request that returns raw data
    func performDataRequest(
        _ request: URLRequest,
        retryCount: Int = 3,
        retryDelay: TimeInterval = 1.0
    ) async throws -> Data {
        
        guard isNetworkAvailable else {
            throw NetworkError.noInternetConnection
        }
        
        try validateRequest(request)
        
        return try await performDataRequestWithRetry(
            request,
            retryCount: retryCount,
            retryDelay: retryDelay
        )
    }
    
    // MARK: - Private Implementation
    
    private func performRequestWithRetry<T: Codable>(
        _ request: URLRequest,
        responseType: T.Type,
        retryCount: Int,
        retryDelay: TimeInterval
    ) async throws -> T {
        
        var lastError: NetworkError?
        
        for attempt in 0..<max(1, retryCount + 1) {
            do {
                let (data, response) = try await session.data(for: request)
                
                // Validate HTTP response
                let validatedData = try validateHTTPResponse(response, data: data, for: request)
                
                // Log successful request (in debug mode)
                #if DEBUG
                logRequest(request, response: response, data: validatedData, attempt: attempt + 1)
                #endif
                
                // Decode response
                return try decodeResponse(validatedData, to: responseType)
                
            } catch let error as NetworkError {
                lastError = error
                
                // Don't retry if error is not retryable or this is the last attempt
                if !error.isRetryable || attempt == retryCount {
                    throw error
                }
                
                // Wait before retry with exponential backoff
                let delay = error.retryDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                let networkError = NetworkError.from(urlError: error as? URLError ?? URLError(.unknown))
                lastError = networkError
                
                if !networkError.isRetryable || attempt == retryCount {
                    throw networkError
                }
                
                try await Task.sleep(nanoseconds: UInt64(retryDelay * pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.requestFailed(NSError(domain: "NetworkManager", code: -1))
    }
    
    private func performDataRequestWithRetry(
        _ request: URLRequest,
        retryCount: Int,
        retryDelay: TimeInterval
    ) async throws -> Data {
        
        var lastError: NetworkError?
        
        for attempt in 0..<max(1, retryCount + 1) {
            do {
                let (data, response) = try await session.data(for: request)
                
                // Validate HTTP response
                let validatedData = try validateHTTPResponse(response, data: data, for: request)
                
                #if DEBUG
                logRequest(request, response: response, data: validatedData, attempt: attempt + 1)
                #endif
                
                return validatedData
                
            } catch let error as NetworkError {
                lastError = error
                
                if !error.isRetryable || attempt == retryCount {
                    throw error
                }
                
                let delay = error.retryDelay * pow(2.0, Double(attempt))
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                
            } catch {
                let networkError = NetworkError.from(urlError: error as? URLError ?? URLError(.unknown))
                lastError = networkError
                
                if !networkError.isRetryable || attempt == retryCount {
                    throw networkError
                }
                
                try await Task.sleep(nanoseconds: UInt64(retryDelay * pow(2.0, Double(attempt)) * 1_000_000_000))
            }
        }
        
        throw lastError ?? NetworkError.requestFailed(NSError(domain: "NetworkManager", code: -1))
    }
    
    // MARK: - Request/Response Validation
    
    private func validateRequest(_ request: URLRequest) throws {
        guard let url = request.url else {
            throw NetworkError.invalidURL("Missing URL")
        }
        
        guard let host = url.host else {
            throw NetworkError.invalidURL("Invalid host")
        }
        
        // Ensure HTTPS for production
        #if !DEBUG
        guard url.scheme == "https" else {
            throw NetworkError.insecureConnection
        }
        #endif
        
        // Validate trusted hosts in production
        #if !DEBUG
        guard trustedHosts.contains(host) else {
            throw NetworkError.insecureConnection
        }
        #endif
    }
    
    private func validateHTTPResponse(
        _ response: URLResponse,
        data: Data,
        for request: URLRequest
    ) throws -> Data {
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Handle different HTTP status codes
        switch httpResponse.statusCode {
        case 200...299:
            return data
        case 400...599:
            throw NetworkError.from(httpResponse: httpResponse, data: data)
        default:
            throw NetworkError.serverError(httpResponse.statusCode, nil)
        }
    }
    
    private func decodeResponse<T: Codable>(_ data: Data, to type: T.Type) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(type, from: data)
        } catch {
            // Log decoding error for debugging
            #if DEBUG
            print("Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Raw JSON: \(jsonString)")
            }
            #endif
            throw NetworkError.dataCorrupted
        }
    }
    
    // MARK: - Request Builders
    
    /// Creates a GET request with standard headers
    func createGetRequest(url: URL, headers: [String: String] = [:]) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = defaultTimeout
        request.cachePolicy = defaultCachePolicy
        
        // Add standard headers
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AI-Sugar-Detection-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("gzip, deflate", forHTTPHeaderField: "Accept-Encoding")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        return request
    }
    
    /// Creates a POST request with JSON body
    func createPostRequest<T: Encodable>(
        url: URL,
        body: T,
        headers: [String: String] = [:]
    ) throws -> URLRequest {
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = defaultTimeout * 1.5 // Longer timeout for POST
        
        // Add standard headers
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("AI-Sugar-Detection-iOS/1.0", forHTTPHeaderField: "User-Agent")
        
        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Encode body
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            request.httpBody = try encoder.encode(body)
        } catch {
            throw NetworkError.invalidInput("Failed to encode request body")
        }
        
        return request
    }
    
    // MARK: - Logging (Debug Only)
    
    #if DEBUG
    private func logRequest(
        _ request: URLRequest,
        response: URLResponse,
        data: Data,
        attempt: Int
    ) {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        
        print("""
        🌐 Network Request (Attempt \(attempt))
        URL: \(request.url?.absoluteString ?? "Unknown")
        Method: \(request.httpMethod ?? "Unknown")
        Status: \(httpResponse.statusCode)
        Response Size: \(data.count) bytes
        """)
    }
    #endif
}

// MARK: - URLSessionDelegate

private class NetworkSessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        
        // Certificate pinning implementation would go here in production
        // For now, use default handling
        completionHandler(.performDefaultHandling, nil)
    }
    
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        // Handle task completion if needed
        if let error = error {
            #if DEBUG
            print("URLSessionTask completed with error: \(error)")
            #endif
        }
    }
}

// MARK: - Convenience Extensions

extension NetworkManager {
    
    /// Quick method to check if a host is reachable
    func isHostReachable(_ host: String) async -> Bool {
        guard let url = URL(string: "https://\(host)") else { return false }
        
        do {
            let request = createGetRequest(url: url)
            let _ = try await session.data(for: request)
            return true
        } catch {
            return false
        }
    }
    
    /// Clears all cached network data
    func clearNetworkCache() {
        session.configuration.urlCache?.removeAllCachedResponses()
    }
    
    /// Returns cache usage statistics
    func getCacheStatistics() -> (memoryUsage: Int, diskUsage: Int) {
        guard let cache = session.configuration.urlCache else {
            return (0, 0)
        }
        return (cache.currentMemoryUsage, cache.currentDiskUsage)
    }
}