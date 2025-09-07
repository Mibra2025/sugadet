//
//  FoodProduct.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Represents a food product with all its associated information
struct FoodProduct: Codable, Identifiable, Hashable {
    let id = UUID()
    
    // MARK: - Basic Product Information
    let barcode: String
    let name: String?
    let brand: String?
    let quantity: String?
    let packaging: String?
    
    // MARK: - Ingredients & Composition
    let ingredientsText: String?
    let ingredients: [Ingredient]?
    let allergens: [String]?
    let traces: [String]?
    
    // MARK: - Nutritional Information
    let nutritionFacts: NutritionFacts?
    let nutritionGrade: String?
    let novaGroup: Int?
    
    // MARK: - Product Details
    let categories: [String]?
    let labels: [String]?
    let stores: [String]?
    let countries: [String]?
    let imageURL: String?
    
    // MARK: - Data Quality & Source
    let completeness: Double?
    let lastModified: Date?
    let dataSource: DataSource
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case barcode = "code"
        case name = "product_name"
        case brand = "brands"
        case quantity
        case packaging
        case ingredientsText = "ingredients_text"
        case ingredients
        case allergens
        case traces
        case nutritionFacts = "nutriments"
        case nutritionGrade = "nutrition_grade_fr"
        case novaGroup = "nova_group"
        case categories
        case labels
        case stores
        case countries
        case imageURL = "image_url"
        case completeness
        case lastModified = "last_modified_t"
        case dataSource
    }
    
    // MARK: - Computed Properties
    
    /// Returns the display name, falling back to brand or barcode if name is unavailable
    var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        } else if let brand = brand, !brand.isEmpty {
            return brand
        } else {
            return "Product \(barcode)"
        }
    }
    
    /// Returns true if the product has sufficient information for analysis
    var isComplete: Bool {
        return name != nil && ingredientsText != nil
    }
    
    /// Returns true if the product contains ingredients information
    var hasIngredients: Bool {
        return ingredientsText?.isEmpty == false || ingredients?.isEmpty == false
    }
    
    /// Returns a formatted string of all allergens
    var allergensText: String? {
        guard let allergens = allergens, !allergens.isEmpty else { return nil }
        return allergens.joined(separator: ", ")
    }
    
    /// Returns a formatted string of all categories
    var categoriesText: String? {
        guard let categories = categories, !categories.isEmpty else { return nil }
        return categories.joined(separator: ", ")
    }
}

// MARK: - Supporting Models

/// Represents a single ingredient with its properties
struct Ingredient: Codable, Hashable, Identifiable {
    let id = UUID()
    let name: String
    let percentage: Double?
    let origin: String?
    let processing: String?
    
    enum CodingKeys: String, CodingKey {
        case name = "text"
        case percentage = "percent_estimate"
        case origin
        case processing
    }
}

/// Comprehensive nutritional information
struct NutritionFacts: Codable, Hashable {
    // MARK: - Energy
    let energyKJ: Double?
    let energyKcal: Double?
    
    // MARK: - Macronutrients
    let fat: Double?
    let saturatedFat: Double?
    let carbohydrates: Double?
    let sugars: Double?
    let fiber: Double?
    let proteins: Double?
    
    // MARK: - Micronutrients
    let salt: Double?
    let sodium: Double?
    let vitaminC: Double?
    let calcium: Double?
    let iron: Double?
    
    // MARK: - Additional Values
    let additives: [String]?
    
    enum CodingKeys: String, CodingKey {
        case energyKJ = "energy-kj_100g"
        case energyKcal = "energy-kcal_100g"
        case fat = "fat_100g"
        case saturatedFat = "saturated-fat_100g"
        case carbohydrates = "carbohydrates_100g"
        case sugars = "sugars_100g"
        case fiber = "fiber_100g"
        case proteins = "proteins_100g"
        case salt = "salt_100g"
        case sodium = "sodium_100g"
        case vitaminC = "vitamin-c_100g"
        case calcium = "calcium_100g"
        case iron = "iron_100g"
        case additives
    }
    
    /// Returns true if sugar information is available
    var hasSugarInfo: Bool {
        return sugars != nil
    }
    
    /// Returns formatted sugar content string
    var sugarDisplayText: String? {
        guard let sugars = sugars else { return nil }
        return String(format: "%.1fg per 100g", sugars)
    }
}

/// Data source for tracking where the product information came from
enum DataSource: String, Codable, CaseIterable {
    case openFoodFacts = "open_food_facts"
    case userInput = "user_input"
    case cache = "cache"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .openFoodFacts:
            return "Open Food Facts"
        case .userInput:
            return "User Input"
        case .cache:
            return "Cached Data"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Extensions

extension FoodProduct {
    /// Creates a placeholder product for testing or when data is unavailable
    static func placeholder(barcode: String) -> FoodProduct {
        return FoodProduct(
            barcode: barcode,
            name: nil,
            brand: nil,
            quantity: nil,
            packaging: nil,
            ingredientsText: nil,
            ingredients: nil,
            allergens: nil,
            traces: nil,
            nutritionFacts: nil,
            nutritionGrade: nil,
            novaGroup: nil,
            categories: nil,
            labels: nil,
            stores: nil,
            countries: nil,
            imageURL: nil,
            completeness: nil,
            lastModified: nil,
            dataSource: .unknown
        )
    }
    
    /// Creates a sample product for testing and previews
    static let sample = FoodProduct(
        barcode: "3017620422003",
        name: "Nutella",
        brand: "Ferrero",
        quantity: "400g",
        packaging: "Plastic jar",
        ingredientsText: "Sugar, palm oil, hazelnuts (13%), skimmed milk powder (8.7%), fat-reduced cocoa (7.4%), emulsifier lecithins (soya), vanillin.",
        ingredients: [
            Ingredient(name: "Sugar", percentage: 56.3, origin: nil, processing: nil),
            Ingredient(name: "Palm oil", percentage: 30.9, origin: nil, processing: nil),
            Ingredient(name: "Hazelnuts", percentage: 13.0, origin: nil, processing: nil)
        ],
        allergens: ["Milk", "Nuts", "Soya"],
        traces: ["Gluten"],
        nutritionFacts: NutritionFacts(
            energyKJ: 2252,
            energyKcal: 539,
            fat: 30.9,
            saturatedFat: 10.6,
            carbohydrates: 57.5,
            sugars: 56.3,
            fiber: 0,
            proteins: 6.3,
            salt: 0.107,
            sodium: nil,
            vitaminC: nil,
            calcium: nil,
            iron: nil,
            additives: ["E322"]
        ),
        nutritionGrade: "e",
        novaGroup: 4,
        categories: ["Spreads", "Sweet spreads", "Cocoa and hazelnut spreads"],
        labels: ["Green Dot"],
        stores: ["Carrefour", "Intermarché", "Magasins U"],
        countries: ["France"],
        imageURL: "https://images.openfoodfacts.org/images/products/301/762/042/2003/front_fr.4.400.jpg",
        completeness: 0.8125,
        lastModified: Date(),
        dataSource: .openFoodFacts
    )
}