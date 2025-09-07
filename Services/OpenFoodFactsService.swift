//
//  OpenFoodFactsService.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Service for integrating with Open Food Facts API for product lookups
@MainActor
final class OpenFoodFactsService: ObservableObject {
    
    // MARK: - Singleton
    static let shared = OpenFoodFactsService()
    
    // MARK: - Configuration
    
    private struct APIConfig {
        static let baseURL = "https://world.openfoodfacts.org/api/v0"
        static let userAgent = "AI-Sugar-Detection-iOS/1.0"
        static let defaultLanguage = "en"
        static let timeout: TimeInterval = 30
        static let rateLimit = 100 // requests per minute
    }
    
    // MARK: - Properties
    
    private let networkManager: NetworkManager
    private let cacheManager: CacheManager
    private let requestQueue: RequestQueue
    
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: NetworkError?
    
    // Request tracking
    private var activeRequests: Set<String> = []
    
    // MARK: - Initialization
    
    private init() {
        self.networkManager = NetworkManager.shared
        self.cacheManager = CacheManager.shared
        self.requestQueue = RequestQueue.shared
    }
    
    // MARK: - Public Methods
    
    /// Fetches product information for a given barcode
    func fetchProduct(barcode: String) async throws -> FoodProduct {
        // Validate barcode format
        guard isValidBarcode(barcode) else {
            throw NetworkError.invalidBarcode(barcode)
        }
        
        // Check if already being fetched
        guard !activeRequests.contains(barcode) else {
            throw NetworkError.requestFailed(NSError(domain: "OpenFoodFactsService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Request already in progress"]))
        }
        
        // Check cache first
        if let cachedProduct = await cacheManager.getCachedProduct(forBarcode: barcode) {
            return cachedProduct
        }
        
        // Mark as active request
        activeRequests.insert(barcode)
        isLoading = true
        lastError = nil
        
        defer {
            activeRequests.remove(barcode)
            isLoading = activeRequests.count > 0
        }
        
        do {
            // Fetch from API using request queue
            let response: OpenFoodFactsResponse = try await requestQueue.enqueue(
                request: { [weak self] in
                    guard let self = self else {
                        throw NetworkError.serviceUnavailable
                    }
                    return try await self.performProductLookup(barcode: barcode)
                },
                priority: .normal,
                serviceType: .openFoodFacts,
                metadata: ["barcode": barcode]
            )
            
            // Process and validate response
            let product = try processProductResponse(response, barcode: barcode)
            
            // Cache the result
            await cacheManager.cacheProduct(product, forBarcode: barcode)
            
            return product
            
        } catch let error as NetworkError {
            lastError = error
            throw error
        } catch {
            let networkError = NetworkError.requestFailed(error)
            lastError = networkError
            throw networkError
        }
    }
    
    /// Searches for products by name (for future implementation)
    func searchProducts(query: String, page: Int = 1, pageSize: Int = 20) async throws -> [FoodProduct] {
        // This would implement product search functionality
        // For now, throwing not implemented error
        throw NetworkError.serviceUnavailable
    }
    
    /// Fetches product suggestions based on partial barcode or name
    func getSuggestions(for input: String) async throws -> [FoodProduct] {
        // This would implement autocomplete/suggestions
        throw NetworkError.serviceUnavailable
    }
    
    // MARK: - Private API Methods
    
    private func performProductLookup(barcode: String) async throws -> OpenFoodFactsResponse {
        // Construct URL
        guard let url = buildProductURL(barcode: barcode) else {
            throw NetworkError.invalidURL("Failed to construct Open Food Facts URL")
        }
        
        // Create request
        let request = networkManager.createGetRequest(
            url: url,
            headers: [
                "User-Agent": APIConfig.userAgent,
                "Accept-Language": APIConfig.defaultLanguage
            ]
        )
        
        // Perform request
        return try await networkManager.performRequest(
            request,
            responseType: OpenFoodFactsResponse.self,
            retryCount: 3,
            retryDelay: 2.0
        )
    }
    
    private func buildProductURL(barcode: String, language: String = APIConfig.defaultLanguage) -> URL? {
        let urlString = "\(APIConfig.baseURL)/product/\(barcode).json"
        
        guard var urlComponents = URLComponents(string: urlString) else {
            return nil
        }
        
        // Add query parameters if needed
        urlComponents.queryItems = [
            URLQueryItem(name: "fields", value: "product_name,brands,quantity,ingredients_text,allergens,traces,categories,labels,nutriments,nutrition_grade_fr,nova_group,image_url,image_ingredients_url,image_nutrition_url,completeness,last_modified_t")
        ]
        
        return urlComponents.url
    }
    
    // MARK: - Response Processing
    
    private func processProductResponse(_ response: OpenFoodFactsResponse, barcode: String) throws -> FoodProduct {
        
        // Check if product was found
        guard response.status == 1 else {
            if response.status == 0 {
                throw NetworkError.productNotFound(barcode)
            } else {
                throw NetworkError.invalidResponse
            }
        }
        
        // Ensure we have product data
        guard let productData = response.product else {
            throw NetworkError.productNotFound(barcode)
        }
        
        // Convert Open Food Facts product to our FoodProduct model
        return try convertToFoodProduct(productData, barcode: barcode)
    }
    
    private func convertToFoodProduct(_ data: OpenFoodFactsProduct, barcode: String) throws -> FoodProduct {
        
        // Process ingredients if available
        let ingredients = processIngredients(data.ingredients)
        
        // Process nutrition facts
        let nutritionFacts = processNutritionFacts(data.nutriments)
        
        // Process categories, allergens, etc.
        let categories = processStringList(data.categories)
        let allergens = processStringList(data.allergens)
        let traces = processStringList(data.traces)
        let labels = processStringList(data.labels)
        let stores = processStringList(data.stores)
        let countries = processStringList(data.countries)
        
        // Convert timestamp to date
        let lastModified = data.lastModifiedT.flatMap { Date(timeIntervalSince1970: $0) }
        
        return FoodProduct(
            barcode: barcode,
            name: data.productName?.isEmpty == false ? data.productName : nil,
            brand: data.brands?.isEmpty == false ? data.brands : nil,
            quantity: data.quantity?.isEmpty == false ? data.quantity : nil,
            packaging: data.packaging?.isEmpty == false ? data.packaging : nil,
            ingredientsText: data.ingredientsText?.isEmpty == false ? data.ingredientsText : nil,
            ingredients: ingredients,
            allergens: allergens,
            traces: traces,
            nutritionFacts: nutritionFacts,
            nutritionGrade: data.nutritionGradeFr?.isEmpty == false ? data.nutritionGradeFr : nil,
            novaGroup: data.novaGroup,
            categories: categories,
            labels: labels,
            stores: stores,
            countries: countries,
            imageURL: data.imageURL?.isEmpty == false ? data.imageURL : nil,
            completeness: data.completeness,
            lastModified: lastModified,
            dataSource: .openFoodFacts
        )
    }
    
    // MARK: - Data Processing Helpers
    
    private func processIngredients(_ ingredients: [OpenFoodFactsIngredient]?) -> [Ingredient]? {
        guard let ingredients = ingredients, !ingredients.isEmpty else { return nil }
        
        return ingredients.compactMap { ingredientData in
            guard let name = ingredientData.text, !name.isEmpty else { return nil }
            
            return Ingredient(
                name: name,
                percentage: ingredientData.percentEstimate,
                origin: ingredientData.origins?.first,
                processing: ingredientData.processing
            )
        }
    }
    
    private func processNutritionFacts(_ nutriments: OpenFoodFactsNutriments?) -> NutritionFacts? {
        guard let nutriments = nutriments else { return nil }
        
        return NutritionFacts(
            energyKJ: nutriments.energyKj100g,
            energyKcal: nutriments.energyKcal100g,
            fat: nutriments.fat100g,
            saturatedFat: nutriments.saturatedFat100g,
            carbohydrates: nutriments.carbohydrates100g,
            sugars: nutriments.sugars100g,
            fiber: nutriments.fiber100g,
            proteins: nutriments.proteins100g,
            salt: nutriments.salt100g,
            sodium: nutriments.sodium100g,
            vitaminC: nutriments.vitaminC100g,
            calcium: nutriments.calcium100g,
            iron: nutriments.iron100g,
            additives: processStringList(nutriments.additives)
        )
    }
    
    private func processStringList(_ input: String?) -> [String]? {
        guard let input = input, !input.isEmpty else { return nil }
        
        let components = input.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return components.isEmpty ? nil : components
    }
    
    // MARK: - Validation
    
    private func isValidBarcode(_ barcode: String) -> Bool {
        // Remove any whitespace
        let cleanBarcode = barcode.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check if it's numeric and has valid length
        guard cleanBarcode.allSatisfy(\.isNumber) else { return false }
        
        // Valid barcode lengths: EAN-8 (8), EAN-13 (13), UPC-A (12), UPC-E (8)
        let validLengths = [8, 12, 13, 14]
        return validLengths.contains(cleanBarcode.count)
    }
    
    // MARK: - Cache Management
    
    /// Clears all cached Open Food Facts data
    func clearCache() async {
        await cacheManager.clear(category: .openFoodFacts)
    }
    
    /// Returns cache statistics for Open Food Facts data
    func getCacheStatistics() async -> CacheStatistics {
        return await cacheManager.getCacheStatistics()
    }
    
    /// Preloads products for given barcodes (for batch operations)
    func preloadProducts(barcodes: [String]) async {
        let tasks = barcodes.map { barcode in
            Task {
                do {
                    let _ = try await fetchProduct(barcode: barcode)
                } catch {
                    // Silently handle errors for preloading
                    print("Failed to preload product \(barcode): \(error)")
                }
            }
        }
        
        // Wait for all preload tasks to complete
        for task in tasks {
            await task.value
        }
    }
}

// MARK: - Open Food Facts API Models

private struct OpenFoodFactsResponse: Codable {
    let status: Int
    let statusVerbose: String?
    let product: OpenFoodFactsProduct?
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
    }
}

private struct OpenFoodFactsProduct: Codable {
    let productName: String?
    let brands: String?
    let quantity: String?
    let packaging: String?
    let ingredientsText: String?
    let ingredients: [OpenFoodFactsIngredient]?
    let allergens: String?
    let traces: String?
    let categories: String?
    let labels: String?
    let stores: String?
    let countries: String?
    let nutriments: OpenFoodFactsNutriments?
    let nutritionGradeFr: String?
    let novaGroup: Int?
    let imageURL: String?
    let imageIngredientsURL: String?
    let imageNutritionURL: String?
    let completeness: Double?
    let lastModifiedT: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case brands
        case quantity
        case packaging
        case ingredientsText = "ingredients_text"
        case ingredients
        case allergens
        case traces
        case categories
        case labels
        case stores
        case countries
        case nutriments
        case nutritionGradeFr = "nutrition_grade_fr"
        case novaGroup = "nova_group"
        case imageURL = "image_url"
        case imageIngredientsURL = "image_ingredients_url"
        case imageNutritionURL = "image_nutrition_url"
        case completeness
        case lastModifiedT = "last_modified_t"
    }
}

private struct OpenFoodFactsIngredient: Codable {
    let text: String?
    let percentEstimate: Double?
    let processing: String?
    let origins: [String]?
    
    enum CodingKeys: String, CodingKey {
        case text
        case percentEstimate = "percent_estimate"
        case processing
        case origins
    }
}

private struct OpenFoodFactsNutriments: Codable {
    let energyKj100g: Double?
    let energyKcal100g: Double?
    let fat100g: Double?
    let saturatedFat100g: Double?
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let fiber100g: Double?
    let proteins100g: Double?
    let salt100g: Double?
    let sodium100g: Double?
    let vitaminC100g: Double?
    let calcium100g: Double?
    let iron100g: Double?
    let additives: String?
    
    enum CodingKeys: String, CodingKey {
        case energyKj100g = "energy-kj_100g"
        case energyKcal100g = "energy-kcal_100g"
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case fiber100g = "fiber_100g"
        case proteins100g = "proteins_100g"
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
        case vitaminC100g = "vitamin-c_100g"
        case calcium100g = "calcium_100g"
        case iron100g = "iron_100g"
        case additives
    }
}

// MARK: - Extensions for Testing

extension OpenFoodFactsService {
    
    /// Creates a mock product for testing purposes
    static func mockProduct(barcode: String) -> FoodProduct {
        return FoodProduct(
            barcode: barcode,
            name: "Mock Product",
            brand: "Mock Brand",
            quantity: "100g",
            packaging: "Mock Packaging",
            ingredientsText: "Mock ingredients for testing",
            ingredients: [
                Ingredient(name: "Mock Ingredient 1", percentage: 50.0, origin: nil, processing: nil),
                Ingredient(name: "Mock Ingredient 2", percentage: 30.0, origin: nil, processing: nil)
            ],
            allergens: ["Mock Allergen"],
            traces: ["Mock Trace"],
            nutritionFacts: NutritionFacts(
                energyKJ: 2000,
                energyKcal: 500,
                fat: 10.0,
                saturatedFat: 5.0,
                carbohydrates: 60.0,
                sugars: 30.0,
                fiber: 5.0,
                proteins: 8.0,
                salt: 1.0,
                sodium: nil,
                vitaminC: nil,
                calcium: nil,
                iron: nil,
                additives: nil
            ),
            nutritionGrade: "b",
            novaGroup: 3,
            categories: ["Mock Category"],
            labels: ["Mock Label"],
            stores: ["Mock Store"],
            countries: ["Mock Country"],
            imageURL: "https://example.com/mock-image.jpg",
            completeness: 0.8,
            lastModified: Date(),
            dataSource: .openFoodFacts
        )
    }
}