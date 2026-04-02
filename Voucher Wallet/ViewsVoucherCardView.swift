//
//  VoucherCardView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI

struct VoucherCardView: View {
    let voucher: Voucher
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec nom de l'enseigne
            HStack {
                Text(voucher.storeName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
                Spacer()
                
                if let amount = voucher.amount {
                    Text(amount, format: .currency(code: "EUR"))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            
            Spacer()
            
            // Numéro du bon
            VStack(alignment: .leading, spacing: 4) {
                Text("Numéro")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
                Text(voucher.voucherNumber)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.white)
            }
            
            // Code PIN si disponible
            if let pin = voucher.pinCode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Code PIN")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(pin)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            
            // Date d'expiration
            if let expiration = voucher.expirationDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("Expire le \(expiration, format: .dateTime.day().month().year())")
                        .font(.caption)
                }
                .foregroundStyle(.white.opacity(0.9))
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

// Extension pour convertir hex en Color
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
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
        storeColor: "#0055A5"
    ))
    .padding()
}
