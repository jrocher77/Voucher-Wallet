//
//  StoreNameLearning+TextColor.swift
//  Voucher Wallet
//
//  Created by JEREMY on 04/04/2026.
//

import Foundation

// MARK: - Extension pour la gestion des couleurs de texte

extension StoreNameLearning {
    
    // MARK: - UserDefaults Keys
    
    private static let textColorKey = "learnedTextColors"
    
    // MARK: - Text Color Learning
    
    /// Enregistre la préférence de couleur de texte pour une enseigne
    /// - Parameters:
    ///   - textColorHex: Couleur du texte au format hexadécimal (ex: "#FFFFFF")
    ///   - storeName: Nom de l'enseigne
    func learnTextColor(_ textColorHex: String, for storeName: String) {
        let key = storeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        var textColors = UserDefaults.standard.dictionary(forKey: Self.textColorKey) as? [String: String] ?? [:]
        textColors[key] = textColorHex
        UserDefaults.standard.set(textColors, forKey: Self.textColorKey)
        
        print("🎨 Couleur de texte apprise pour \(storeName): \(textColorHex)")
    }
    
    /// Récupère la couleur de texte apprise pour une enseigne
    /// - Parameter storeName: Nom de l'enseigne
    /// - Returns: Couleur hexadécimale apprise, ou nil si aucune n'est enregistrée
    func getLearnedTextColor(for storeName: String) -> String? {
        let key = storeName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let textColors = UserDefaults.standard.dictionary(forKey: Self.textColorKey) as? [String: String] ?? [:]
        return textColors[key]
    }
    
    /// Suggère automatiquement une couleur de texte appropriée basée sur la couleur de fond
    /// - Parameter backgroundColor: Couleur de fond au format hexadécimal
    /// - Returns: Couleur de texte suggérée ("#FFFFFF" pour blanc ou "#000000" pour noir)
    func suggestTextColor(for backgroundColor: String) -> String {
        // Calculer la luminosité de la couleur de fond
        let luminance = calculateLuminance(hex: backgroundColor)
        
        // Si la couleur de fond est claire (luminance > 0.5), utiliser du texte noir
        // Sinon, utiliser du texte blanc
        return luminance > 0.5 ? "#000000" : "#FFFFFF"
    }
    
    /// Calcule la luminosité relative d'une couleur (formule W3C)
    private func calculateLuminance(hex: String) -> Double {
        let rgb = hexToRGB(hex)
        
        let r = rgb.r / 255.0
        let g = rgb.g / 255.0
        let b = rgb.b / 255.0
        
        let rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
    }
    
    /// Convertit une couleur hex en RGB
    private func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF)
        g = Double((int >> 8) & 0xFF)
        b = Double(int & 0xFF)
        return (r, g, b)
    }
    
    /// Vérifie si deux couleurs ont un contraste suffisant pour la lisibilité
    /// - Parameters:
    ///   - foregroundHex: Couleur de premier plan (texte)
    ///   - backgroundHex: Couleur d'arrière-plan (fond)
    /// - Returns: true si le contraste est suffisant (ratio >= 3:1)
    func hasGoodContrast(foreground foregroundHex: String, background backgroundHex: String) -> Bool {
        let luminance1 = calculateLuminance(hex: foregroundHex)
        let luminance2 = calculateLuminance(hex: backgroundHex)
        
        let contrastRatio = max(luminance1, luminance2) / min(luminance1, luminance2)
        
        // Un ratio de 3:1 est le minimum pour un bon contraste
        // 4.5:1 est recommandé pour le texte normal (WCAG AA)
        // 7:1 est recommandé pour le texte amélioré (WCAG AAA)
        return contrastRatio >= 3.0
    }
    
}
