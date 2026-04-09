//
//  VoucherCardView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI

struct VoucherCardView: View {
    let voucher: Voucher
    
    // Couleur du texte à utiliser
    private var textColor: Color {
        Color(hex: voucher.textColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec nom de l'enseigne
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                // Espace pour l'étoile favori
                if voucher.isFavorite {
                    Spacer()
                        .frame(width: 28)
                }
                
                Text(voucher.storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(textColor)
                
                Spacer()
                
                if let amount = voucher.amount {
                    // Solde restant (principal) - aligné sur la baseline
                    Text(voucher.remainingBalance.formattedEuro)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(textColor)
                        .overlay(alignment: .bottom) {
                            // Montant initial (petit) en dessous
                            if voucher.totalExpenses > 0 {
                                Text("sur \(amount.formattedEuro)")
                                    .font(.caption2)
                                    .foregroundStyle(textColor.opacity(0.7))
                                    .offset(y: 14)
                            }
                        }
                }
            }
            .padding(.top, -8)
            
            Spacer()
            
            // Numéro du bon
            VStack(alignment: .leading, spacing: 4) {
                Text("Numéro")
                    .font(.caption)
                    .foregroundStyle(textColor.opacity(0.8))
                Text(voucher.voucherNumber)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(textColor)
            }
            
            // Code PIN si disponible
            if let pin = voucher.pinCode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Code PIN")
                        .font(.caption)
                        .foregroundStyle(textColor.opacity(0.8))
                    Text(pin)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(textColor)
                }
            }
            
            // Date d'expiration
            if let expiration = voucher.expirationDate {
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("Expire le \(expiration.frenchLongFormat)")
                        .font(.caption)
                }
                .foregroundStyle(textColor.opacity(0.9))
            }
        }
        .padding(20)
        .frame(height: 200)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: voucher.storeColor))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        )
        .overlay(alignment: .topLeading) {
            // Badge favori
            if voucher.isFavorite {
                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voucher.isFavorite)
    }
}

#Preview {
    VStack(spacing: 20) {
        // Carte normale
        VoucherCardView(voucher: Voucher(
            storeName: "Carrefour",
            amount: 50.0,
            voucherNumber: "1234567890123",
            pinCode: "5678",
            codeType: .barcode,
            expirationDate: Date().addingTimeInterval(86400 * 30),
            storeColor: "#0055A5",
            textColor: "#FFFFFF"
        ))
        
        // Carte favorite
        VoucherCardView(voucher: {
            let voucher = Voucher(
                storeName: "Fnac",
                amount: 100.0,
                voucherNumber: "9876543210987",
                pinCode: "1234",
                codeType: .qrCode,
                expirationDate: Date().addingTimeInterval(86400 * 60),
                storeColor: "#F39200",
                textColor: "#000000"
            )
            voucher.isFavorite = true
            return voucher
        }())
    }
    .padding()
}
