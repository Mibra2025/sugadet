//
//  AIResponse.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Represents the response from AI service for sugar detection analysis
struct AIResponse: Codable, Identifiable, Hashable {
    let id = UUID()
    
    // MARK: - Request Information
    let requestId: String
    let ingredientsAnalyzed: String
    let processingTime: TimeInterval
    let createdAt: Date
    
    // MARK: - Sugar Detection Results
    let containsSugar: Bool
    let sugarTypes: [SugarTypeDetection]
    let sugarAnalysis: SugarAnalysis
    let confidence: Double
    
    // MARK: - Additional Information
    let warnings: [String]
    let recommendations: [String]
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case requestId = "analysis_id"
        case ingredientsAnalyzed = "ingredients"
        case processingTime = "processing_time_ms"
        case createdAt = "timestamp"
        case containsSugar = "contains_sugar"
        case sugarTypes = "sugar_types"
        case sugarAnalysis = "sugar_analysis"
        case confidence
        case warnings
        case recommendations
    }
    
    // MARK: - Computed Properties
    
    /// Returns a user-friendly confidence description
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
    
    /// Returns true if the confidence is high enough for reliable results
    var isReliable: Bool {
        return confidence >= 0.7
    }
    
    /// Returns formatted processing time string
    var processingTimeText: String {
        if processingTime < 1000 {
            return String(format: "%.0fms", processingTime)
        } else {
            return String(format: "%.1fs", processingTime / 1000)
        }
    }
    
    /// Returns the total number of sugar types detected
    var sugarTypeCount: Int {
        return sugarTypes.filter { $0.confidence > 0.5 }.count
    }
    
    /// Returns the highest confidence sugar type detected
    var primarySugarType: SugarTypeDetection? {
        return sugarTypes.max { $0.confidence < $1.confidence }
    }
    
    /// Returns summary text for display
    var summaryText: String {
        if containsSugar {
            let typeCount = sugarTypeCount
            if typeCount == 1 {
                return "Contains 1 type of sugar"
            } else {
                return "Contains \(typeCount) types of sugar"
            }
        } else {
            return "No sugar detected"
        }
    }
}

// MARK: - Supporting Models

/// Represents a detected sugar type with its confidence and sources
struct SugarTypeDetection: Codable, Hashable, Identifiable {
    let id = UUID()
    let type: SugarType
    let confidence: Double
    let sources: [String]
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case type
        case confidence
        case sources
        case description
    }
    
    /// Returns a formatted confidence percentage
    var confidencePercentage: String {
        return String(format: "%.0f%%", confidence * 100)
    }
    
    /// Returns true if this detection is considered reliable
    var isReliable: Bool {
        return confidence >= 0.6
    }
    
    /// Returns formatted sources text
    var sourcesText: String {
        return sources.joined(separator: ", ")
    }
}

/// Enum representing different types of sugars that can be detected
enum SugarType: String, CaseIterable, Codable, Hashable {
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
    case dextrose = "dextrose"
    case galactose = "galactose"
    case ribose = "ribose"
    case xylose = "xylose"
    case agave = "agave"
    case coconutSugar = "coconut_sugar"
    case dateSugar = "date_sugar"
    case molasses = "molasses"
    case corn_syrup = "corn_syrup"
    case rice_syrup = "rice_syrup"
    
    /// Human-readable display name for the sugar type
    var displayName: String {
        switch self {
        case .sucrose:
            return "Sucrose (Table Sugar)"
        case .glucose:
            return "Glucose"
        case .fructose:
            return "Fructose (Fruit Sugar)"
        case .lactose:
            return "Lactose (Milk Sugar)"
        case .maltose:
            return "Maltose (Malt Sugar)"
        case .highFructoseCornSyrup:
            return "High Fructose Corn Syrup"
        case .brownSugar:
            return "Brown Sugar"
        case .honeyMaple:
            return "Honey/Maple Syrup"
        case .artificialSweetener:
            return "Artificial Sweetener"
        case .sugarAlcohol:
            return "Sugar Alcohol"
        case .dextrose:
            return "Dextrose"
        case .galactose:
            return "Galactose"
        case .ribose:
            return "Ribose"
        case .xylose:
            return "Xylose"
        case .agave:
            return "Agave Syrup"
        case .coconutSugar:
            return "Coconut Sugar"
        case .dateSugar:
            return "Date Sugar"
        case .molasses:
            return "Molasses"
        case .corn_syrup:
            return "Corn Syrup"
        case .rice_syrup:
            return "Rice Syrup"
        }
    }
    
    /// Returns the category of sugar (natural, processed, artificial)
    var category: SugarCategory {
        switch self {
        case .glucose, .fructose, .lactose, .galactose, .ribose:
            return .natural
        case .honeyMaple, .agave, .coconutSugar, .dateSugar, .molasses:
            return .naturalSweetener
        case .sucrose, .maltose, .brownSugar, .dextrose, .xylose:
            return .processed
        case .highFructoseCornSyrup, .corn_syrup, .rice_syrup:
            return .highlyProcessed
        case .artificialSweetener:
            return .artificial
        case .sugarAlcohol:
            return .sugarAlcohol
        }
    }
    
    /// Returns health impact level
    var healthImpact: HealthImpact {
        switch category {
        case .natural:
            return .low
        case .naturalSweetener:
            return .medium
        case .processed:
            return .medium
        case .highlyProcessed:
            return .high
        case .artificial, .sugarAlcohol:
            return .low
        }
    }
}

/// Categories for different types of sugars
enum SugarCategory: String, CaseIterable, Codable {
    case natural = "natural"
    case naturalSweetener = "natural_sweetener"
    case processed = "processed"
    case highlyProcessed = "highly_processed"
    case artificial = "artificial"
    case sugarAlcohol = "sugar_alcohol"
    
    var displayName: String {
        switch self {
        case .natural:
            return "Natural Sugar"
        case .naturalSweetener:
            return "Natural Sweetener"
        case .processed:
            return "Processed Sugar"
        case .highlyProcessed:
            return "Highly Processed"
        case .artificial:
            return "Artificial Sweetener"
        case .sugarAlcohol:
            return "Sugar Alcohol"
        }
    }
}

/// Health impact levels for sugar types
enum HealthImpact: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low Impact"
        case .medium:
            return "Medium Impact"
        case .high:
            return "High Impact"
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
        }
    }
}

// MARK: - Extensions

extension AIResponse {
    /// Creates a sample AI response for testing and SwiftUI previews
    static let sample = AIResponse(
        requestId: "req_123456789",
        ingredientsAnalyzed: "Sugar, palm oil, hazelnuts (13%), skimmed milk powder (8.7%), fat-reduced cocoa (7.4%), emulsifier lecithins (soya), vanillin.",
        processingTime: 1250.0,
        createdAt: Date(),
        containsSugar: true,
        sugarTypes: [
            SugarTypeDetection(
                type: .sucrose,
                confidence: 0.95,
                sources: ["Sugar"],
                description: "Primary sweetening ingredient"
            ),
            SugarTypeDetection(
                type: .lactose,
                confidence: 0.78,
                sources: ["skimmed milk powder"],
                description: "From dairy ingredients"
            ),
            SugarTypeDetection(
                type: .fructose,
                confidence: 0.65,
                sources: ["hazelnuts"],
                description: "Natural sugars from nuts"
            )
        ],
        sugarAnalysis: .sample,
        confidence: 0.89,
        warnings: ["High sugar content detected"],
        recommendations: [
            "Consider limiting portion size due to high sugar content",
            "Look for alternatives with lower sugar content"
        ]
    )
    
    /// Creates a no-sugar sample for testing
    static let noSugarSample = AIResponse(
        requestId: "req_987654321",
        ingredientsAnalyzed: "Water, salt, vinegar, herbs, spices",
        processingTime: 890.0,
        createdAt: Date(),
        containsSugar: false,
        sugarTypes: [],
        sugarAnalysis: .noSugarSample,
        confidence: 0.92,
        warnings: [],
        recommendations: ["This product appears to be sugar-free"]
    )
    
    /// Creates a low confidence sample for testing uncertain results
    static let lowConfidenceSample = AIResponse(
        requestId: "req_555666777",
        ingredientsAnalyzed: "Natural flavors, citric acid, preservatives",
        processingTime: 2100.0,
        createdAt: Date(),
        containsSugar: false,
        sugarTypes: [],
        sugarAnalysis: .uncertainSample,
        confidence: 0.45,
        warnings: [
            "Low confidence in analysis",
            "Ingredient list may be incomplete or unclear"
        ],
        recommendations: [
            "Check nutrition facts for sugar content",
            "Consider scanning the ingredients again for better results"
        ]
    )
}