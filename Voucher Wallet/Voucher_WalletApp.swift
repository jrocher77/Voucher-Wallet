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
        do {
            modelContainer = try SharedModelContainer.create()
            print("✅ ModelContainer créé avec App Group")
        } catch {
            print("❌ Erreur: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
        
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
