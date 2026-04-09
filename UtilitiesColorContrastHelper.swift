//
//  ColorContrastHelper.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI

/// Utilitaire pour calculer le contraste entre les couleurs et assurer la lisibilité
struct ColorContrastHelper {
    
    /// Vérifie si deux couleurs sont trop similaires pour une bonne lisibilité
    /// - Parameters:
    ///   - color1: Première couleur
    ///   - color2: Deuxième couleur
    /// - Returns: `true` si le contraste est insuffisant (< 3:1)
    static func areColorsTooSimilar(_ color1: Color, _ color2: Color) -> Bool {
        let hex1 = color1.toHex()
        let hex2 = color2.toHex()
        
        // Comparaison exacte
        if hex1 == hex2 {
            return true
        }
        
        // Calcul du ratio de contraste
        let luminance1 = calculateLuminance(hex: hex1)
        let luminance2 = calculateLuminance(hex: hex2)
        
        let contrastRatio = max(luminance1, luminance2) / min(luminance1, luminance2)
        
        // Un ratio de contraste < 3:1 est considéré comme insuffisant selon WCAG
        return contrastRatio < 3.0
    }
    
    /// Calcule la luminosité relative d'une couleur selon la formule W3C
    /// - Parameter hex: Code hexadécimal de la couleur
    /// - Returns: Valeur de luminance entre 0 et 1
    static func calculateLuminance(hex: String) -> Double {
        let rgb = hexToRGB(hex)
        
        let r = rgb.r / 255.0
        let g = rgb.g / 255.0
        let b = rgb.b / 255.0
        
        // Conversion sRGB vers valeurs linéaires
        let rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        // Calcul de la luminance relative
        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
    }
    
    /// Convertit une couleur hexadécimale en composantes RGB
    /// - Parameter hex: Code hexadécimal de la couleur
    /// - Returns: Tuple contenant les valeurs R, G, B (0-255)
    static func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let r = Double((int >> 16) & 0xFF)
        let g = Double((int >> 8) & 0xFF)
        let b = Double(int & 0xFF)
        
        return (r, g, b)
    }
    
    /// Calcule le ratio de contraste entre deux couleurs
    /// - Parameters:
    ///   - color1: Première couleur
    ///   - color2: Deuxième couleur
    /// - Returns: Ratio de contraste (1:1 à 21:1)
    static func contrastRatio(between color1: Color, and color2: Color) -> Double {
        let luminance1 = calculateLuminance(hex: color1.toHex())
        let luminance2 = calculateLuminance(hex: color2.toHex())
        
        let lighter = max(luminance1, luminance2)
        let darker = min(luminance1, luminance2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    /// Suggère automatiquement une couleur de texte (noir ou blanc) en fonction de la couleur de fond
    /// - Parameter backgroundColor: Couleur de fond
    /// - Returns: Couleur de texte recommandée (noir ou blanc)
    static func suggestTextColor(for backgroundColor: Color) -> Color {
        let luminance = calculateLuminance(hex: backgroundColor.toHex())
        
        // Si le fond est clair (luminance élevée), utiliser du texte noir
        // Sinon, utiliser du texte blanc
        return luminance > 0.5 ? .black : .white
    }
}
