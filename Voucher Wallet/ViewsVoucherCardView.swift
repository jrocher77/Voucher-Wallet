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
            HStack {
                Text(voucher.storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(textColor)
                
                Spacer()
                
                if let amount = voucher.amount {
                    VStack(alignment: .trailing, spacing: 2) {
                        // Solde restant (principal)
                        Text(voucher.remainingBalance.formattedEuro)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(textColor)
                        
                        // Montant initial (petit)
                        if voucher.totalExpenses > 0 {
                            Text("sur \(amount.formattedEuro)")
                                .font(.caption2)
                                .foregroundStyle(textColor.opacity(0.7))
                        }
                    }
                }
            }
            
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
                    Image(systemName: "clock")
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
    }
}

#Preview {
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
    .padding()
}
