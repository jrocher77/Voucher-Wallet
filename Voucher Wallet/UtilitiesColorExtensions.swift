//
//  ColorExtensions.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//

import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// Initialise une couleur à partir d'un code hexadécimal
    /// - Parameter hex: Code couleur au format "#RRGGBB" ou "RRGGBB"
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
    
    /// Convertit une couleur en code hexadécimal
    /// - Returns: Code couleur au format "#RRGGBB"
    func toHex() -> String {
        guard let components = UIColor(self).cgColor.components else {
            return "#007AFF"
        }
        
        let r = components[0]
        let g = components[1]
        let b = components[2]
        
        return String(
            format: "#%02X%02X%02X",
            Int(r * 255),
            Int(g * 255),
            Int(b * 255)
        )
    }
}

// MARK: - Color Presets

struct ColorPreset: Identifiable {
    let id = UUID()
    let name: String
    let hex: String
}

struct ColorPresets {
    static let allPresets: [ColorPreset] = [
        // Couleurs classiques
        ColorPreset(name: "Bleu", hex: "#007AFF"),
        ColorPreset(name: "Rouge", hex: "#FF3B30"),
        ColorPreset(name: "Vert", hex: "#34C759"),
        ColorPreset(name: "Orange", hex: "#FF9500"),
        ColorPreset(name: "Rose", hex: "#FF2D55"),
        ColorPreset(name: "Violet", hex: "#AF52DE"),
        ColorPreset(name: "Jaune", hex: "#FFCC00"),
        ColorPreset(name: "Cyan", hex: "#5AC8FA"),
        
        // Couleurs d'enseignes populaires
        ColorPreset(name: "Carrefour", hex: "#0055A5"),
        ColorPreset(name: "Decathlon", hex: "#0082C3"),
        ColorPreset(name: "Fnac", hex: "#E1A925"),
        ColorPreset(name: "Amazon", hex: "#FF9900"),
        ColorPreset(name: "Ikea", hex: "#FFDB00"),
        ColorPreset(name: "Auchan", hex: "#ED1C24"),
        ColorPreset(name: "Leclerc", hex: "#005AA9"),
        ColorPreset(name: "Boulanger", hex: "#E30613"),
        ColorPreset(name: "Darty", hex: "#E2001A"),
        ColorPreset(name: "Intersport", hex: "#0066B3"),
        ColorPreset(name: "H&M", hex: "#E50000"),
        ColorPreset(name: "Sephora", hex: "#000000"),
        
        // Couleurs neutres
        ColorPreset(name: "Gris", hex: "#8E8E93"),
        ColorPreset(name: "Noir", hex: "#000000"),
        ColorPreset(name: "Indigo", hex: "#5856D6"),
        ColorPreset(name: "Marron", hex: "#A2845E")
    ]
}
