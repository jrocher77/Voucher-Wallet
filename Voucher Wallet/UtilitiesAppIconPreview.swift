//
//  AppIconPreview.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI

/// Vue pour prévisualiser le design de l'icône de l'app
struct AppIconPreview: View {
    var body: some View {
        ZStack {
            // Fond dégradé bleu iOS
            LinearGradient(
                colors: [Color(hex: "#007AFF"), Color(hex: "#0051D5")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Carte blanche centrale
            RoundedRectangle(cornerRadius: 40)
                .fill(.white)
                .frame(width: 600, height: 400)
                .shadow(color: .black.opacity(0.2), radius: 40, x: 0, y: 20)
            
            // Code-barres stylisé
            HStack(spacing: 20) {
                barcodeBar(width: 40)
                barcodeBar(width: 60)
                barcodeBar(width: 40)
                barcodeBar(width: 60)
                barcodeBar(width: 40)
            }
            
            // Reflet subtil (optionnel, rend l'icône plus premium)
            LinearGradient(
                colors: [.white.opacity(0.3), .clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .frame(width: 1024, height: 512)
            .offset(y: -256)
            .blendMode(.overlay)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 200))
    }
    
    private func barcodeBar(width: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.black)
            .frame(width: width, height: 150)
    }
}

/// Vue alternative : Design minimaliste
struct AppIconPreviewMinimal: View {
    var body: some View {
        ZStack {
            // Fond bleu uni
            Color(hex: "#007AFF")
            
            // Code-barres simple et grand
            VStack(spacing: 40) {
                // Symbole de carte
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 200))
                    .foregroundStyle(.white.opacity(0.3))
                
                // Code-barres
                HStack(spacing: 30) {
                    ForEach(0..<6) { index in
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white)
                            .frame(width: index % 2 == 0 ? 50 : 70, height: 200)
                    }
                }
            }
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 200))
    }
}

/// Vue alternative : Design avec wallet empilé
struct AppIconPreviewStacked: View {
    var body: some View {
        ZStack {
            // Fond dégradé
            LinearGradient(
                colors: [Color(hex: "#5856D6"), Color(hex: "#3C3B94")],
                startPoint: .top,
                endPoint: .bottom
            )
            
            VStack(spacing: -80) {
                // Cartes empilées
                ForEach(0..<3) { index in
                    cardLayer(offset: CGFloat(index * 60), opacity: 1.0 - Double(index) * 0.15)
                }
            }
            .offset(y: -50)
        }
        .frame(width: 1024, height: 1024)
        .clipShape(RoundedRectangle(cornerRadius: 200))
    }
    
    private func cardLayer(offset: CGFloat, opacity: Double) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 50)
                .fill(.white.opacity(opacity))
                .frame(width: 700, height: 450)
                .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 10)
            
            // Code-barres sur la carte du dessus (index 0)
            if offset == 0 {
                HStack(spacing: 25) {
                    ForEach(0..<5) { i in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.black)
                            .frame(width: i % 2 == 0 ? 50 : 70, height: 180)
                    }
                }
            }
        }
        .offset(y: offset)
        .rotationEffect(.degrees(Double(offset) * 0.1))
    }
}

#Preview("Design Principal") {
    AppIconPreview()
}

#Preview("Design Minimal") {
    AppIconPreviewMinimal()
}

#Preview("Design Empilé") {
    AppIconPreviewStacked()
}

#Preview("Comparaison") {
    HStack(spacing: 50) {
        VStack {
            AppIconPreview()
                .frame(width: 300, height: 300)
                .shadow(radius: 10)
            Text("Principal")
                .font(.caption)
        }
        
        VStack {
            AppIconPreviewMinimal()
                .frame(width: 300, height: 300)
                .shadow(radius: 10)
            Text("Minimal")
                .font(.caption)
        }
        
        VStack {
            AppIconPreviewStacked()
                .frame(width: 300, height: 300)
                .shadow(radius: 10)
            Text("Empilé")
                .font(.caption)
        }
    }
    .padding(50)
}
