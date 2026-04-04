//
//  Voucher_WalletApp.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

@main
struct Voucher_WalletApp: App {
    @State private var urlHandler = URLHandler()
    
    // Initialiser le SettingsManager au démarrage
    init() {
        // Force l'initialisation du singleton
        _ = SettingsManager.shared
        print("🚀 App démarrée - SettingsManager initialisé")
    }
    
    // Container SwiftData avec les deux modèles et synchronisation iCloud
    let modelContainer: ModelContainer = {
        do {
            let schema = Schema([Voucher.self, Expense.self])
            
            // Configuration avec détection automatique d'iCloud
            // Si iCloud est disponible, il sera utilisé automatiquement
            // Sinon, les données seront stockées localement
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // On démarre en mode local
            )
            
            // Pour activer iCloud plus tard :
            // 1. Ajoutez la capability "iCloud" avec CloudKit dans le projet
            // 2. Changez .none en .automatic ci-dessus
            // Les données locales seront automatiquement migrées vers iCloud
            
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(urlHandler)
                .onOpenURL { url in
                    print("🔵 App received URL: \(url)")
                    urlHandler.handleURL(url)
                }
        }
        .modelContainer(modelContainer)
    }
}
