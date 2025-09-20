//
//  CacheManager.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation
import CryptoKit

/// Comprehensive caching system for API responses, AI results, and images
@MainActor
final class CacheManager: ObservableObject {
    
    // MARK: - Singleton
    static let shared = CacheManager()
    
    // MARK: - Cache Configuration
    
    private struct CacheConfig {
        static let openFoodFactsTTL: TimeInterval = 24 * 3600 // 24 hours
        static let aiResponseTTL: TimeInterval = 7 * 24 * 3600 // 7 days
        static let imageTTL: TimeInterval = 3 * 24 * 3600 // 3 days
        static let maxMemoryUsage = 50 * 1024 * 1024 // 50MB
        static let maxDiskUsage = 200 * 1024 * 1024 // 200MB
    }
    
    // MARK: - Properties
    
    private let memoryCache = NSCache<NSString, CacheItem>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let diskQueue = DispatchQueue(label: "CacheManager.disk", qos: .utility)
    
    @Published private(set) var memoryUsage: Int = 0
    @Published private(set) var diskUsage: Int = 0
    
    // Cache directories
    private let openFoodFactsDirectory: URL
    private let aiResponseDirectory: URL
    private let imageDirectory: URL
    
    // MARK: - Initialization
    
    private init() {
        // Setup cache directories
        let cacheRoot = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cacheRoot.appendingPathComponent("AIFoodScanner")
        
        self.openFoodFactsDirectory = cacheDirectory.appendingPathComponent("OpenFoodFacts")
        self.aiResponseDirectory = cacheDirectory.appendingPathComponent("AIResponses")
        self.imageDirectory = cacheDirectory.appendingPathComponent("Images")
        
        setupCacheDirectories()
        configureMemoryCache()
        
        // Start background maintenance
        Task {
            await performMaintenanceTasks()
        }
    }
    
    // MARK: - Setup Methods
    
    private func setupCacheDirectories() {
        let directories = [cacheDirectory, openFoodFactsDirectory, aiResponseDirectory, imageDirectory]
        
        for directory in directories {
            do {
                try fileManager.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true,
                    attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                )
            } catch {
                print("Failed to create cache directory: \(directory.path) - \(error)")
            }
        }
    }
    
    private func configureMemoryCache() {
        memoryCache.countLimit = 100
        memoryCache.totalCostLimit = CacheConfig.maxMemoryUsage
        memoryCache.delegate = self
    }
    
    // MARK: - Generic Cache Methods
    
    /// Stores a codable item in cache with specified TTL
    func store<T: Codable>(
        _ item: T,
        forKey key: String,
        category: CacheCategory,
        ttl: TimeInterval? = nil
    ) async throws {
        
        let cacheItem = CacheItem(
            data: try encodeItem(item),
            expiresAt: Date().addingTimeInterval(ttl ?? category.defaultTTL),
            category: category
        )
        
        // Store in memory cache
        memoryCache.setObject(cacheItem, forKey: NSString(string: key))
        
        // Store on disk asynchronously
        await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    try self.storeToDisk(cacheItem, key: key, category: category)
                    continuation.resume()
                } catch {
                    print("Failed to store to disk: \(error)")
                    continuation.resume()
                }
            }
        }
        
        await updateUsageStats()
    }
    
    /// Retrieves a codable item from cache
    func retrieve<T: Codable>(
        _ type: T.Type,
        forKey key: String,
        category: CacheCategory
    ) async -> T? {
        
        // First check memory cache
        if let cacheItem = memoryCache.object(forKey: NSString(string: key)) {
            if !cacheItem.isExpired {
                do {
                    return try decodeItem(type, from: cacheItem.data)
                } catch {
                    // Remove corrupted item from memory
                    memoryCache.removeObject(forKey: NSString(string: key))
                }
            } else {
                // Remove expired item from memory
                memoryCache.removeObject(forKey: NSString(string: key))
            }
        }
        
        // Check disk cache
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    if let cacheItem = try self.retrieveFromDisk(key: key, category: category) {
                        if !cacheItem.isExpired {
                            // Store back in memory for faster future access
                            self.memoryCache.setObject(cacheItem, forKey: NSString(string: key))
                            
                            let decoded = try? self.decodeItem(type, from: cacheItem.data)
                            continuation.resume(returning: decoded)
                        } else {
                            // Remove expired item from disk
                            try? self.removeFromDisk(key: key, category: category)
                            continuation.resume(returning: nil)
                        }
                    } else {
                        continuation.resume(returning: nil)
                    }
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    /// Removes an item from cache
    func remove(key: String, category: CacheCategory) async {
        // Remove from memory
        memoryCache.removeObject(forKey: NSString(string: key))
        
        // Remove from disk
        await withCheckedContinuation { continuation in
            diskQueue.async {
                try? self.removeFromDisk(key: key, category: category)
                continuation.resume()
            }
        }
        
        await updateUsageStats()
    }
    
    /// Checks if an item exists in cache and is not expired
    func exists(key: String, category: CacheCategory) async -> Bool {
        // Check memory first
        if let cacheItem = memoryCache.object(forKey: NSString(string: key)) {
            return !cacheItem.isExpired
        }
        
        // Check disk
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    if let cacheItem = try self.retrieveFromDisk(key: key, category: category) {
                        continuation.resume(returning: !cacheItem.isExpired)
                    } else {
                        continuation.resume(returning: false)
                    }
                } catch {
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Specialized Cache Methods
    
    /// Caches an Open Food Facts product response
    func cacheProduct(_ product: FoodProduct, forBarcode barcode: String) async {
        do {
            try await store(product, forKey: barcode, category: .openFoodFacts)
        } catch {
            print("Failed to cache product: \(error)")
        }
    }
    
    /// Retrieves a cached Open Food Facts product
    func getCachedProduct(forBarcode barcode: String) async -> FoodProduct? {
        return await retrieve(FoodProduct.self, forKey: barcode, category: .openFoodFacts)
    }
    
    /// Caches an AI response
    func cacheAIResponse(_ response: AIResponse, forIngredients ingredients: String) async {
        let key = generateIngredientsKey(ingredients)
        do {
            try await store(response, forKey: key, category: .aiResponse)
        } catch {
            print("Failed to cache AI response: \(error)")
        }
    }
    
    /// Retrieves a cached AI response
    func getCachedAIResponse(forIngredients ingredients: String) async -> AIResponse? {
        let key = generateIngredientsKey(ingredients)
        return await retrieve(AIResponse.self, forKey: key, category: .aiResponse)
    }
    
    /// Caches image data
    func cacheImage(_ imageData: Data, forURL url: URL) async {
        let key = generateImageKey(from: url)
        do {
            try await store(imageData, forKey: key, category: .image)
        } catch {
            print("Failed to cache image: \(error)")
        }
    }
    
    /// Retrieves cached image data
    func getCachedImage(forURL url: URL) async -> Data? {
        let key = generateImageKey(from: url)
        return await retrieve(Data.self, forKey: key, category: .image)
    }
    
    // MARK: - Cache Management
    
    /// Clears all cache data
    func clearAll() async {
        memoryCache.removeAllObjects()
        
        await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    try self.fileManager.removeItem(at: self.cacheDirectory)
                    self.setupCacheDirectories()
                } catch {
                    print("Failed to clear cache: \(error)")
                }
                continuation.resume()
            }
        }
        
        await updateUsageStats()
    }
    
    /// Clears cache for a specific category
    func clear(category: CacheCategory) async {
        // Clear from memory cache
        memoryCache.removeAllObjects() // NSCache doesn't support category-based removal
        
        await withCheckedContinuation { continuation in
            diskQueue.async {
                do {
                    let directory = self.directoryForCategory(category)
                    try self.fileManager.removeItem(at: directory)
                    try self.fileManager.createDirectory(
                        at: directory,
                        withIntermediateDirectories: true,
                        attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]
                    )
                } catch {
                    print("Failed to clear category cache: \(error)")
                }
                continuation.resume()
            }
        }
        
        await updateUsageStats()
    }
    
    /// Clears expired items from cache
    func clearExpired() async {
        await withCheckedContinuation { continuation in
            diskQueue.async {
                self.clearExpiredItems()
                continuation.resume()
            }
        }
        
        await updateUsageStats()
    }
    
    // MARK: - Statistics and Monitoring
    
    /// Returns cache statistics
    func getCacheStatistics() async -> CacheStatistics {
        await updateUsageStats()
        
        return CacheStatistics(
            memoryUsage: memoryUsage,
            diskUsage: diskUsage,
            itemCount: await getItemCount(),
            hitRate: 0.0 // Would need to track hits/misses for accurate calculation
        )
    }
    
    private func updateUsageStats() async {
        let stats = await withCheckedContinuation { continuation in
            diskQueue.async {
                let diskUsage = self.calculateDiskUsage()
                continuation.resume(returning: diskUsage)
            }
        }
        
        self.memoryUsage = Int(memoryCache.totalCostLimit)
        self.diskUsage = stats
    }
    
    private func getItemCount() async -> Int {
        return await withCheckedContinuation { continuation in
            diskQueue.async {
                let count = self.calculateItemCount()
                continuation.resume(returning: count)
            }
        }
    }
    
    // MARK: - Private Disk Operations
    
    private func storeToDisk(_ item: CacheItem, key: String, category: CacheCategory) throws {
        let directory = directoryForCategory(category)
        let filename = sanitizeFilename(key)
        let fileURL = directory.appendingPathComponent(filename)
        
        let data = try JSONEncoder().encode(item)
        try data.write(to: fileURL, options: .atomic)
    }
    
    private func retrieveFromDisk(key: String, category: CacheCategory) throws -> CacheItem? {
        let directory = directoryForCategory(category)
        let filename = sanitizeFilename(key)
        let fileURL = directory.appendingPathComponent(filename)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode(CacheItem.self, from: data)
    }
    
    private func removeFromDisk(key: String, category: CacheCategory) throws {
        let directory = directoryForCategory(category)
        let filename = sanitizeFilename(key)
        let fileURL = directory.appendingPathComponent(filename)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    // MARK: - Helper Methods
    
    private func directoryForCategory(_ category: CacheCategory) -> URL {
        switch category {
        case .openFoodFacts:
            return openFoodFactsDirectory
        case .aiResponse:
            return aiResponseDirectory
        case .image:
            return imageDirectory
        }
    }
    
    private func encodeItem<T: Codable>(_ item: T) throws -> Data {
        return try JSONEncoder().encode(item)
    }
    
    private func decodeItem<T: Codable>(_ type: T.Type, from data: Data) throws -> T {
        return try JSONDecoder().decode(type, from: data)
    }
    
    private func generateIngredientsKey(_ ingredients: String) -> String {
        let normalized = ingredients.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .joined(separator: " ")
        
        let hash = SHA256.hash(data: Data(normalized.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func generateImageKey(from url: URL) -> String {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8))
        return hash.map { String(format: "%02x", $0) }.joined()
    }
    
    private func sanitizeFilename(_ filename: String) -> String {
        return filename.replacingOccurrences(of: "/", with: "_")
                       .replacingOccurrences(of: "\\", with: "_")
                       .replacingOccurrences(of: ":", with: "_")
    }
    
    private func clearExpiredItems() {
        let categories: [CacheCategory] = [.openFoodFacts, .aiResponse, .image]
        
        for category in categories {
            let directory = directoryForCategory(category)
            
            guard let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
                continue
            }
            
            for itemURL in items {
                do {
                    let data = try Data(contentsOf: itemURL)
                    let cacheItem = try JSONDecoder().decode(CacheItem.self, from: data)
                    
                    if cacheItem.isExpired {
                        try fileManager.removeItem(at: itemURL)
                    }
                } catch {
                    // Remove corrupted files
                    try? fileManager.removeItem(at: itemURL)
                }
            }
        }
    }
    
    private func calculateDiskUsage() -> Int {
        var totalSize = 0
        
        let categories: [CacheCategory] = [.openFoodFacts, .aiResponse, .image]
        
        for category in categories {
            let directory = directoryForCategory(category)
            
            guard let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
                continue
            }
            
            for itemURL in items {
                if let resourceValues = try? itemURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    totalSize += fileSize
                }
            }
        }
        
        return totalSize
    }
    
    private func calculateItemCount() -> Int {
        var totalCount = 0
        
        let categories: [CacheCategory] = [.openFoodFacts, .aiResponse, .image]
        
        for category in categories {
            let directory = directoryForCategory(category)
            
            if let items = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                totalCount += items.count
            }
        }
        
        return totalCount
    }
    
    // MARK: - Background Maintenance
    
    private func performMaintenanceTasks() async {
        // Run maintenance every 6 hours
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 6 * 3600 * 1_000_000_000)
            
            await clearExpired()
            
            // Check if we need to free up space
            if diskUsage > CacheConfig.maxDiskUsage {
                await performCleanup()
            }
        }
    }
    
    private func performCleanup() async {
        // Remove oldest files first
        await withCheckedContinuation { continuation in
            diskQueue.async {
                // Implementation for LRU cleanup would go here
                continuation.resume()
            }
        }
    }
}

// MARK: - NSCacheDelegate

extension CacheManager: NSCacheDelegate {
    nonisolated func cache(_ cache: NSCache<AnyObject, AnyObject>, willEvictObject obj: Any) {
        // Could track evictions for statistics
    }
}

// MARK: - Supporting Types

enum CacheCategory: String, CaseIterable {
    case openFoodFacts = "openFoodFacts"
    case aiResponse = "aiResponse"
    case image = "image"
    
    var defaultTTL: TimeInterval {
        switch self {
        case .openFoodFacts:
            return CacheManager.CacheConfig.openFoodFactsTTL
        case .aiResponse:
            return CacheManager.CacheConfig.aiResponseTTL
        case .image:
            return CacheManager.CacheConfig.imageTTL
        }
    }
}

private struct CacheItem: Codable {
    let data: Data
    let expiresAt: Date
    let category: CacheCategory
    
    var isExpired: Bool {
        return Date() > expiresAt
    }
}

struct CacheStatistics {
    let memoryUsage: Int
    let diskUsage: Int
    let itemCount: Int
    let hitRate: Double
    
    var memoryUsageString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(memoryUsage), countStyle: .memory)
    }
    
    var diskUsageString: String {
        return ByteCountFormatter.string(fromByteCount: Int64(diskUsage), countStyle: .file)
    }
}