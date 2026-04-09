//
//  ConfidenceBadge.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI

/// Badge visuel affichant le score de confiance de la détection
struct ConfidenceBadge: View {
    let confidence: Double
    
    private var percentage: Int {
        Int(confidence * 100)
    }
    
    private var style: (color: Color, icon: String) {
        switch confidence {
        case 0.8...1.0:
            return (.green, "checkmark.circle.fill")
        case 0.6..<0.8:
            return (.blue, "checkmark.circle")
        case 0.4..<0.6:
            return (.orange, "exclamationmark.circle")
        default:
            return (.red, "questionmark.circle")
        }
    }
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: style.icon)
                .font(.system(size: 10))
            Text("Confiance \(percentage)%")
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(style.color.opacity(0.15))
        .foregroundColor(style.color)
        .clipShape(Capsule())
    }
}

#Preview {
    VStack(spacing: 12) {
        ConfidenceBadge(confidence: 0.95)
        ConfidenceBadge(confidence: 0.75)
        ConfidenceBadge(confidence: 0.55)
        ConfidenceBadge(confidence: 0.25)
    }
    .padding()
}
