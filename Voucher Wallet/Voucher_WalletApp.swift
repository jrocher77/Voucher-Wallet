//
//  Voucher_WalletApp.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import CoreData

@main
struct Voucher_WalletApp: App {
    @UIApplicationDelegateAdaptor(CloudSharingAppDelegate.self) private var appDelegate
    @State private var urlHandler = URLHandler()

    let persistence: SharedModelContainer
    let sharingManager: VoucherSharingManager
    
    // Initialiser le SettingsManager et le ModelContainer au démarrage
    init() {
        do {
            let persistence = try SharedModelContainer()
            self.persistence = persistence
            let sharingManager = VoucherSharingManager(persistence: persistence)
            self.sharingManager = sharingManager
            appDelegate.sharingManager = sharingManager
            debugLog("✅ Conteneur Core Data CloudKit privé/partagé créé")
        } catch {
            debugLog("❌ Erreur: \(error)")
            fatalError("Could not create persistent container: \(error)")
        }
        
        _ = SettingsManager.shared
        debugLog("🚀 App démarrée - SettingsManager initialisé")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(urlHandler)
                .environment(sharingManager)
                .environment(\.managedObjectContext, persistence.container.viewContext)
                .onOpenURL { url in
                    debugLog("🔵 App received URL: \(url)")
                    if sharingManager.acceptShareURLIfPossible(url) {
                        return
                    }
                    urlHandler.handleURL(url)
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    guard let url = activity.webpageURL else { return }
                    debugLog("🔵 App received user activity URL: \(url)")
                    if sharingManager.acceptShareURLIfPossible(url) {
                        return
                    }
                    urlHandler.handleURL(url)
                }
        }
    }
}
