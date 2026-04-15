//
//  VoucherCardView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI

struct VoucherCardView: View {
    let voucher: Voucher
    var showsFavoriteIcon: Bool = true
    
    // Couleur du texte à utiliser
    private var textColor: Color {
        Color(hex: voucher.textColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec nom de l'enseigne
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Spacer()
                    .frame(width: 28)
                
                Text(voucher.storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(textColor)
                
                Spacer()
                
                if let amount = voucher.amount {
                    // Montants alignés à droite sans clipping du montant initial
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(voucher.remainingBalance.formattedEuro)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        if voucher.totalExpenses > 0 {
                            Text("sur \(amount.formattedEuro)")
                                .font(.caption2)
                                .foregroundStyle(textColor.opacity(0.7))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
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
            if showsFavoriteIcon {
                favoriteIcon
                    .padding(.leading, 12)
                    .padding(.top, 12)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: voucher.isFavorite)
    }
    
    private var favoriteIcon: some View {
        Image(systemName: voucher.isFavorite ? "star.fill" : "star")
            .font(.title2)
            .foregroundStyle(voucher.isFavorite ? .yellow : textColor.opacity(0.9))
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .symbolEffect(.bounce, value: voucher.isFavorite)
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
