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
    
    // Container SwiftData avec les deux modèles et synchronisation iCloud
    let modelContainer: ModelContainer
    
    // Initialiser le SettingsManager et le ModelContainer au démarrage
    init() {
        // 1. D'abord créer le ModelContainer
        do {
            print("🔧 Création du Schema SwiftData...")
            let schema = Schema([Voucher.self, Expense.self])
            print("✅ Schema créé avec \(schema.entities.count) entités")
            
            // Configuration avec détection automatique d'iCloud
            // Si iCloud est disponible, il sera utilisé automatiquement
            // Sinon, les données seront stockées localement
            let modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                cloudKitDatabase: .none // On démarre en mode local
            )
            
            print("🔧 Création du ModelContainer...")
            
            // Pour activer iCloud plus tard :
            // 1. Ajoutez la capability "iCloud" avec CloudKit dans le projet
            // 2. Changez .none en .automatic ci-dessus
            // Les données locales seront automatiquement migrées vers iCloud
            
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ ModelContainer créé avec succès")
        } catch let error as NSError {
            print("❌ Erreur lors de la création du ModelContainer:")
            print("   Domain: \(error.domain)")
            print("   Code: \(error.code)")
            print("   Description: \(error.localizedDescription)")
            print("   User Info: \(error.userInfo)")
            if let underlyingError = error.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying error: \(underlyingError)")
            }
            fatalError("Could not create ModelContainer: \(error)")
        } catch {
            print("❌ Erreur lors de la création du ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
        
        // 2. Ensuite initialiser le SettingsManager
        _ = SettingsManager.shared
        print("🚀 App démarrée - SettingsManager initialisé")
    }
    
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
