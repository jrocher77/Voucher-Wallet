//
//  FavoritesManager.swift
//  Voucher Wallet
//
//  Created by JEREMY on 06/04/2026.
//

import Foundation
import SwiftData
import SwiftUI

@Observable
final class FavoritesManager {
    private let modelContext: ModelContext
    static let maxFavorites = 4
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Toggle le statut favori d'un voucher
    func toggleFavorite(_ voucher: Voucher) -> FavoriteToggleResult {
        if voucher.isFavorite {
            // Retirer des favoris
            voucher.isFavorite = false
            try? modelContext.save()
            return .removed
        } else {
            // Vérifier si on peut ajouter
            let currentFavorites = getFavoriteVouchers()
            if currentFavorites.count >= Self.maxFavorites {
                return .limitReached(currentFavorites: currentFavorites)
            }
            
            // Ajouter aux favoris
            voucher.isFavorite = true
            try? modelContext.save()
            return .added
        }
    }
    
    /// Récupère tous les vouchers favoris
    func getFavoriteVouchers() -> [Voucher] {
        let descriptor = FetchDescriptor<Voucher>(
            predicate: #Predicate { $0.isFavorite == true },
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        
        do {
            return try modelContext.fetch(descriptor)
        } catch {
            print("Erreur lors de la récupération des favoris: \(error)")
            return []
        }
    }
    
}

enum FavoriteToggleResult {
    case added
    case removed
    case limitReached(currentFavorites: [Voucher])
}
