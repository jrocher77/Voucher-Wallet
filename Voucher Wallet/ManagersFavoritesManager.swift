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

    @discardableResult
    static func deletePersonalPreference(for voucherID: UUID, in context: NSManagedObjectContext) -> Bool {
        let request = PersonalVoucherPreference.fetchRequest()
        request.predicate = NSPredicate(format: "voucherID == %@", voucherID as CVarArg)

        do {
            let preferences = try context.fetch(request)
            guard !preferences.isEmpty else { return false }

            for preference in preferences {
                context.delete(preference)
            }
            try context.save()
            notifyChange()
            return true
        } catch {
            debugLog("Impossible de supprimer les préférences du bon: \(error.localizedDescription)")
            return false
        }
    }

    @discardableResult
    static func deleteOrphanedPreferences(in context: NSManagedObjectContext) -> Bool {
        do {
            let vouchers = try context.fetch(Voucher.fetchRequest())
            let existingVoucherIDs = Set(vouchers.filter { $0.managedObjectContext != nil && !$0.isDeleted }.map(\.id))
            let preferences = try context.fetch(PersonalVoucherPreference.fetchRequest())
            let orphanedPreferences = preferences.filter { !existingVoucherIDs.contains($0.voucherID) }
            guard !orphanedPreferences.isEmpty else { return false }

            for preference in orphanedPreferences {
                context.delete(preference)
            }
            try context.save()
            notifyChange()
            return true
        } catch {
            debugLog("Impossible de nettoyer les préférences favorites orphelines: \(error.localizedDescription)")
            return false
        }
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
