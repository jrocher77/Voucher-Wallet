//
//  VoucherCardView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import CoreData

struct VoucherCardItem {
    let storeName: String
    let voucherNumber: String
    let amount: Double?
    let remainingBalance: Double
    let totalExpenses: Double
    let expirationDate: Date?
    let storeColor: String
    let textColor: String
    let isFavorite: Bool
    let isReceivedShare: Bool
    let isInActiveShare: Bool

    init(
        storeName: String,
        voucherNumber: String,
        amount: Double?,
        remainingBalance: Double,
        totalExpenses: Double,
        expirationDate: Date?,
        storeColor: String,
        textColor: String,
        isFavorite: Bool,
        isReceivedShare: Bool,
        isInActiveShare: Bool
    ) {
        self.storeName = storeName
        self.voucherNumber = voucherNumber
        self.amount = amount
        self.remainingBalance = remainingBalance
        self.totalExpenses = totalExpenses
        self.expirationDate = expirationDate
        self.storeColor = storeColor
        self.textColor = textColor
        self.isFavorite = isFavorite
        self.isReceivedShare = isReceivedShare
        self.isInActiveShare = isInActiveShare
    }

    init(voucher: Voucher) {
        self.storeName = voucher.storeName
        self.voucherNumber = voucher.voucherNumber
        self.amount = voucher.amount
        self.remainingBalance = voucher.remainingBalance
        self.totalExpenses = voucher.totalExpenses
        self.expirationDate = voucher.expirationDate
        self.storeColor = voucher.storeColor
        self.textColor = voucher.textColor
        self.isFavorite = voucher.isFavorite
        self.isReceivedShare = voucher.isReceivedShare
        self.isInActiveShare = voucher.isInActiveShare
    }
}

struct VoucherCardView: View {
    let item: VoucherCardItem
    var showsFavoriteIcon: Bool = true

    init(voucher: Voucher, showsFavoriteIcon: Bool = true) {
        self.item = VoucherCardItem(voucher: voucher)
        self.showsFavoriteIcon = showsFavoriteIcon
    }

    init(item: VoucherCardItem, showsFavoriteIcon: Bool = true) {
        self.item = item
        self.showsFavoriteIcon = showsFavoriteIcon
    }
    
    // Couleur du texte à utiliser
    private var textColor: Color {
        Color(hex: item.textColor)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // En-tête avec nom de l'enseigne
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Spacer()
                    .frame(width: 28)
                
                HStack(spacing: 6) {
                    Text(item.storeName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(textColor)
                        .lineLimit(1)

                    if item.isInActiveShare {
                        Image(systemName: item.isReceivedShare ? "person.badge.shield.checkmark.fill" : "person.2.fill")
                            .font(.caption)
                            .foregroundStyle(textColor.opacity(0.95))
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                }
                
                Spacer()
                
                if let amount = item.amount {
                    // Montants alignés à droite sans clipping du montant initial
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(item.remainingBalance.formattedEuro)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(textColor)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        
                        if item.totalExpenses > 0 {
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
                Text(item.voucherNumber)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(textColor)
            }
            
            // Date d'expiration
            if let expiration = item.expirationDate {
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
                .fill(Color(hex: item.storeColor))
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
        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: item.isFavorite)
    }
    
    private var favoriteIcon: some View {
        Image(systemName: item.isFavorite ? "star.fill" : "star")
            .font(.title2)
            .foregroundStyle(item.isFavorite ? .yellow : textColor.opacity(0.9))
            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            .symbolEffect(.bounce, value: item.isFavorite)
    }
    
}

#Preview {
    VStack(spacing: 20) {
        // Carte normale
        VoucherCardView(voucher: Voucher(
            context: PreviewData.shared.container.viewContext,
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
                context: PreviewData.shared.container.viewContext,
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
