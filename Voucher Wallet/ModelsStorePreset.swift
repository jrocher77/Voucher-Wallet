//
//  StorePreset.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation

/// Préréglages pour les enseignes connues avec leurs couleurs
struct StorePreset {
    let name: String
    let colorHex: String
    
    static let presets: [String: String] = [
        "Carrefour": "#0055A5",
        "Decathlon": "#0082C3",
        "Fnac": "#E1A925",
        "Amazon": "#FF9900",
        "Ikea": "#FFDB00",
        "Auchan": "#ED1C24",
        "Leclerc": "#005AA9",
        "Boulanger": "#E30613",
        "Darty": "#E2001A",
        "Intersport": "#0066B3",
        "H&M": "#E50000",
        "Zara": "#000000",
        "Sephora": "#000000",
        "Galeries Lafayette": "#000000",
        "Printemps": "#BE1E2D"
    ]
    
    static func getColor(for storeName: String) -> String {
        // 1. D'abord, vérifier si l'utilisateur a appris une préférence de couleur
        if let learnedColor = StoreNameLearning.shared.getLearnedColor(for: storeName) {
            return learnedColor
        }
        
        // 2. Recherche exacte dans les presets
        if let color = presets[storeName] {
            return color
        }
        
        // 3. Recherche partielle (si le nom contient l'enseigne)
        for (preset, color) in presets {
            if storeName.localizedCaseInsensitiveContains(preset) {
                return color
            }
        }
        
        // 4. Couleur par défaut
        return "#007AFF"
    }
}
