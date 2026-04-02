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
        // Recherche exacte
        if let color = presets[storeName] {
            return color
        }
        
        // Recherche partielle (si le nom contient l'enseigne)
        for (preset, color) in presets {
            if storeName.localizedCaseInsensitiveContains(preset) {
                return color
            }
        }
        
        // Couleur par défaut
        return "#007AFF"
    }
}
