//
//  VoucherExtensions.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//
//  Extensions utiles pour les Vouchers et leur affichage dans les widgets

import Foundation
import SwiftUI

// MARK: - Extension Voucher pour les widgets

extension Voucher {
    
    /// Toggle le statut favori et recharge automatiquement les widgets
    func toggleFavoriteWithWidgetUpdate() {
        self.isFavorite.toggle()
        
        // Recharger immédiatement les widgets pour refléter le changement
        WidgetReloader.reloadFavoriteVouchersWidget()
        
        print("💫 Favori modifié pour \(storeName): \(isFavorite ? "✅" : "❌")")
    }
    
    /// Vérifie si le voucher expire bientôt (dans les 7 jours)
    var isExpiringSoon: Bool {
        guard let expirationDate else { return false }
        let daysUntilExpiration = Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day ?? 0
        return daysUntilExpiration >= 0 && daysUntilExpiration <= 7
    }
    
    /// Vérifie si le voucher est expiré
    var isExpired: Bool {
        guard let expirationDate else { return false }
        return expirationDate < Date()
    }
    
    /// Retourne le nombre de jours avant expiration
    var daysUntilExpiration: Int? {
        guard let expirationDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: expirationDate).day
    }
    
    /// Retourne une description textuelle de l'expiration
    var expirationDescription: String {
        guard let days = daysUntilExpiration else {
            return "Pas de date d'expiration"
        }
        
        if days < 0 {
            return "Expiré"
        } else if days == 0 {
            return "Expire aujourd'hui"
        } else if days == 1 {
            return "Expire demain"
        } else {
            return "Expire dans \(days) jours"
        }
    }
    
    /// Retourne la couleur appropriée pour le badge d'expiration
    var expirationBadgeColor: Color {
        guard let days = daysUntilExpiration else {
            return .secondary
        }
        
        if days < 0 {
            return .red
        } else if days <= 3 {
            return .orange
        } else if days <= 7 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Extension pour formater les montants

extension Double {
    
    /// Formate le montant en euros avec la locale française
    var formattedAsCurrency: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: self)) ?? "0,00 €"
    }
    
    /// Formate le montant en euros de manière courte (sans symbole)
    var formattedAsAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: self)) ?? "0,00"
    }
}

// MARK: - Extension SwiftUI View pour faciliter l'utilisation

extension View {
    
    /// Applique un style de carte compatible avec le widget
    func widgetCardStyle(color: Color, cornerRadius: CGFloat = 12) -> some View {
        self
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(color)
            )
    }
    
    /// Applique un badge d'expiration avec style automatique
    func expirationBadge(for voucher: Voucher) -> some View {
        Group {
            if let days = voucher.daysUntilExpiration {
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    
                    Text(voucher.expirationDescription)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(voucher.expirationBadgeColor)
                )
            }
        }
    }
}

// MARK: - Notifications pour les widgets

extension Notification.Name {
    /// Notification envoyée quand un voucher favori change
    static let favoriteVoucherChanged = Notification.Name("favoriteVoucherChanged")
    
    /// Notification envoyée quand une dépense est ajoutée (change le solde)
    static let voucherBalanceChanged = Notification.Name("voucherBalanceChanged")
}

// MARK: - Observer pour recharger automatiquement les widgets

@MainActor
class WidgetUpdateObserver: ObservableObject {
    
    private var observers: [NSObjectProtocol] = []
    
    init() {
        setupObservers()
    }
    
    private func setupObservers() {
        // Observer les changements de favoris
        let favoriteObserver = NotificationCenter.default.addObserver(
            forName: .favoriteVoucherChanged,
            object: nil,
            queue: .main
        ) { _ in
            WidgetReloader.reloadFavoriteVouchersWidget()
        }
        observers.append(favoriteObserver)
        
        // Observer les changements de solde
        let balanceObserver = NotificationCenter.default.addObserver(
            forName: .voucherBalanceChanged,
            object: nil,
            queue: .main
        ) { _ in
            WidgetReloader.reloadFavoriteVouchersWidget()
        }
        observers.append(balanceObserver)
    }
    
    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }
}

// MARK: - Exemples d'utilisation

/*

// EXEMPLE 1 : Dans VoucherDetailView

struct VoucherDetailView: View {
    @Bindable var voucher: Voucher
    
    var body: some View {
        VStack {
            // ... contenu
            
            Button {
                voucher.toggleFavoriteWithWidgetUpdate()
                // Le widget sera rechargé automatiquement
            } label: {
                Label(
                    voucher.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                    systemImage: voucher.isFavorite ? "star.fill" : "star"
                )
            }
        }
    }
}

// EXEMPLE 2 : Utilisation du formatage

Text(voucher.remainingBalance.formattedAsCurrency)
Text("Solde : \(voucher.remainingBalance.formattedAsAmount) €")

// EXEMPLE 3 : Badge d'expiration

VStack {
    Text(voucher.storeName)
    Text(voucher.remainingBalance.formattedAsCurrency)
}
.expirationBadge(for: voucher)

// EXEMPLE 4 : Style de carte

VStack {
    Text(voucher.storeName)
    Text(voucher.remainingBalance.formattedAsCurrency)
}
.widgetCardStyle(color: Color(hex: voucher.storeColor))

// EXEMPLE 5 : Avec notifications

struct AddExpenseView: View {
    func saveExpense() {
        // ... sauvegarder la dépense
        
        // Notifier le changement de solde
        NotificationCenter.default.post(name: .voucherBalanceChanged, object: nil)
    }
}

*/
