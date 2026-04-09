//
//  SharedModelContainer.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//
//  Container SwiftData partagé entre l'app et les widgets

import Foundation
import SwiftData

/// Configuration du container SwiftData partagé
enum SharedModelContainer {
    
    /// L'identifiant de l'App Group à utiliser
    /// ⚠️ IMPORTANT : Remplacez par votre propre identifiant App Group
    /// configuré dans Signing & Capabilities
    /// Format recommandé : group.com.[votre-team-id].voucherwallet
    nonisolated static let appGroupIdentifier = "group.com.jrocher77.voucherwallet"
    
    /// Crée un ModelContainer partagé entre l'app et les widgets
    /// - Parameter inMemory: Si true, utilise un stockage en mémoire (pour les previews)
    /// - Returns: Un ModelContainer configuré
    static func create(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([Voucher.self, Expense.self])
        
        let configuration: ModelConfiguration
        
        if inMemory {
            // Pour les previews et tests
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            // Pour la production - avec App Group pour partager avec les widgets
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(appGroupIdentifier),
                cloudKitDatabase: .none // Changez en .automatic pour activer iCloud
            )
        }
        
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
