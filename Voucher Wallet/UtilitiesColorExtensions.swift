//
//  ColorExtensions.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//

import SwiftUI

// MARK: - Color Presets

struct ColorPreset {
    let name: String
    let hex: String
}

struct ColorPresets {
    static let allPresets: [ColorPreset] = [
        // Couleurs vives
        ColorPreset(name: "Bleu", hex: "#007AFF"),
        ColorPreset(name: "Rouge", hex: "#FF3B30"),
        ColorPreset(name: "Vert", hex: "#34C759"),
        ColorPreset(name: "Orange", hex: "#FF9500"),
        ColorPreset(name: "Rose", hex: "#FF2D55"),
        ColorPreset(name: "Violet", hex: "#AF52DE"),
        ColorPreset(name: "Jaune", hex: "#FFCC00"),
        ColorPreset(name: "Cyan", hex: "#5AC8FA"),
        ColorPreset(name: "Indigo", hex: "#5856D6"),
        
        // Couleurs foncées
        ColorPreset(name: "Bleu foncé", hex: "#0055A5"),
        ColorPreset(name: "Rouge foncé", hex: "#C41E3A"),
        ColorPreset(name: "Vert foncé", hex: "#228B22"),
        ColorPreset(name: "Orange foncé", hex: "#CC5500"),
        ColorPreset(name: "Violet foncé", hex: "#6A0DAD"),
        
        // Couleurs pastel
        ColorPreset(name: "Bleu pastel", hex: "#AEC6CF"),
        ColorPreset(name: "Rose pastel", hex: "#FFD1DC"),
        ColorPreset(name: "Vert pastel", hex: "#B4E7CE"),
        ColorPreset(name: "Jaune pastel", hex: "#FFFACD"),
        
        // Couleurs neutres
        ColorPreset(name: "Gris", hex: "#8E8E93"),
        ColorPreset(name: "Noir", hex: "#000000"),
        ColorPreset(name: "Marron", hex: "#A52A2A"),
        ColorPreset(name: "Or", hex: "#FFD700"),
        ColorPreset(name: "Argent", hex: "#C0C0C0")
    ]
}
