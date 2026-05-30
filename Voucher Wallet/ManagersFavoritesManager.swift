//
//  FavoritesManager.swift
//  Voucher Wallet
//
//  Created by JEREMY on 06/04/2026.
//

import Foundation
import CoreData
import SwiftUI

@Observable
final class FavoritesManager {
    private let modelContext: NSManagedObjectContext
    static let maxFavorites = 4
    static let favoritesDidChange = Notification.Name("FavoritesManager.favoritesDidChange")
    
    init(modelContext: NSManagedObjectContext) {
        self.modelContext = modelContext
    }
    
    /// Toggle le statut favori d'un voucher
    func toggleFavorite(_ voucher: Voucher) -> FavoriteToggleResult {
        if voucher.isFavorite {
            // Retirer des favoris
            voucher.isFavorite = false
            saveAndNotifyChange()
            return .removed
        } else {
            // Vérifier si on peut ajouter
            let currentFavorites = getFavoriteVouchers()
            if currentFavorites.count >= Self.maxFavorites {
                return .limitReached(currentFavorites: currentFavorites)
            }
            
            // Ajouter aux favoris
            voucher.isFavorite = true
            let maxSortOrder = currentFavorites.map(\.sortOrder).max() ?? -1
            voucher.sortOrder = maxSortOrder + 1
            saveAndNotifyChange()
            return .added
        }
    }
    
    /// Récupère tous les vouchers favoris
    func getFavoriteVouchers() -> [Voucher] {
        do {
            let request = Voucher.fetchRequest()
            let vouchers = try modelContext.fetch(request).filter(\.isFavorite)
            return vouchers.sorted {
                $0.sortOrder == $1.sortOrder
                    ? $0.dateAdded > $1.dateAdded
                    : $0.sortOrder < $1.sortOrder
            }
        } catch {
            debugLog("Erreur lors de la récupération des favoris: \(error)")
            return []
        }
    }

    static func notifyChange() {
        NotificationCenter.default.post(name: favoritesDidChange, object: nil)
    }

    private func saveAndNotifyChange() {
        do {
            try modelContext.save()
            Self.notifyChange()
        } catch {
            debugLog("Erreur lors de la sauvegarde des favoris: \(error)")
        }
    }
    
}

enum FavoriteToggleResult {
    case added
    case removed
    case limitReached(currentFavorites: [Voucher])
}
