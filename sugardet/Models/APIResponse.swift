//
//  APIResponse.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

// MARK: - Open Food Facts API Response Models

/// Root response structure from Open Food Facts API
struct OpenFoodFactsResponse: Codable {
    let status: Int
    let statusVerbose: String
    let product: OpenFoodFactsProduct?
    let code: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case statusVerbose = "status_verbose"
        case product
        case code
    }
    
    /// Returns true if the API request was successful
    var isSuccess: Bool {
        return status == 1
    }
    
    /// Returns true if a product was found
    var hasProduct: Bool {
        return product != nil
    }
}

/// Product data structure from Open Food Facts API
struct OpenFoodFactsProduct: Codable {
    // MARK: - Basic Product Information
    let code: String?
    let productName: String?
    let productNameEn: String?
    let genericName: String?
    let brands: String?
    let categories: String?
    let quantity: String?
    let packaging: String?
    
    // MARK: - Ingredients
    let ingredientsText: String?
    let ingredientsTextEn: String?
    let ingredientsHierarchy: [String]?
    let allergens: String?
    let allergensHierarchy: [String]?
    let traces: String?
    let tracesHierarchy: [String]?
    
    // MARK: - Nutritional Information
    let nutriments: OpenFoodFactsNutriments?
    let nutritionGradeFr: String?
    let nutritionGrades: String?
    let novaGroup: Int?
    let nutriscoreScore: Int?
    let nutriscoreGrade: String?
    
    // MARK: - Additional Product Details
    let labels: String?
    let labelsHierarchy: [String]?
    let stores: String?
    let countries: String?
    let countriesHierarchy: [String]?
    let manufacturingPlaces: String?
    let origins: String?
    
    // MARK: - Images
    let imageUrl: String?
    let imageFrontUrl: String?
    let imageIngredientsUrl: String?
    let imageNutritionUrl: String?
    let imagePackagingUrl: String?
    let selectedImages: SelectedImages?
    
    // MARK: - Data Quality and Metadata
    let completeness: Double?
    let dataQualityErrors: [String]?
    let dataQualityWarnings: [String]?
    let lastModifiedBy: String?
    let lastModifiedT: Int?
    let rev: Int?
    let createdT: Int?
    let creator: String?
    
    // MARK: - Additional Fields
    let servingSize: String?
    let servingQuantity: Double?
    let additives: String?
    let additivesN: Int?
    let ingredientsAnalysisTags: [String]?
    let ecoscore: String?
    let ecoscoreGrade: String?
    
    enum CodingKeys: String, CodingKey {
        case code
        case productName = "product_name"
        case productNameEn = "product_name_en"
        case genericName = "generic_name"
        case brands
        case categories
        case quantity
        case packaging
        case ingredientsText = "ingredients_text"
        case ingredientsTextEn = "ingredients_text_en"
        case ingredientsHierarchy = "ingredients_hierarchy"
        case allergens
        case allergensHierarchy = "allergens_hierarchy"
        case traces
        case tracesHierarchy = "traces_hierarchy"
        case nutriments
        case nutritionGradeFr = "nutrition_grade_fr"
        case nutritionGrades = "nutrition_grades"
        case novaGroup = "nova_group"
        case nutriscoreScore = "nutriscore_score"
        case nutriscoreGrade = "nutriscore_grade"
        case labels
        case labelsHierarchy = "labels_hierarchy"
        case stores
        case countries
        case countriesHierarchy = "countries_hierarchy"
        case manufacturingPlaces = "manufacturing_places"
        case origins
        case imageUrl = "image_url"
        case imageFrontUrl = "image_front_url"
        case imageIngredientsUrl = "image_ingredients_url"
        case imageNutritionUrl = "image_nutrition_url"
        case imagePackagingUrl = "image_packaging_url"
        case selectedImages = "selected_images"
        case completeness
        case dataQualityErrors = "data_quality_errors_tags"
        case dataQualityWarnings = "data_quality_warnings_tags"
        case lastModifiedBy = "last_modified_by"
        case lastModifiedT = "last_modified_t"
        case rev
        case createdT = "created_t"
        case creator
        case servingSize = "serving_size"
        case servingQuantity = "serving_quantity"
        case additives = "additives_tags"
        case additivesN = "additives_n"
        case ingredientsAnalysisTags = "ingredients_analysis_tags"
        case ecoscore = "ecoscore_score"
        case ecoscoreGrade = "ecoscore_grade"
    }
    
    // MARK: - Computed Properties
    
    /// Returns the best available product name
    var bestProductName: String? {
        return productNameEn ?? productName ?? genericName
    }
    
    /// Returns the best available ingredients text
    var bestIngredientsText: String? {
        return ingredientsTextEn ?? ingredientsText
    }
    
    /// Converts comma-separated strings to arrays
    var categoriesArray: [String] {
        return categories?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
    
    var allergensArray: [String] {
        return allergens?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
    
    var tracesArray: [String] {
        return traces?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
    
    var labelsArray: [String] {
        return labels?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
    
    var storesArray: [String] {
        return stores?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
    
    var countriesArray: [String] {
        return countries?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }
    
    /// Returns the creation date if available
    var createdDate: Date? {
        guard let timestamp = createdT else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    /// Returns the last modified date if available
    var lastModifiedDate: Date? {
        guard let timestamp = lastModifiedT else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(timestamp))
    }
    
    /// Returns true if the product has sufficient data quality
    var hasGoodDataQuality: Bool {
        guard let completeness = completeness else { return false }
        return completeness > 0.7 && (dataQualityErrors?.isEmpty ?? true)
    }
}

/// Nutritional information from Open Food Facts
struct OpenFoodFactsNutriments: Codable {
    // MARK: - Energy
    let energy: Double?
    let energyKj: Double?
    let energyKcal: Double?
    let energy100g: Double?
    let energyKj100g: Double?
    let energyKcal100g: Double?
    
    // MARK: - Macronutrients (per 100g)
    let fat100g: Double?
    let saturatedFat100g: Double?
    let monounsaturatedFat100g: Double?
    let polyunsaturatedFat100g: Double?
    let trans_fat100g: Double?
    let cholesterol100g: Double?
    
    let carbohydrates100g: Double?
    let sugars100g: Double?
    let addedSugars100g: Double?
    let sucrose100g: Double?
    let glucose100g: Double?
    let fructose100g: Double?
    let lactose100g: Double?
    let maltose100g: Double?
    let fiber100g: Double?
    let insolubleFiber100g: Double?
    let solubleFiber100g: Double?
    
    let proteins100g: Double?
    
    // MARK: - Minerals (per 100g)
    let salt100g: Double?
    let sodium100g: Double?
    let calcium100g: Double?
    let iron100g: Double?
    let magnesium100g: Double?
    let phosphorus100g: Double?
    let potassium100g: Double?
    let zinc100g: Double?
    
    // MARK: - Vitamins (per 100g)
    let vitaminA100g: Double?
    let betaCarotene100g: Double?
    let vitaminD100g: Double?
    let vitaminE100g: Double?
    let vitaminK100g: Double?
    let vitaminC100g: Double?
    let vitaminB1100g: Double?
    let vitaminB2100g: Double?
    let vitaminB3100g: Double?
    let vitaminB6100g: Double?
    let vitaminB9100g: Double?
    let vitaminB12100g: Double?
    let biotin100g: Double?
    
    // MARK: - Additional nutrients
    let alcohol100g: Double?
    let caffeine100g: Double?
    let taurine100g: Double?
    
    enum CodingKeys: String, CodingKey {
        case energy
        case energyKj = "energy-kj"
        case energyKcal = "energy-kcal"
        case energy100g = "energy_100g"
        case energyKj100g = "energy-kj_100g"
        case energyKcal100g = "energy-kcal_100g"
        
        case fat100g = "fat_100g"
        case saturatedFat100g = "saturated-fat_100g"
        case monounsaturatedFat100g = "monounsaturated-fat_100g"
        case polyunsaturatedFat100g = "polyunsaturated-fat_100g"
        case trans_fat100g = "trans-fat_100g"
        case cholesterol100g = "cholesterol_100g"
        
        case carbohydrates100g = "carbohydrates_100g"
        case sugars100g = "sugars_100g"
        case addedSugars100g = "added-sugars_100g"
        case sucrose100g = "sucrose_100g"
        case glucose100g = "glucose_100g"
        case fructose100g = "fructose_100g"
        case lactose100g = "lactose_100g"
        case maltose100g = "maltose_100g"
        case fiber100g = "fiber_100g"
        case insolubleFiber100g = "insoluble-fiber_100g"
        case solubleFiber100g = "soluble-fiber_100g"
        
        case proteins100g = "proteins_100g"
        
        case salt100g = "salt_100g"
        case sodium100g = "sodium_100g"
        case calcium100g = "calcium_100g"
        case iron100g = "iron_100g"
        case magnesium100g = "magnesium_100g"
        case phosphorus100g = "phosphorus_100g"
        case potassium100g = "potassium_100g"
        case zinc100g = "zinc_100g"
        
        case vitaminA100g = "vitamin-a_100g"
        case betaCarotene100g = "beta-carotene_100g"
        case vitaminD100g = "vitamin-d_100g"
        case vitaminE100g = "vitamin-e_100g"
        case vitaminK100g = "vitamin-k_100g"
        case vitaminC100g = "vitamin-c_100g"
        case vitaminB1100g = "vitamin-b1_100g"
        case vitaminB2100g = "vitamin-b2_100g"
        case vitaminB3100g = "vitamin-b3_100g"
        case vitaminB6100g = "vitamin-b6_100g"
        case vitaminB9100g = "vitamin-b9_100g"
        case vitaminB12100g = "vitamin-b12_100g"
        case biotin100g = "biotin_100g"
        
        case alcohol100g = "alcohol_100g"
        case caffeine100g = "caffeine_100g"
        case taurine100g = "taurine_100g"
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if sugar information is available
    var hasSugarInfo: Bool {
        return sugars100g != nil || hasDetailedSugarInfo
    }
    
    /// Returns true if detailed sugar breakdown is available
    var hasDetailedSugarInfo: Bool {
        return sucrose100g != nil || glucose100g != nil || fructose100g != nil || lactose100g != nil || maltose100g != nil
    }
    
    /// Returns formatted total sugar content
    var sugarContentText: String? {
        guard let sugars = sugars100g else { return nil }
        return String(format: "%.1fg sugar per 100g", sugars)
    }
    
    /// Returns formatted total energy content
    var energyContentText: String? {
        guard let energy = energyKcal100g else { return nil }
        return String(format: "%.0f kcal per 100g", energy)
    }
    
    /// Returns all available sugar types as a dictionary
    var sugarBreakdown: [String: Double] {
        var breakdown: [String: Double] = [:]
        
        if let sucrose = sucrose100g { breakdown["Sucrose"] = sucrose }
        if let glucose = glucose100g { breakdown["Glucose"] = glucose }
        if let fructose = fructose100g { breakdown["Fructose"] = fructose }
        if let lactose = lactose100g { breakdown["Lactose"] = lactose }
        if let maltose = maltose100g { breakdown["Maltose"] = maltose }
        
        return breakdown
    }
    
    /// Returns sugar category based on total sugar content
    var sugarCategory: SugarContentCategory {
        guard let sugars = sugars100g else { return .unknown }
        
        switch sugars {
        case 0..<5:
            return .low
        case 5..<22.5:
            return .medium
        case 22.5...:
            return .high
        default:
            return .unknown
        }
    }
}

/// Selected images for different views
struct SelectedImages: Codable {
    let front: ImageVariants?
    let ingredients: ImageVariants?
    let nutrition: ImageVariants?
    let packaging: ImageVariants?
    
    enum CodingKeys: String, CodingKey {
        case front
        case ingredients
        case nutrition
        case packaging
    }
}

/// Image variants for different sizes
struct ImageVariants: Codable {
    let display: ImageDetails?
    let small: ImageDetails?
    let thumb: ImageDetails?
    
    enum CodingKeys: String, CodingKey {
        case display
        case small
        case thumb
    }
}

/// Details for a specific image
struct ImageDetails: Codable {
    let url: String?
    let width: Int?
    let height: Int?
    
    enum CodingKeys: String, CodingKey {
        case url
        case width
        case height
    }
}

/// Sugar content categories based on nutritional guidelines
enum SugarContentCategory: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low Sugar"
        case .medium:
            return "Medium Sugar"
        case .high:
            return "High Sugar"
        case .unknown:
            return "Unknown"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Less than 5g per 100g"
        case .medium:
            return "5-22.5g per 100g"
        case .high:
            return "More than 22.5g per 100g"
        case .unknown:
            return "Sugar content unavailable"
        }
    }
    
    var color: String {
        switch self {
        case .low:
            return "green"
        case .medium:
            return "orange"
        case .high:
            return "red"
        case .unknown:
            return "gray"
        }
    }
}

// MARK: - Extensions

extension OpenFoodFactsProduct {
    /// Converts the OpenFoodFacts product to our internal FoodProduct model
    func toFoodProduct() -> FoodProduct {
        return FoodProduct(
            barcode: code ?? "",
            name: bestProductName,
            brand: brands,
            quantity: quantity,
            packaging: packaging,
            ingredientsText: bestIngredientsText,
            ingredients: nil, // Would need separate parsing for ingredients hierarchy
            allergens: allergensArray.isEmpty ? nil : allergensArray,
            traces: tracesArray.isEmpty ? nil : tracesArray,
            nutritionFacts: nutriments?.toNutritionFacts(),
            nutritionGrade: nutritionGradeFr,
            novaGroup: novaGroup,
            categories: categoriesArray.isEmpty ? nil : categoriesArray,
            labels: labelsArray.isEmpty ? nil : labelsArray,
            stores: storesArray.isEmpty ? nil : storesArray,
            countries: countriesArray.isEmpty ? nil : countriesArray,
            imageURL: imageFrontUrl ?? imageUrl,
            completeness: completeness,
            lastModified: lastModifiedDate,
            dataSource: .openFoodFacts
        )
    }
}

extension OpenFoodFactsNutriments {
    /// Converts OpenFoodFacts nutriments to our internal NutritionFacts model
    func toNutritionFacts() -> NutritionFacts {
        return NutritionFacts(
            energyKJ: energyKj100g,
            energyKcal: energyKcal100g,
            fat: fat100g,
            saturatedFat: saturatedFat100g,
            carbohydrates: carbohydrates100g,
            sugars: sugars100g,
            fiber: fiber100g,
            proteins: proteins100g,
            salt: salt100g,
            sodium: sodium100g,
            vitaminC: vitaminC100g,
            calcium: calcium100g,
            iron: iron100g,
            additives: nil // Would need separate processing for additives
        )
    }
}

extension OpenFoodFactsResponse {
    /// Creates a sample successful response for testing
    static let sampleSuccess = OpenFoodFactsResponse(
        status: 1,
        statusVerbose: "product found",
        product: .sample,
        code: "3017620422003"
    )
    
    /// Creates a sample not found response for testing
    static let sampleNotFound = OpenFoodFactsResponse(
        status: 0,
        statusVerbose: "product not found",
        product: nil,
        code: "1234567890123"
    )
}

extension OpenFoodFactsProduct {
    /// Creates a sample product for testing
    static let sample = OpenFoodFactsProduct(
        code: "3017620422003",
        productName: "Nutella",
        productNameEn: "Nutella",
        genericName: "Hazelnut cocoa spread",
        brands: "Ferrero",
        categories: "Spreads,Sweet spreads,Cocoa and hazelnut spreads",
        quantity: "400g",
        packaging: "Plastic jar",
        ingredientsText: "Sugar, palm oil, hazelnuts (13%), skimmed milk powder (8.7%), fat-reduced cocoa (7.4%), emulsifier lecithins (soya), vanillin.",
        ingredientsTextEn: "Sugar, palm oil, hazelnuts (13%), skimmed milk powder (8.7%), fat-reduced cocoa (7.4%), emulsifier lecithins (soya), vanillin.",
        ingredientsHierarchy: ["en:sugar", "en:palm-oil", "en:hazelnut", "en:skimmed-milk-powder", "en:cocoa", "en:emulsifier", "en:lecithin", "en:vanillin"],
        allergens: "Milk,Nuts,Soya",
        allergensHierarchy: ["en:milk", "en:nuts", "en:soybeans"],
        traces: "Gluten",
        tracesHierarchy: ["en:gluten"],
        nutriments: .sample,
        nutritionGradeFr: "e",
        nutritionGrades: "e",
        novaGroup: 4,
        nutriscoreScore: 26,
        nutriscoreGrade: "e",
        labels: "Green Dot",
        labelsHierarchy: ["en:green-dot"],
        stores: "Carrefour,Intermarché,Magasins U",
        countries: "France",
        countriesHierarchy: ["en:france"],
        manufacturingPlaces: "Italy",
        origins: "European Union",
        imageUrl: "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.4.400.jpg",
        imageFrontUrl: "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.4.400.jpg",
        imageIngredientsUrl: "https://images.openfoodfacts.org/images/products/301/762/042/2003/ingredients_fr.8.400.jpg",
        imageNutritionUrl: "https://images.openfoodfacts.org/images/products/301/762/042/2003/nutrition_fr.7.400.jpg",
        imagePackagingUrl: nil,
        selectedImages: nil,
        completeness: 0.8125,
        dataQualityErrors: nil,
        dataQualityWarnings: nil,
        lastModifiedBy: "openfoodfacts-contributors",
        lastModifiedT: 1699123456,
        rev: 42,
        createdT: 1577836800,
        creator: "openfoodfacts-contributors",
        servingSize: "15g",
        servingQuantity: 15.0,
        additives: "E322",
        additivesN: 1,
        ingredientsAnalysisTags: ["en:palm-oil", "en:non-vegan", "en:vegetarian"],
        ecoscore: "50",
        ecoscoreGrade: "c"
    )
}

extension OpenFoodFactsNutriments {
    /// Creates a sample nutriments for testing
    static let sample = OpenFoodFactsNutriments(
        energy: 2252,
        energyKj: 2252,
        energyKcal: 539,
        energy100g: 2252,
        energyKj100g: 2252,
        energyKcal100g: 539,
        fat100g: 30.9,
        saturatedFat100g: 10.6,
        monounsaturatedFat100g: nil,
        polyunsaturatedFat100g: nil,
        trans_fat100g: nil,
        cholesterol100g: nil,
        carbohydrates100g: 57.5,
        sugars100g: 56.3,
        addedSugars100g: 55.0,
        sucrose100g: 50.2,
        glucose100g: 3.1,
        fructose100g: 3.0,
        lactose100g: 6.2,
        maltose100g: nil,
        fiber100g: 0,
        insolubleFiber100g: nil,
        solubleFiber100g: nil,
        proteins100g: 6.3,
        salt100g: 0.107,
        sodium100g: 0.043,
        calcium100g: 108,
        iron100g: 4.2,
        magnesium100g: 64,
        phosphorus100g: 163,
        potassium100g: 407,
        zinc100g: 2.4,
        vitaminA100g: nil,
        betaCarotene100g: nil,
        vitaminD100g: nil,
        vitaminE100g: 5.4,
        vitaminK100g: nil,
        vitaminC100g: nil,
        vitaminB1100g: nil,
        vitaminB2100g: nil,
        vitaminB3100g: nil,
        vitaminB6100g: nil,
        vitaminB9100g: nil,
        vitaminB12100g: nil,
        biotin100g: nil,
        alcohol100g: nil,
        caffeine100g: nil,
        taurine100g: nil
    )
}