//
//  WidgetReloader.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//
//  Utilitaire pour recharger les widgets quand les données changent

import Foundation
import WidgetKit

/// Gestionnaire de rechargement des widgets
struct WidgetReloader {
    
    /// Recharge tous les widgets de l'application
    static func reloadAllWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
        print("♻️ Tous les widgets ont été rechargés")
    }
    
    /// Recharge un widget spécifique
    /// - Parameter kind: L'identifiant du widget à recharger
    static func reloadWidget(kind: String) {
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
        print("♻️ Widget '\(kind)' rechargé")
    }
    
    /// Recharge le widget des favoris
    static func reloadFavoriteVouchersWidget() {
        reloadWidget(kind: "FavoriteVouchersWidget")
    }
}
