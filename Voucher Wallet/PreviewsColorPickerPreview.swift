//
//  ColorPickerPreview.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//
//  Fichier de preview pour tester le sélecteur de couleur

import SwiftUI

struct ColorPickerPreview: View {
    @State private var selectedColor = Color(hex: "#007AFF")
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Aperçu de la carte") {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(selectedColor)
                        .frame(height: 200)
                        .overlay {
                            VStack {
                                Text("Ma Carte")
                                    .font(.title)
                                    .fontWeight(.bold)
                                Text("50,00 €")
                                    .font(.title2)
                            }
                            .foregroundStyle(.white)
                        }
                        .shadow(radius: 10)
                }
                
                Section("Couleur de la carte") {
                    ColorPicker("Couleur", selection: $selectedColor, supportsOpacity: false)
                    
                    // Préréglages de couleurs populaires
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ColorPresets.allPresets, id: \.hex) { preset in
                                Button {
                                    selectedColor = Color(hex: preset.hex)
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: preset.hex))
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                if selectedColor.isSimilar(to: Color(hex: preset.hex)) {
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
                
                Section("Informations") {
                    HStack {
                        Text("Code hex")
                        Spacer()
                        Text(selectedColor.toHex())
                            .foregroundStyle(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Sélecteur de couleur")
        }
    }
}

#Preview {
    ColorPickerPreview()
}
