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

        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            guard !inMemory, shouldAttemptStoreRecovery(for: error) else {
                throw error
            }

            print("⚠️ Échec du chargement SwiftData, tentative de récupération automatique...")
            try resetSharedPersistentStoreFiles()
            return try ModelContainer(for: schema, configurations: [configuration])
        }
    }

    private static func shouldAttemptStoreRecovery(for error: Error) -> Bool {
        let message = String(describing: error)
        return message.contains("loadIssueModelContainer")
    }

    private static func resetSharedPersistentStoreFiles() throws {
        let fileManager = FileManager.default
        guard let appGroupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw NSError(
                domain: "SharedModelContainer",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Impossible d'accéder au conteneur App Group."]
            )
        }

        let backupRoot = appGroupURL.appendingPathComponent("SwiftDataRecoveryBackup", isDirectory: true)
        try? fileManager.createDirectory(at: backupRoot, withIntermediateDirectories: true)
        let backupFolder = backupRoot.appendingPathComponent(String(Int(Date().timeIntervalSince1970)), isDirectory: true)
        try? fileManager.createDirectory(at: backupFolder, withIntermediateDirectories: true)

        guard let enumerator = fileManager.enumerator(at: appGroupURL, includingPropertiesForKeys: nil) else {
            return
        }

        for case let fileURL as URL in enumerator {
            if shouldResetStoreFile(fileURL) {
                let backupURL = backupFolder.appendingPathComponent(fileURL.lastPathComponent)
                if fileManager.fileExists(atPath: fileURL.path) {
                    try? fileManager.copyItem(at: fileURL, to: backupURL)
                    try? fileManager.removeItem(at: fileURL)
                }
            }
        }
    }

    private static func shouldResetStoreFile(_ fileURL: URL) -> Bool {
        let name = fileURL.lastPathComponent.lowercased()
        let knownPrefixes = ["default.store", "default.sqlite", "voucher wallet.store", "voucher wallet.sqlite"]
        return knownPrefixes.contains { name.hasPrefix($0) }
    }
}
