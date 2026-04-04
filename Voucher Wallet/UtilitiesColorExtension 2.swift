//
//  ColorExtension.swift
//  Voucher Wallet
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
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
    
    /// Compare deux couleurs en comparant leurs codes hex normalisés
    /// - Parameter other: L'autre couleur à comparer
    /// - Returns: True si les couleurs sont identiques (ou très similaires)
    func isSimilar(to other: Color) -> Bool {
        let thisHex = self.toHex().uppercased()
        let otherHex = other.toHex().uppercased()
        return thisHex == otherHex
    }
}
