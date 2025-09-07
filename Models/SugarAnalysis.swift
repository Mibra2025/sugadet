//
//  SugarAnalysis.swift
//  BarcodeScanner
//
//  Created by Claude on 9/7/25.
//

import Foundation

/// Detailed analysis of sugar content and types found in ingredients
struct SugarAnalysis: Codable, Hashable, Identifiable {
    let id = UUID()
    
    // MARK: - Sugar Detection Metrics
    let totalSugarIndicators: Int
    let hiddenSugars: [String]
    let sugarAlternatives: [String]
    let addedSugars: [String]
    let naturalSugars: [String]
    
    // MARK: - Health Assessment
    let healthImpact: HealthImpactLevel
    let sugarLoad: SugarLoad
    let glycemicImpact: GlycemicImpact
    
    // MARK: - Analysis Details
    let analysisDate: Date
    let ingredientCount: Int
    let sugarPercentageEstimate: Double?
    let confidenceScore: Double
    
    // MARK: - User Guidance
    let recommendations: [String]
    let warnings: [String]
    let alternatives: [String]
    
    // MARK: - Coding Keys
    enum CodingKeys: String, CodingKey {
        case totalSugarIndicators = "total_sugar_indicators"
        case hiddenSugars = "hidden_sugars"
        case sugarAlternatives = "sugar_alternatives"
        case addedSugars = "added_sugars"
        case naturalSugars = "natural_sugars"
        case healthImpact = "health_impact"
        case sugarLoad = "sugar_load"
        case glycemicImpact = "glycemic_impact"
        case analysisDate = "analysis_date"
        case ingredientCount = "ingredient_count"
        case sugarPercentageEstimate = "sugar_percentage_estimate"
        case confidenceScore = "confidence_score"
        case recommendations
        case warnings
        case alternatives
    }
    
    // MARK: - Computed Properties
    
    /// Returns true if any hidden sugars were detected
    var hasHiddenSugars: Bool {
        return !hiddenSugars.isEmpty
    }
    
    /// Returns true if sugar alternatives are present
    var hasSugarAlternatives: Bool {
        return !sugarAlternatives.isEmpty
    }
    
    /// Returns the total number of sugar-related ingredients
    var totalSugarIngredients: Int {
        return hiddenSugars.count + addedSugars.count + naturalSugars.count
    }
    
    /// Returns a summary of sugar types found
    var sugarTypeSummary: String {
        var components: [String] = []
        
        if !addedSugars.isEmpty {
            components.append("\(addedSugars.count) added sugar(s)")
        }
        
        if !naturalSugars.isEmpty {
            components.append("\(naturalSugars.count) natural sugar(s)")
        }
        
        if !hiddenSugars.isEmpty {
            components.append("\(hiddenSugars.count) hidden sugar(s)")
        }
        
        if !sugarAlternatives.isEmpty {
            components.append("\(sugarAlternatives.count) sugar alternative(s)")
        }
        
        return components.isEmpty ? "No sugars detected" : components.joined(separator: ", ")
    }
    
    /// Returns formatted sugar percentage estimate
    var sugarPercentageText: String? {
        guard let percentage = sugarPercentageEstimate else { return nil }
        return String(format: "~%.1f%% sugar content", percentage)
    }
    
    /// Returns the primary concern level based on analysis
    var primaryConcern: String {
        if hasHiddenSugars && addedSugars.count > 2 {
            return "High sugar content with hidden sugars detected"
        } else if addedSugars.count > 3 {
            return "Multiple added sugars detected"
        } else if hasHiddenSugars {
            return "Hidden sugars detected"
        } else if !addedSugars.isEmpty {
            return "Added sugars present"
        } else if !naturalSugars.isEmpty {
            return "Natural sugars present"
        } else {
            return "No significant sugar concerns"
        }
    }
    
    /// Returns recommendation priority level
    var recommendationPriority: RecommendationPriority {
        switch healthImpact {
        case .low:
            return naturalSugars.isEmpty ? .none : .low
        case .medium:
            return hasHiddenSugars ? .high : .medium
        case .high:
            return .high
        }
    }
}

// MARK: - Supporting Enums

/// Overall health impact assessment for sugar content
enum HealthImpactLevel: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low:
            return "Low Impact"
        case .medium:
            return "Moderate Impact"
        case .high:
            return "High Impact"
        }
    }
    
    var description: String {
        switch self {
        case .low:
            return "Minimal impact on blood sugar and health"
        case .medium:
            return "Moderate impact - consume in moderation"
        case .high:
            return "Significant impact - limit consumption"
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
    
    var icon: String {
        switch self {
        case .low:
            return "checkmark.circle.fill"
        case .medium:
            return "exclamationmark.triangle.fill"
        case .high:
            return "xmark.circle.fill"
        }
    }
}

/// Sugar load assessment based on quantity and type
enum SugarLoad: String, CaseIterable, Codable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .minimal:
            return "Minimal"
        case .low:
            return "Low"
        case .moderate:
            return "Moderate"
        case .high:
            return "High"
        case .veryHigh:
            return "Very High"
        }
    }
    
    var description: String {
        switch self {
        case .minimal:
            return "Very little sugar content"
        case .low:
            return "Low sugar content"
        case .moderate:
            return "Moderate sugar content"
        case .high:
            return "High sugar content"
        case .veryHigh:
            return "Very high sugar content"
        }
    }
    
    var severity: Int {
        switch self {
        case .minimal:
            return 1
        case .low:
            return 2
        case .moderate:
            return 3
        case .high:
            return 4
        case .veryHigh:
            return 5
        }
    }
}

/// Estimated glycemic impact of the sugars
enum GlycemicImpact: String, CaseIterable, Codable {
    case negligible = "negligible"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .negligible:
            return "Negligible"
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        }
    }
    
    var description: String {
        switch self {
        case .negligible:
            return "Minimal blood sugar impact"
        case .low:
            return "Low blood sugar impact"
        case .medium:
            return "Moderate blood sugar impact"
        case .high:
            return "Significant blood sugar impact"
        }
    }
    
    var estimatedGIRange: String {
        switch self {
        case .negligible:
            return "0-10"
        case .low:
            return "10-35"
        case .medium:
            return "35-55"
        case .high:
            return "55+"
        }
    }
}

/// Priority level for recommendations
enum RecommendationPriority: String, CaseIterable, Codable {
    case none = "none"
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .none:
            return "No Action Needed"
        case .low:
            return "Consider"
        case .medium:
            return "Recommended"
        case .high:
            return "Strongly Recommended"
        }
    }
}

// MARK: - Extensions

extension SugarAnalysis {
    /// Creates a sample sugar analysis for testing and SwiftUI previews
    static let sample = SugarAnalysis(
        totalSugarIndicators: 3,
        hiddenSugars: ["dextrose", "maltodextrin"],
        sugarAlternatives: [],
        addedSugars: ["sugar", "corn syrup"],
        naturalSugars: ["fruit juice concentrate"],
        healthImpact: .high,
        sugarLoad: .high,
        glycemicImpact: .high,
        analysisDate: Date(),
        ingredientCount: 15,
        sugarPercentageEstimate: 45.2,
        confidenceScore: 0.89,
        recommendations: [
            "Limit portion size due to high sugar content",
            "Look for alternatives with less added sugar",
            "Consider the timing of consumption around physical activity"
        ],
        warnings: [
            "Contains multiple types of added sugars",
            "High glycemic impact expected"
        ],
        alternatives: [
            "Look for unsweetened versions",
            "Choose products with natural sweeteners like stevia",
            "Consider making homemade alternatives"
        ]
    )
    
    /// Creates a no-sugar analysis sample
    static let noSugarSample = SugarAnalysis(
        totalSugarIndicators: 0,
        hiddenSugars: [],
        sugarAlternatives: ["stevia", "erythritol"],
        addedSugars: [],
        naturalSugars: [],
        healthImpact: .low,
        sugarLoad: .minimal,
        glycemicImpact: .negligible,
        analysisDate: Date(),
        ingredientCount: 8,
        sugarPercentageEstimate: 0.0,
        confidenceScore: 0.92,
        recommendations: [
            "This product appears to be sugar-free",
            "Good choice for low-sugar diet"
        ],
        warnings: [],
        alternatives: []
    )
    
    /// Creates a low-sugar natural sample
    static let naturalSugarSample = SugarAnalysis(
        totalSugarIndicators: 2,
        hiddenSugars: [],
        sugarAlternatives: [],
        addedSugars: [],
        naturalSugars: ["apple juice", "date paste"],
        healthImpact: .medium,
        sugarLoad: .low,
        glycemicImpact: .medium,
        analysisDate: Date(),
        ingredientCount: 12,
        sugarPercentageEstimate: 18.5,
        confidenceScore: 0.85,
        recommendations: [
            "Natural sugars present but at moderate levels",
            "Good choice compared to products with added sugars"
        ],
        warnings: [
            "Still contains natural sugars - consume in moderation"
        ],
        alternatives: [
            "Look for unsweetened versions for even lower sugar content"
        ]
    )
    
    /// Creates an uncertain analysis sample for low confidence results
    static let uncertainSample = SugarAnalysis(
        totalSugarIndicators: 1,
        hiddenSugars: [],
        sugarAlternatives: [],
        addedSugars: [],
        naturalSugars: [],
        healthImpact: .low,
        sugarLoad: .minimal,
        glycemicImpact: .low,
        analysisDate: Date(),
        ingredientCount: 5,
        sugarPercentageEstimate: nil,
        confidenceScore: 0.45,
        recommendations: [
            "Analysis confidence is low",
            "Check nutrition facts for accurate sugar content"
        ],
        warnings: [
            "Ingredient list may be incomplete or unclear",
            "Manual verification recommended"
        ],
        alternatives: [
            "Re-scan the ingredient list for better results",
            "Check the nutrition facts panel"
        ]
    )
}