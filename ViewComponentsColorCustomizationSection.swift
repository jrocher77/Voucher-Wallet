//
//  ColorCustomizationSection.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI

/// Section de personnalisation des couleurs de carte réutilisable
struct ColorCustomizationSection: View {
    @Binding var cardColor: Color
    @Binding var textColor: Color
    
    let previewStoreName: String
    let previewVoucherNumber: String
    let previewAmount: String?
    let showPopularColors: Bool
    
    init(
        cardColor: Binding<Color>,
        textColor: Binding<Color>,
        previewStoreName: String = "Enseigne exemple",
        previewVoucherNumber: String = "1234567890",
        previewAmount: String? = "50,00 €",
        showPopularColors: Bool = true
    ) {
        self._cardColor = cardColor
        self._textColor = textColor
        self.previewStoreName = previewStoreName
        self.previewVoucherNumber = previewVoucherNumber
        self.previewAmount = previewAmount
        self.showPopularColors = showPopularColors
    }
    
    var body: some View {
        Group {
            // Sélecteurs de couleurs
            ColorPicker("Couleur de fond", selection: $cardColor, supportsOpacity: false)
                .onChange(of: cardColor) { oldValue, newValue in
                    autoAdjustTextColor(for: newValue)
                }
            
            ColorPicker("Couleur du texte", selection: $textColor, supportsOpacity: false)
            
            // Avertissements de contraste
            contrastWarnings
            
            // Prévisualisation
            previewCard
            
            // Préréglages de couleurs
            if showPopularColors {
                backgroundColorPresets
                textColorPresets
            }
        }
    }
    
    // MARK: - Sous-vues
    
    @ViewBuilder
    private var contrastWarnings: some View {
        if ColorContrastHelper.areColorsTooSimilar(cardColor, textColor) {
            Label {
                Text("⚠️ Les couleurs sont identiques ou trop similaires. Le texte sera illisible.")
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
            }
            .font(.caption)
            .foregroundStyle(.red)
        } else {
            Label {
                Text("Bon contraste pour la lisibilité")
            } icon: {
                Image(systemName: "checkmark.circle.fill")
            }
            .font(.caption)
            .foregroundStyle(.green)
        }
    }
    
    private var previewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Aperçu")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(previewStoreName)
                        .font(.headline)
                        .foregroundStyle(textColor)
                    
                    Text(previewVoucherNumber)
                        .font(.caption)
                        .foregroundStyle(textColor.opacity(0.8))
                }
                Spacer()
                if let amount = previewAmount {
                    Text(amount)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(cardColor)
            )
        }
    }
    
    private var backgroundColorPresets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couleurs de fond populaires")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ColorPresets.allPresets, id: \.hex) { preset in
                        Button {
                            cardColor = Color(hex: preset.hex)
                            // Suggestion automatique de couleur de texte
                            let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: preset.hex)
                            textColor = Color(hex: suggestedTextColor)
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: preset.hex))
                                    .frame(width: 44, height: 44)
                                    .overlay {
                                        if cardColor.isSimilar(to: Color(hex: preset.hex)) {
                                            Circle()
                                                .stroke(Color.primary, lineWidth: 3)
                                        }
                                    }
                                
                                Text(preset.name)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }
    
    private var textColorPresets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Couleurs de texte populaires")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                ForEach([
                    ("Blanc", "#FFFFFF"),
                    ("Noir", "#000000"),
                    ("Gris clair", "#E5E5EA"),
                    ("Gris foncé", "#3A3A3C")
                ], id: \.1) { preset in
                    Button {
                        textColor = Color(hex: preset.1)
                    } label: {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: preset.1))
                                .frame(width: 40, height: 40)
                                .overlay {
                                    Circle()
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                    if textColor.isSimilar(to: Color(hex: preset.1)) {
                                        Circle()
                                            .stroke(Color.primary, lineWidth: 3)
                                    }
                                }
                            
                            Text(preset.0)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private func autoAdjustTextColor(for backgroundColor: Color) {
        if ColorContrastHelper.areColorsTooSimilar(backgroundColor, textColor) {
            let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: backgroundColor.toHex())
            textColor = Color(hex: suggestedTextColor)
        }
    }
}

#Preview {
    Form {
        Section("Personnalisation") {
            ColorCustomizationSection(
                cardColor: .constant(Color(hex: "#007AFF")),
                textColor: .constant(.white)
            )
        }
    }
}
