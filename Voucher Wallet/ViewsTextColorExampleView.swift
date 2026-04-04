//
//  TextColorExampleView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 04/04/2026.
//
//  Vue de démonstration pour tester la fonctionnalité de couleur de texte
//

import SwiftUI

/// Vue de démonstration montrant différentes combinaisons de couleurs texte/fond
struct TextColorExampleView: View {
    
    // Exemples de combinaisons
    private let examples: [(name: String, bg: String, text: String, desc: String)] = [
        // ✅ Bonnes combinaisons
        ("Carrefour", "#0055A5", "#FFFFFF", "✅ Excellent contraste"),
        ("Fnac", "#FFD700", "#000000", "✅ Excellent contraste"),
        ("Auchan", "#E30613", "#FFFFFF", "✅ Excellent contraste"),
        ("Décathlon", "#0082C3", "#FFFFFF", "✅ Excellent contraste"),
        
        // ⚠️ Contrastes moyens
        ("Exemple 1", "#FF6B6B", "#FFFFFF", "⚠️ Contraste moyen"),
        ("Exemple 2", "#95E1D3", "#000000", "⚠️ Contraste moyen"),
        
        // ❌ Mauvaises combinaisons (pour démonstration)
        ("Mauvais 1", "#FFFFFF", "#FFFFFF", "❌ Contraste nul"),
        ("Mauvais 2", "#FFFF00", "#FFFFFF", "❌ Contraste faible"),
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // En-tête
                    headerSection
                    
                    // Exemples de cartes
                    ForEach(examples, id: \.name) { example in
                        exampleCard(
                            storeName: example.name,
                            backgroundColor: example.bg,
                            textColor: example.text,
                            description: example.desc
                        )
                    }
                    
                    // Guide de contraste
                    contrastGuideSection
                }
                .padding()
            }
            .navigationTitle("Exemples de Couleurs")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "paintpalette.fill")
                .font(.system(size: 50))
                .foregroundStyle(.blue)
            
            Text("Combinaisons de Couleurs")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Exemples de cartes avec différentes combinaisons de couleurs texte/fond")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Example Card
    
    private func exampleCard(storeName: String, backgroundColor: String, textColor: String, description: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Carte simulée
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(storeName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: textColor))
                    
                    Spacer()
                    
                    Text("50,00 €")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: textColor))
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Numéro")
                        .font(.caption)
                        .foregroundStyle(Color(hex: textColor).opacity(0.8))
                    Text("1234567890123")
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(Color(hex: textColor))
                }
                
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Expire le 31 décembre 2026")
                        .font(.caption)
                }
                .foregroundStyle(Color(hex: textColor).opacity(0.9))
            }
            .padding(20)
            .frame(height: 180)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: backgroundColor))
                    .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
            )
            
            // Description et statistiques
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(description)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack(spacing: 12) {
                        colorInfo("Fond", hex: backgroundColor)
                        colorInfo("Texte", hex: textColor)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    
                    contrastInfo(background: backgroundColor, foreground: textColor)
                }
                
                Spacer()
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Color Info
    
    private func colorInfo(_ label: String, hex: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: hex))
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                }
            
            Text("\(label): \(hex)")
        }
    }
    
    // MARK: - Contrast Info
    
    private func contrastInfo(background: String, foreground: String) -> some View {
        let ratio = calculateContrastRatio(background: background, foreground: foreground)
        let (icon, color) = contrastStyle(ratio: ratio)
        
        return HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text("Ratio de contraste: \(String(format: "%.2f", ratio)):1")
        }
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
    
    // MARK: - Contrast Guide Section
    
    private var contrastGuideSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Guide de Contraste WCAG")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                guideRow(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    title: "Excellent (≥ 7:1)",
                    description: "WCAG AAA - Optimal pour tous les utilisateurs"
                )
                
                guideRow(
                    icon: "checkmark.circle",
                    color: .blue,
                    title: "Bon (≥ 4.5:1)",
                    description: "WCAG AA - Recommandé pour le texte normal"
                )
                
                guideRow(
                    icon: "exclamationmark.triangle",
                    color: .orange,
                    title: "Acceptable (≥ 3:1)",
                    description: "WCAG A - Minimum pour le texte large"
                )
                
                guideRow(
                    icon: "xmark.circle",
                    color: .red,
                    title: "Insuffisant (< 3:1)",
                    description: "Non conforme - À éviter"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    private func guideRow(icon: String, color: Color, title: String, description: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Utilities
    
    private func calculateContrastRatio(background: String, foreground: String) -> Double {
        let bgLuminance = calculateLuminance(hex: background)
        let fgLuminance = calculateLuminance(hex: foreground)
        
        let lighter = max(bgLuminance, fgLuminance)
        let darker = min(bgLuminance, fgLuminance)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
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
    
    private func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF)
        let g = Double((int >> 8) & 0xFF)
        let b = Double(int & 0xFF)
        return (r, g, b)
    }
    
    private func contrastStyle(ratio: Double) -> (String, Color) {
        switch ratio {
        case 7...:
            return ("checkmark.circle.fill", .green)
        case 4.5..<7:
            return ("checkmark.circle", .blue)
        case 3..<4.5:
            return ("exclamationmark.triangle", .orange)
        default:
            return ("xmark.circle", .red)
        }
    }
}

// MARK: - Preview

#Preview("Exemples de Couleurs") {
    TextColorExampleView()
}

#Preview("Carte Carrefour") {
    VStack {
        TextColorExampleView()
            .frame(height: 300)
    }
}
