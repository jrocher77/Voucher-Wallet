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
        "Fnac / Darty": "#E1A925",
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
        "Printemps": "#BE1E2D",
        "King Jouet": "#E30613",
        "King jouet": "#E30613",
        "La Grande Recre": "#00AEEF",
        "Cultura": "#2B2B2B",
        "Leroy Merlin": "#78BE20",
        "Castorama": "#0078D7",
        "Bricorama": "#E30613",
        "BUT": "#E30613",
        "Conforama": "#E30613",
        "Maisons du Monde": "#000000",
        "Monoprix": "#E2007A",
        "Intermarche": "#E30613",
        "Super U": "#003DA5",
        "Hyper U": "#003DA5",
        "U Express": "#003DA5",
        "Lidl": "#0050AA",
        "Aldi": "#00539F",
        "Casino": "#E30613",
        "Picard": "#0072CE",
        "Biocoop": "#6BA539",
        "Kiabi": "#0066CC",
        "Nocibe": "#000000",
        "Yves Rocher": "#0B5D1E",
        "Nature et Decouvertes": "#5A7D2B",
        "Go Sport": "#E30613",
        "Orange": "#FF7900",
        "Action": "#0055A5",
        "Primark": "#0057B8",
        "Nike": "#111111",
        "Adidas": "#000000",
        "Apple Store": "#000000",
        "Micromania": "#0055A5",
        "Nintendo eShop": "#E60012",
        "PlayStation Store": "#003791",
        "Xbox": "#107C10",
        "Steam": "#1B2838",
        "Netflix": "#E50914",
        "Spotify": "#1DB954",
        "Google Play": "#01875F",
        "Pathé": "#FFD100",
        "Pathe": "#FFD100"
    ]
    
    /// Couleurs de texte par défaut pour les enseignes connues
    /// Chaque enseigne de `presets` a une couleur de texte explicite.
    static let textPresets: [String: String] = [
        "Carrefour": "#EAF3FF",
        "Decathlon": "#E6F5FF",
        "Fnac": "#000000",
        "Fnac / Darty": "#000000",
        "Ikea": "#0058A3",
        "Amazon": "#131A22",
        "Auchan": "#FFF2F2",
        "Leclerc": "#EAF4FF",
        "Boulanger": "#FFF1F2",
        "Darty": "#FFF1F3",
        "Intersport": "#EAF4FF",
        "H&M": "#FFEFF1",
        "Zara": "#F5F5F5",
        "Sephora": "#F2F2F2",
        "Galeries Lafayette": "#FAFAFA",
        "Printemps": "#FFF0F3",
        "King Jouet": "#FFF1F2",
        "La Grande Recre": "#003B73",
        "Cultura": "#F3EFEA",
        "Leroy Merlin": "#17340A",
        "Castorama": "#E9F4FF",
        "Bricorama": "#FFF1F2",
        "BUT": "#FFF4F4",
        "Conforama": "#FFF1F2",
        "Maisons du Monde": "#F3F3F0",
        "Monoprix": "#FFF0F8",
        "Intermarche": "#FFF1F2",
        "Super U": "#EAF1FF",
        "Hyper U": "#EAF1FF",
        "U Express": "#EAF1FF",
        "Orange": "#1A1A1A",
        "Lidl": "#FFED00",
        "Aldi": "#EAF3FF",
        "Casino": "#FFF1F2",
        "Picard": "#EAF4FF",
        "Biocoop": "#17310B",
        "Kiabi": "#EAF3FF",
        "Nocibe": "#F5F0FF",
        "Yves Rocher": "#EAF7E6",
        "Nature et Decouvertes": "#F3F8E7",
        "Go Sport": "#FFF1F2",
        "Action": "#FFD200",
        "Primark": "#EAF2FF",
        "Nike": "#F2F2F2",
        "Adidas": "#F2F2F2",
        "Apple Store": "#F5F5F7",
        "Micromania": "#F9F300",
        "Nintendo eShop": "#FFF2F2",
        "PlayStation Store": "#EAF0FF",
        "Xbox": "#EAF7EE",
        "Steam": "#66C0F4",
        "Netflix": "#FFF2F2",
        "Spotify": "#0B1F14",
        "Google Play": "#E8FFF7",
        "Pathé": "#1A1A1A",
        "Pathe": "#1A1A1A"
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
    
    static func getTextColor(for storeName: String, backgroundHex: String) -> String {
        // Recherche exacte dans les presets texte
        if let textColor = textPresets[storeName] {
            return textColor
        }
        
        // Recherche partielle (si le nom contient l'enseigne)
        for (preset, textColor) in textPresets {
            if storeName.localizedCaseInsensitiveContains(preset) {
                return textColor
            }
        }
        
        // Fallback: suggestion automatique basée sur la couleur de fond
        return StoreNameLearning.shared.suggestTextColor(for: backgroundHex)
    }
}
