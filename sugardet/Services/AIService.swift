//
//  AIService.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation
import CryptoKit

/// AI service integration for ingredient analysis and sugar detection
@MainActor
final class AIService: ObservableObject {
    
    // MARK: - AI Provider Configuration
    enum AIProvider: String, CaseIterable {
        case openAI = "openai"
        case anthropic = "anthropic"
        case custom = "custom"
        
        var baseURL: String {
            switch self {
            case .openAI:
                return "https://api.openai.com/v1"
            case .anthropic:
                return "https://api.anthropic.com/v1"
            case .custom:
                return UserDefaults.standard.string(forKey: "custom_ai_base_url") ?? ""
            }
        }
        
        var defaultModel: String {
            switch self {
            case .openAI:
                return "gpt-4"
            case .anthropic:
                return "claude-3-sonnet-20240229"
            case .custom:
                return "custom-model"
            }
        }
    }
    
    enum AnalysisLevel: String, CaseIterable {
        case basic = "basic"
        case detailed = "detailed"
        case comprehensive = "comprehensive"
    }
    
    // MARK: - Properties
    private let networkManager: NetworkManager
    private let cacheManager: CacheManager
    private let requestQueue: RequestQueue
    
    @Published private(set) var isAnalyzing = false
    @Published private(set) var currentProvider: AIProvider
    @Published private(set) var analysisCount = 0
    @Published private(set) var lastAnalysisTime: Date?
    
    // Configuration
    private var apiKey: String? {
        KeychainManager.shared.getAPIKey(for: currentProvider.rawValue)
    }
    
    private let defaultTimeout: TimeInterval = 45.0
    private let maxRetries = 2
    private let retryDelays: [TimeInterval] = [5.0, 10.0]
    
    // MARK: - Initialization
    init(
        provider: AIProvider = .openAI,
        networkManager: NetworkManager = .shared,
        cacheManager: CacheManager = .shared,
        requestQueue: RequestQueue = .shared
    ) {
        self.currentProvider = provider
        self.networkManager = networkManager
        self.cacheManager = cacheManager
        self.requestQueue = requestQueue
    }
    
    // MARK: - Public Methods
    
    /// Analyze ingredients for sugar content using AI
    func analyzeIngredients(
        _ ingredientsText: String,
        language: String = "en",
        analysisLevel: AnalysisLevel = .detailed
    ) async throws -> AIResponse {
        
        guard !ingredientsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NetworkError.invalidRequest("Ingredients text cannot be empty")
        }
        
        guard let apiKey = apiKey else {
            throw NetworkError.authenticationFailed
        }
        
        // Check cache first
        let cacheKey = generateCacheKey(ingredients: ingredientsText, language: language, level: analysisLevel)
        if let cachedResponse = await cacheManager.getCachedAIResponse(forKey: cacheKey) {
            return cachedResponse
        }
        
        // Set analyzing state
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        // Create analysis request
        let analysisRequest = AIAnalysisRequest(
            ingredients: ingredientsText,
            language: language,
            analysisType: "sugar_detection",
            detailLevel: analysisLevel.rawValue,
            requestId: UUID().uuidString
        )
        
        do {
            let response = try await performAnalysisWithRetry(request: analysisRequest, apiKey: apiKey)
            
            // Cache successful response
            await cacheManager.cacheAIResponse(response, forKey: cacheKey)
            
            // Update analytics
            analysisCount += 1
            lastAnalysisTime = Date()
            
            return response
            
        } catch {
            throw handleAnalysisError(error)
        }
    }
    
    /// Batch analyze multiple ingredient lists
    func batchAnalyzeIngredients(
        _ ingredientsList: [String],
        language: String = "en",
        analysisLevel: AnalysisLevel = .basic
    ) async throws -> [AIResponse] {
        
        guard !ingredientsList.isEmpty else {
            throw NetworkError.invalidRequest("Ingredients list cannot be empty")
        }
        
        // Process in batches to avoid overwhelming the API
        let batchSize = 5
        var results: [AIResponse] = []
        
        for batch in ingredientsList.chunked(into: batchSize) {
            let batchTasks = batch.map { ingredients in
                Task {
                    try await analyzeIngredients(ingredients, language: language, analysisLevel: analysisLevel)
                }
            }
            
            let batchResults = try await withThrowingTaskGroup(of: AIResponse.self) { group in
                for task in batchTasks {
                    group.addTask { try await task.value }
                }
                
                var responses: [AIResponse] = []
                for try await response in group {
                    responses.append(response)
                }
                return responses
            }
            
            results.append(contentsOf: batchResults)
            
            // Add delay between batches to respect rate limits
            if results.count < ingredientsList.count {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
        }
        
        return results
    }
    
    /// Switch AI provider
    func switchProvider(_ provider: AIProvider) {
        currentProvider = provider
        // Clear any cached configurations
        UserDefaults.standard.removeObject(forKey: "ai_service_config")
    }
    
    /// Validate API key for current provider
    func validateAPIKey() async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            _ = try await performTestRequest(apiKey: apiKey)
            return true
        } catch {
            return false
        }
    }
    
    /// Get estimated cost for analysis
    func getEstimatedCost(for ingredientsText: String) -> Double {
        let characterCount = ingredientsText.count
        let estimatedTokens = Double(characterCount) / 4.0 // Rough token estimation
        
        switch currentProvider {
        case .openAI:
            return estimatedTokens * 0.00003 // GPT-4 pricing
        case .anthropic:
            return estimatedTokens * 0.00001 // Claude pricing
        case .custom:
            return 0.001 // Default estimate
        }
    }
}

// MARK: - Private Methods
private extension AIService {
    
    /// Perform analysis with retry logic
    func performAnalysisWithRetry(request: AIAnalysisRequest, apiKey: String) async throws -> AIResponse {
        var lastError: Error?
        
        for attempt in 0...maxRetries {
            do {
                return try await performAnalysis(request: request, apiKey: apiKey)
            } catch let error as NetworkError {
                lastError = error
                
                // Don't retry on authentication or client errors
                if case .authenticationFailed = error,
                   case .invalidRequest = error {
                    throw error
                }
                
                // Apply retry delay if not the last attempt
                if attempt < maxRetries {
                    let delay = retryDelays[min(attempt, retryDelays.count - 1)]
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            } catch {
                lastError = error
                if attempt < maxRetries {
                    let delay = retryDelays[min(attempt, retryDelays.count - 1)]
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? NetworkError.unknown("Analysis failed after retries")
    }
    
    /// Perform the actual AI analysis request
    func performAnalysis(request: AIAnalysisRequest, apiKey: String) async throws -> AIResponse {
        let startTime = Date()
        
        // Build request based on provider
        let urlRequest = try buildAnalysisRequest(request: request, apiKey: apiKey)
        
        // Execute request through request queue
        let (data, response) = try await requestQueue.execute(urlRequest)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse("Invalid HTTP response")
        }
        
        guard 200...299 ~= httpResponse.statusCode else {
            throw NetworkError.serverError(httpResponse.statusCode, String(data: data, encoding: .utf8) ?? "Unknown error")
        }
        
        // Parse response based on provider
        let aiResponse = try parseAnalysisResponse(data: data, requestId: request.requestId, startTime: startTime)
        
        return aiResponse
    }
    
    /// Build analysis request for the current provider
    func buildAnalysisRequest(request: AIAnalysisRequest, apiKey: String) throws -> URLRequest {
        let endpoint = currentProvider.baseURL + getAnalysisEndpoint()
        
        guard let url = URL(string: endpoint) else {
            throw NetworkError.invalidRequest("Invalid API endpoint URL")
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = defaultTimeout
        
        // Set headers
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        switch currentProvider {
        case .openAI:
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.httpBody = try buildOpenAIRequest(request)
        case .anthropic:
            urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            urlRequest.httpBody = try buildAnthropicRequest(request)
        case .custom:
            urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            urlRequest.httpBody = try buildGenericRequest(request)
        }
        
        return urlRequest
    }
    
    /// Get analysis endpoint for current provider
    func getAnalysisEndpoint() -> String {
        switch currentProvider {
        case .openAI:
            return "/chat/completions"
        case .anthropic:
            return "/messages"
        case .custom:
            return "/analyze-ingredients"
        }
    }
    
    /// Build OpenAI request body
    func buildOpenAIRequest(_ request: AIAnalysisRequest) throws -> Data {
        let prompt = buildAnalysisPrompt(ingredients: request.ingredients, language: request.language, level: request.detailLevel)
        
        let requestBody: [String: Any] = [
            "model": currentProvider.defaultModel,
            "messages": [
                [
                    "role": "system",
                    "content": "You are a food ingredient analyzer specializing in sugar detection. Provide accurate, structured analysis in JSON format."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.1,
            "max_tokens": 1000
        ]
        
        return try JSONSerialization.data(withJSONObject: requestBody)
    }
    
    /// Build Anthropic request body
    func buildAnthropicRequest(_ request: AIAnalysisRequest) throws -> Data {
        let prompt = buildAnalysisPrompt(ingredients: request.ingredients, language: request.language, level: request.detailLevel)
        
        let requestBody: [String: Any] = [
            "model": currentProvider.defaultModel,
            "max_tokens": 1000,
            "system": "You are a food ingredient analyzer specializing in sugar detection. Provide accurate, structured analysis in JSON format.",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ]
        ]
        
        return try JSONSerialization.data(withJSONObject: requestBody)
    }
    
    /// Build generic request body for custom providers
    func buildGenericRequest(_ request: AIAnalysisRequest) throws -> Data {
        return try JSONEncoder().encode(request)
    }
    
    /// Build analysis prompt
    func buildAnalysisPrompt(ingredients: String, language: String, level: String) -> String {
        return """
        Analyze the following food ingredients for sugar content and provide a JSON response:
        
        Ingredients: "\(ingredients)"
        Language: \(language)
        Analysis Level: \(level)
        
        Please provide a JSON response with the following structure:
        {
          "analysis_id": "unique_id",
          "contains_sugar": boolean,
          "confidence": number_between_0_and_1,
          "sugar_types": [
            {
              "type": "sugar_type_name",
              "confidence": number_between_0_and_1,
              "sources": ["ingredient_names"]
            }
          ],
          "sugar_analysis": {
            "total_sugar_indicators": number,
            "hidden_sugars": ["ingredient_names"],
            "sugar_alternatives": ["ingredient_names"],
            "health_impact": "low|medium|high",
            "recommendations": ["recommendation_strings"]
          },
          "processing_time_ms": number,
          "warnings": ["warning_strings"]
        }
        
        Focus on identifying both obvious and hidden sugars, including natural sugars, processed sugars, and artificial sweeteners.
        """
    }
    
    /// Parse analysis response based on provider
    func parseAnalysisResponse(data: Data, requestId: String, startTime: Date) throws -> AIResponse {
        let processingTime = Date().timeIntervalSince(startTime)
        
        do {
            // Try to parse as direct JSON response first (custom provider)
            if let directResponse = try? JSONDecoder().decode(AIAnalysisResponse.self, from: data) {
                return convertToAIResponse(directResponse, requestId: requestId, processingTime: processingTime)
            }
            
            // Parse provider-specific response
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            
            switch currentProvider {
            case .openAI:
                return try parseOpenAIResponse(json: json, requestId: requestId, processingTime: processingTime)
            case .anthropic:
                return try parseAnthropicResponse(json: json, requestId: requestId, processingTime: processingTime)
            case .custom:
                throw NetworkError.invalidResponse("Unable to parse custom provider response")
            }
            
        } catch {
            throw NetworkError.invalidResponse("Failed to parse AI response: \(error.localizedDescription)")
        }
    }
    
    /// Parse OpenAI response
    func parseOpenAIResponse(json: [String: Any]?, requestId: String, processingTime: TimeInterval) throws -> AIResponse {
        guard let json = json,
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NetworkError.invalidResponse("Invalid OpenAI response format")
        }
        
        // Parse the JSON content
        guard let contentData = content.data(using: .utf8),
              let analysisResponse = try? JSONDecoder().decode(AIAnalysisResponse.self, from: contentData) else {
            throw NetworkError.invalidResponse("Invalid JSON in OpenAI response content")
        }
        
        return convertToAIResponse(analysisResponse, requestId: requestId, processingTime: processingTime)
    }
    
    /// Parse Anthropic response
    func parseAnthropicResponse(json: [String: Any]?, requestId: String, processingTime: TimeInterval) throws -> AIResponse {
        guard let json = json,
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw NetworkError.invalidResponse("Invalid Anthropic response format")
        }
        
        // Parse the JSON content
        guard let contentData = text.data(using: .utf8),
              let analysisResponse = try? JSONDecoder().decode(AIAnalysisResponse.self, from: contentData) else {
            throw NetworkError.invalidResponse("Invalid JSON in Anthropic response content")
        }
        
        return convertToAIResponse(analysisResponse, requestId: requestId, processingTime: processingTime)
    }
    
    /// Convert analysis response to AIResponse
    func convertToAIResponse(_ response: AIAnalysisResponse, requestId: String, processingTime: TimeInterval) -> AIResponse {
        let sugarTypes = response.sugarTypes.map { sugarType in
            SugarType(rawValue: sugarType.type) ?? .sucrose
        }
        
        let sugarAnalysis = SugarAnalysis(
            totalSugarIndicators: response.sugarAnalysis.totalSugarIndicators,
            hiddenSugars: response.sugarAnalysis.hiddenSugars,
            sugarAlternatives: response.sugarAnalysis.sugarAlternatives,
            healthImpact: HealthImpact(rawValue: response.sugarAnalysis.healthImpact) ?? .medium,
            recommendations: response.sugarAnalysis.recommendations,
            warnings: response.warnings
        )
        
        return AIResponse(
            requestId: requestId,
            ingredientsAnalyzed: "",
            containsSugar: response.containsSugar,
            sugarTypes: sugarTypes,
            sugarAnalysis: sugarAnalysis,
            confidence: response.confidence,
            processingTime: processingTime,
            warnings: response.warnings
        )
    }
    
    /// Perform test request to validate API key
    func performTestRequest(apiKey: String) async throws -> Bool {
        let testRequest = AIAnalysisRequest(
            ingredients: "sugar, flour, water",
            language: "en",
            analysisType: "sugar_detection",
            detailLevel: "basic",
            requestId: "test-\(UUID().uuidString)"
        )
        
        _ = try await performAnalysis(request: testRequest, apiKey: apiKey)
        return true
    }
    
    /// Generate cache key for ingredients analysis
    func generateCacheKey(ingredients: String, language: String, level: AnalysisLevel) -> String {
        let combined = "\(ingredients)_\(language)_\(level.rawValue)_\(currentProvider.rawValue)"
        let hash = SHA256.hash(data: combined.data(using: .utf8) ?? Data())
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    /// Handle analysis errors
    func handleAnalysisError(_ error: Error) -> NetworkError {
        if let networkError = error as? NetworkError {
            return networkError
        }
        
        if error is DecodingError {
            return .invalidResponse("Failed to decode AI response")
        }
        
        return .unknown(error.localizedDescription)
    }
}

// MARK: - Supporting Models

private struct AIAnalysisRequest: Codable {
    let ingredients: String
    let language: String
    let analysisType: String
    let detailLevel: String
    let requestId: String
    
    enum CodingKeys: String, CodingKey {
        case ingredients
        case language
        case analysisType = "analysis_type"
        case detailLevel = "detail_level"
        case requestId = "request_id"
    }
}

private struct AIAnalysisResponse: Codable {
    let analysisId: String
    let containsSugar: Bool
    let confidence: Double
    let sugarTypes: [SugarTypeResponse]
    let sugarAnalysis: SugarAnalysisResponse
    let processingTimeMs: Double
    let warnings: [String]
    
    enum CodingKeys: String, CodingKey {
        case analysisId = "analysis_id"
        case containsSugar = "contains_sugar"
        case confidence
        case sugarTypes = "sugar_types"
        case sugarAnalysis = "sugar_analysis"
        case processingTimeMs = "processing_time_ms"
        case warnings
    }
}

private struct SugarTypeResponse: Codable {
    let type: String
    let confidence: Double
    let sources: [String]
}

private struct SugarAnalysisResponse: Codable {
    let totalSugarIndicators: Int
    let hiddenSugars: [String]
    let sugarAlternatives: [String]
    let healthImpact: String
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case totalSugarIndicators = "total_sugar_indicators"
        case hiddenSugars = "hidden_sugars"
        case sugarAlternatives = "sugar_alternatives"
        case healthImpact = "health_impact"
        case recommendations
    }
}

// MARK: - KeychainManager Extension

private extension KeychainManager {
    func getAPIKey(for provider: String) -> String? {
        switch provider {
        case "openai":
            return getString(forKey: "openai_api_key")
        case "anthropic":
            return getString(forKey: "anthropic_api_key")
        case "custom":
            return getString(forKey: "custom_ai_api_key")
        default:
            return nil
        }
    }
}

// MARK: - Array Extension

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}