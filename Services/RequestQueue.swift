//
//  RequestQueue.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Advanced request queue system with rate limiting, prioritization, and retry logic
@MainActor
final class RequestQueue: ObservableObject {
    
    // MARK: - Singleton
    static let shared = RequestQueue()
    
    // MARK: - Configuration
    
    private struct QueueConfig {
        static let maxConcurrentRequests = 3
        static let defaultRetryCount = 3
        static let rateLimitWindow: TimeInterval = 60 // 1 minute
        static let maxRequestsPerWindow = 100
        static let highPriorityLimit = 5
    }
    
    // MARK: - Properties
    
    private let processingQueue = DispatchQueue(label: "RequestQueue.processing", qos: .userInitiated)
    private let rateLimitQueue = DispatchQueue(label: "RequestQueue.rateLimit", qos: .utility)
    
    @Published private(set) var pendingRequestsCount = 0
    @Published private(set) var isRateLimited = false
    @Published private(set) var currentConcurrentRequests = 0
    
    // Request tracking
    private var pendingRequests: [QueuedRequest] = []
    private var activeRequests: [String: QueuedRequest] = [:]
    private var requestHistory: [RequestHistoryEntry] = []
    
    // Rate limiting
    private var requestCounts: [String: [Date]] = [:] // Service -> Request timestamps
    private var rateLimitResetTimes: [String: Date] = [:]
    
    // Semaphore for concurrent request limiting
    private let concurrentRequestsSemaphore = DispatchSemaphore(value: QueueConfig.maxConcurrentRequests)
    
    // MARK: - Initialization
    
    private init() {
        startRateLimitMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Enqueues a request with specified priority and retry configuration
    func enqueue<T>(
        request: QueuedRequest.RequestExecutor<T>,
        priority: RequestPriority = .normal,
        serviceType: ServiceType,
        retryCount: Int = QueueConfig.defaultRetryCount,
        retryDelay: TimeInterval = 1.0,
        metadata: [String: Any] = [:]
    ) async throws -> T {
        
        let queuedRequest = QueuedRequest(
            id: UUID().uuidString,
            priority: priority,
            serviceType: serviceType,
            retryCount: retryCount,
            retryDelay: retryDelay,
            metadata: metadata,
            createdAt: Date()
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            queuedRequest.completion = { result in
                continuation.resume(with: result)
            }
            
            Task { @MainActor in
                addRequest(queuedRequest, executor: request)
                processQueueIfNeeded()
            }
        }
    }
    
    /// Cancels a specific request by ID
    func cancelRequest(id: String) {
        Task { @MainActor in
            // Remove from pending queue
            pendingRequests.removeAll { $0.id == id }
            
            // Cancel active request
            if let request = activeRequests.removeValue(forKey: id) {
                request.isCancelled = true
                currentConcurrentRequests = max(0, currentConcurrentRequests - 1)
            }
            
            updatePublishedProperties()
        }
    }
    
    /// Cancels all requests for a specific service
    func cancelRequestsForService(_ serviceType: ServiceType) {
        Task { @MainActor in
            // Cancel pending requests
            let cancelledCount = pendingRequests.count
            pendingRequests.removeAll { $0.serviceType == serviceType }
            
            // Cancel active requests
            let activeToCancel = activeRequests.values.filter { $0.serviceType == serviceType }
            for request in activeToCancel {
                request.isCancelled = true
                activeRequests.removeValue(forKey: request.id)
                currentConcurrentRequests = max(0, currentConcurrentRequests - 1)
            }
            
            updatePublishedProperties()
        }
    }
    
    /// Returns queue statistics
    func getQueueStatistics() -> QueueStatistics {
        let stats = QueueStatistics(
            pendingRequests: pendingRequestsCount,
            activeRequests: currentConcurrentRequests,
            totalRequests: requestHistory.count,
            averageResponseTime: calculateAverageResponseTime(),
            successRate: calculateSuccessRate(),
            rateLimitStatus: getRateLimitStatus()
        )
        return stats
    }
    
    // MARK: - Private Queue Management
    
    private func addRequest<T>(_ request: QueuedRequest, executor: @escaping QueuedRequest.RequestExecutor<T>) {
        request.executor = { [weak self] in
            guard let self = self else {
                throw NetworkError.requestFailed(NSError(domain: "RequestQueue", code: -1))
            }
            
            // Check if request was cancelled
            if request.isCancelled {
                throw NetworkError.requestFailed(NSError(domain: "RequestQueue", code: NSURLErrorCancelled))
            }
            
            return try await executor()
        }
        
        // Insert request based on priority
        let insertIndex = findInsertionIndex(for: request)
        pendingRequests.insert(request, at: insertIndex)
        
        updatePublishedProperties()
    }
    
    private func findInsertionIndex(for request: QueuedRequest) -> Int {
        // Find the insertion point to maintain priority order
        for (index, existingRequest) in pendingRequests.enumerated() {
            if request.priority.rawValue > existingRequest.priority.rawValue {
                return index
            }
        }
        return pendingRequests.count
    }
    
    private func processQueueIfNeeded() {
        processingQueue.async { [weak self] in
            self?.processQueue()
        }
    }
    
    private func processQueue() {
        while !pendingRequests.isEmpty && currentConcurrentRequests < QueueConfig.maxConcurrentRequests {
            
            guard let nextRequest = getNextEligibleRequest() else {
                break // No eligible requests (may be rate limited)
            }
            
            // Move request from pending to active
            Task { @MainActor in
                self.pendingRequests.removeAll { $0.id == nextRequest.id }
                self.activeRequests[nextRequest.id] = nextRequest
                self.currentConcurrentRequests += 1
                self.updatePublishedProperties()
            }
            
            // Process the request
            Task {
                await processRequest(nextRequest)
            }
        }
    }
    
    private func getNextEligibleRequest() -> QueuedRequest? {
        // Sort by priority and creation time
        let sortedRequests = pendingRequests.sorted { req1, req2 in
            if req1.priority.rawValue != req2.priority.rawValue {
                return req1.priority.rawValue > req2.priority.rawValue
            }
            return req1.createdAt < req2.createdAt
        }
        
        // Find first request that's not rate limited
        for request in sortedRequests {
            if !isRateLimited(for: request.serviceType) {
                return request
            }
        }
        
        return nil
    }
    
    private func processRequest(_ request: QueuedRequest) async {
        var attemptCount = 0
        let maxAttempts = request.retryCount + 1
        
        while attemptCount < maxAttempts {
            attemptCount += 1
            
            // Check if request was cancelled
            if request.isCancelled {
                await completeRequest(request, result: .failure(NetworkError.requestFailed(NSError(domain: "RequestQueue", code: NSURLErrorCancelled))))
                return
            }
            
            // Wait for rate limit if necessary
            if isRateLimited(for: request.serviceType) {
                await waitForRateLimit(request.serviceType)
            }
            
            // Acquire semaphore to limit concurrent requests
            concurrentRequestsSemaphore.wait()
            
            // Record request attempt
            await recordRequestAttempt(for: request.serviceType)
            
            let startTime = Date()
            
            do {
                // Execute the request
                guard let executor = request.executor else {
                    throw NetworkError.requestFailed(NSError(domain: "RequestQueue", code: -1))
                }
                
                let result = try await executor()
                
                // Record success
                await recordRequestCompletion(request: request, success: true, responseTime: Date().timeIntervalSince(startTime))
                
                // Complete successfully
                await completeRequest(request, result: .success(result))
                concurrentRequestsSemaphore.signal()
                return
                
            } catch let error as NetworkError {
                concurrentRequestsSemaphore.signal()
                
                // Handle rate limiting
                if case .rateLimitExceeded(let retryAfter) = error {
                    await handleRateLimit(for: request.serviceType, retryAfter: retryAfter)
                }
                
                // Determine if we should retry
                if attemptCount < maxAttempts && error.isRetryable && !request.isCancelled {
                    await recordRequestCompletion(request: request, success: false, responseTime: Date().timeIntervalSince(startTime))
                    
                    // Wait before retry with exponential backoff
                    let delay = request.retryDelay * pow(2.0, Double(attemptCount - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                } else {
                    // Final failure
                    await recordRequestCompletion(request: request, success: false, responseTime: Date().timeIntervalSince(startTime))
                    await completeRequest(request, result: .failure(error))
                    return
                }
                
            } catch {
                concurrentRequestsSemaphore.signal()
                
                // Final failure for non-NetworkError
                await recordRequestCompletion(request: request, success: false, responseTime: Date().timeIntervalSince(startTime))
                await completeRequest(request, result: .failure(NetworkError.requestFailed(error)))
                return
            }
        }
    }
    
    private func completeRequest(_ request: QueuedRequest, result: Result<Any, Error>) async {
        await MainActor.run {
            // Remove from active requests
            activeRequests.removeValue(forKey: request.id)
            currentConcurrentRequests = max(0, currentConcurrentRequests - 1)
            updatePublishedProperties()
        }
        
        // Call completion handler
        request.completion?(result)
        
        // Continue processing queue
        processQueueIfNeeded()
    }
    
    // MARK: - Rate Limiting
    
    private func isRateLimited(for serviceType: ServiceType) -> Bool {
        let now = Date()
        let windowStart = now.addingTimeInterval(-QueueConfig.rateLimitWindow)
        
        // Clean old entries and count recent requests
        rateLimitQueue.sync {
            let serviceKey = serviceType.rawValue
            
            // Remove old entries
            requestCounts[serviceKey] = requestCounts[serviceKey]?.filter { $0 > windowStart } ?? []
            
            // Check if rate limited
            let recentRequestCount = requestCounts[serviceKey]?.count ?? 0
            let isLimited = recentRequestCount >= serviceType.rateLimit
            
            // Check if rate limit reset time has passed
            if let resetTime = rateLimitResetTimes[serviceKey], now > resetTime {
                rateLimitResetTimes.removeValue(forKey: serviceKey)
                return false
            }
            
            return isLimited
        }
    }
    
    private func recordRequestAttempt(for serviceType: ServiceType) async {
        await withCheckedContinuation { continuation in
            rateLimitQueue.async {
                let serviceKey = serviceType.rawValue
                var requests = self.requestCounts[serviceKey] ?? []
                requests.append(Date())
                self.requestCounts[serviceKey] = requests
                continuation.resume()
            }
        }
    }
    
    private func handleRateLimit(for serviceType: ServiceType, retryAfter: TimeInterval?) async {
        await withCheckedContinuation { continuation in
            rateLimitQueue.async {
                let serviceKey = serviceType.rawValue
                let resetTime = Date().addingTimeInterval(retryAfter ?? 60)
                self.rateLimitResetTimes[serviceKey] = resetTime
                
                Task { @MainActor in
                    self.isRateLimited = true
                }
                
                continuation.resume()
            }
        }
    }
    
    private func waitForRateLimit(_ serviceType: ServiceType) async {
        let serviceKey = serviceType.rawValue
        
        if let resetTime = rateLimitResetTimes[serviceKey] {
            let waitTime = resetTime.timeIntervalSinceNow
            if waitTime > 0 {
                try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            }
        }
    }
    
    private func startRateLimitMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateRateLimitStatus()
            }
        }
    }
    
    private func updateRateLimitStatus() {
        let now = Date()
        var anyServiceLimited = false
        
        for serviceType in ServiceType.allCases {
            if isRateLimited(for: serviceType) {
                anyServiceLimited = true
                break
            }
        }
        
        isRateLimited = anyServiceLimited
    }
    
    // MARK: - Statistics and Monitoring
    
    private func recordRequestCompletion(request: QueuedRequest, success: Bool, responseTime: TimeInterval) async {
        await MainActor.run {
            let historyEntry = RequestHistoryEntry(
                id: request.id,
                serviceType: request.serviceType,
                priority: request.priority,
                success: success,
                responseTime: responseTime,
                attemptCount: request.retryCount + 1,
                completedAt: Date()
            )
            
            requestHistory.append(historyEntry)
            
            // Keep only recent history (last 1000 requests)
            if requestHistory.count > 1000 {
                requestHistory.removeFirst(requestHistory.count - 1000)
            }
        }
    }
    
    private func calculateAverageResponseTime() -> TimeInterval {
        guard !requestHistory.isEmpty else { return 0 }
        
        let totalTime = requestHistory.reduce(0) { $0 + $1.responseTime }
        return totalTime / Double(requestHistory.count)
    }
    
    private func calculateSuccessRate() -> Double {
        guard !requestHistory.isEmpty else { return 0 }
        
        let successCount = requestHistory.filter { $0.success }.count
        return Double(successCount) / Double(requestHistory.count)
    }
    
    private func getRateLimitStatus() -> [String: Any] {
        var status: [String: Any] = [:]
        
        for serviceType in ServiceType.allCases {
            let serviceKey = serviceType.rawValue
            let recentRequests = requestCounts[serviceKey]?.count ?? 0
            let isLimited = isRateLimited(for: serviceType)
            let resetTime = rateLimitResetTimes[serviceKey]
            
            status[serviceKey] = [
                "recent_requests": recentRequests,
                "rate_limit": serviceType.rateLimit,
                "is_limited": isLimited,
                "reset_time": resetTime?.timeIntervalSince1970
            ]
        }
        
        return status
    }
    
    private func updatePublishedProperties() {
        pendingRequestsCount = pendingRequests.count
    }
}

// MARK: - Supporting Types

enum RequestPriority: Int, CaseIterable {
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
}

enum ServiceType: String, CaseIterable {
    case openFoodFacts = "openFoodFacts"
    case aiService = "aiService"
    case imageDownload = "imageDownload"
    
    var rateLimit: Int {
        switch self {
        case .openFoodFacts:
            return 100 // 100 requests per minute
        case .aiService:
            return 20   // 20 requests per minute
        case .imageDownload:
            return 50   // 50 requests per minute
        }
    }
}

private class QueuedRequest {
    typealias RequestExecutor<T> = () async throws -> T
    
    let id: String
    let priority: RequestPriority
    let serviceType: ServiceType
    let retryCount: Int
    let retryDelay: TimeInterval
    let metadata: [String: Any]
    let createdAt: Date
    
    var executor: (() async throws -> Any)?
    var completion: ((Result<Any, Error>) -> Void)?
    var isCancelled = false
    
    init(id: String, priority: RequestPriority, serviceType: ServiceType, retryCount: Int, retryDelay: TimeInterval, metadata: [String: Any], createdAt: Date) {
        self.id = id
        self.priority = priority
        self.serviceType = serviceType
        self.retryCount = retryCount
        self.retryDelay = retryDelay
        self.metadata = metadata
        self.createdAt = createdAt
    }
}

private struct RequestHistoryEntry {
    let id: String
    let serviceType: ServiceType
    let priority: RequestPriority
    let success: Bool
    let responseTime: TimeInterval
    let attemptCount: Int
    let completedAt: Date
}

struct QueueStatistics {
    let pendingRequests: Int
    let activeRequests: Int
    let totalRequests: Int
    let averageResponseTime: TimeInterval
    let successRate: Double
    let rateLimitStatus: [String: Any]
    
    var averageResponseTimeString: String {
        return String(format: "%.2fs", averageResponseTime)
    }
    
    var successRateString: String {
        return String(format: "%.1f%%", successRate * 100)
    }
}