//
//  SettingsManager.swift
//  Voucher Wallet
//
//  Created by JEREMY on 04/04/2026.
//

import Foundation
import SwiftUI
import Combine

/// Gestionnaire pour synchroniser les données d'apprentissage avec les Réglages iOS
class SettingsManager: ObservableObject {
    
    static let shared = SettingsManager()
    
    // Clés UserDefaults pour les statistiques affichées dans Réglages iOS
    private let learnedStoresCountKey = "learned_stores_count"
    private let colorPreferencesCountKey = "color_preferences_count"
    private let topStore1Key = "top_store_1"
    private let topStore2Key = "top_store_2"
    private let topStore3Key = "top_store_3"
    private let resetRequestedKey = "reset_learning_requested"
    
    @Published var shouldShowResetConfirmation = false
    
    private init() {
        // Enregistrer les valeurs par défaut
        registerDefaultSettings()
        
        // Observer les changements dans UserDefaults
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDefaultsDidChange),
            name: UserDefaults.didChangeNotification,
            object: nil
        )
        
        // Observer les changements dans les données d'apprentissage
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(learningDataDidChange),
            name: .learningDataDidChange,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Enregistrement des valeurs par défaut
    
    private func registerDefaultSettings() {
        let defaults: [String: Any] = [
            learnedStoresCountKey: 0,
            colorPreferencesCountKey: 0,
            topStore1Key: "-",
            topStore2Key: "-",
            topStore3Key: "-",
            resetRequestedKey: false,
            "version_preference": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        ]
        
        UserDefaults.standard.register(defaults: defaults)
    }
    
    // MARK: - Mise à jour des statistiques
    
    /// Met à jour les statistiques affichées dans les Réglages iOS
    func updateSettingsStatistics() {
        let learning = StoreNameLearning.shared
        
        // Nombre d'enseignes mémorisées
        let learnedCount = learning.getLearnedStoreNames().count
        UserDefaults.standard.set(learnedCount, forKey: learnedStoresCountKey)
        
        // Nombre de préférences de couleurs
        let colorCount = countColorPreferences()
        UserDefaults.standard.set(colorCount, forKey: colorPreferencesCountKey)
        
        // Top 3 enseignes
        let topStores = learning.getMostUsedStores(limit: 3)
        
        if topStores.count > 0 {
            let store1 = "\(topStores[0].0) (\(topStores[0].1))"
            UserDefaults.standard.set(store1, forKey: topStore1Key)
        } else {
            UserDefaults.standard.set("-", forKey: topStore1Key)
        }
        
        if topStores.count > 1 {
            let store2 = "\(topStores[1].0) (\(topStores[1].1))"
            UserDefaults.standard.set(store2, forKey: topStore2Key)
        } else {
            UserDefaults.standard.set("-", forKey: topStore2Key)
        }
        
        if topStores.count > 2 {
            let store3 = "\(topStores[2].0) (\(topStores[2].1))"
            UserDefaults.standard.set(store3, forKey: topStore3Key)
        } else {
            UserDefaults.standard.set("-", forKey: topStore3Key)
        }
        
        print("📊 Statistiques mises à jour dans les Réglages iOS")
    }
    
    private func countColorPreferences() -> Int {
        let data = StoreNameLearning.shared.exportLearningData()
        if let colors = data["storeColors"] as? [String: [String: Int]] {
            return colors.count
        }
        return 0
    }
    
    // MARK: - Détection de la demande de réinitialisation
    
    @objc private func userDefaultsDidChange(_ notification: Notification) {
        // Pas besoin de gérer ici, on vérifie dans checkForResetRequest()
    }
    
    @objc private func learningDataDidChange(_ notification: Notification) {
        // Mettre à jour les statistiques quand les données d'apprentissage changent
        updateSettingsStatistics()
    }
    
    /// Vérifie si une réinitialisation a été demandée depuis les Réglages iOS
    /// Cette méthode doit être appelée quand l'app devient active
    func checkForResetRequest() {
        let resetRequested = UserDefaults.standard.bool(forKey: resetRequestedKey)
        print("🔍 Vérification reset: \(resetRequested)")
        
        if resetRequested {
            print("✅ Reset demandé, déclenchement de l'alerte")
            // Déclencher l'alerte de confirmation
            DispatchQueue.main.async {
                self.shouldShowResetConfirmation = true
            }
        }
    }
    
    /// Effectue la réinitialisation et réinitialise le toggle dans les Réglages
    func performReset() {
        StoreNameLearning.shared.resetLearningData()
        
        // Remettre le toggle à OFF
        UserDefaults.standard.set(false, forKey: resetRequestedKey)
        
        // Mettre à jour les statistiques (elles seront à zéro)
        updateSettingsStatistics()
        
        print("✅ Réinitialisation effectuée depuis les Réglages iOS")
    }
    
    /// Annule la demande de réinitialisation (remet le toggle à OFF)
    func cancelReset() {
        print("❌ Réinitialisation annulée")
        UserDefaults.standard.set(false, forKey: resetRequestedKey)
    }
}

// MARK: - Extension pour faciliter l'utilisation

extension SettingsManager {
    
    /// Met à jour les statistiques et affiche une alerte de réinitialisation si nécessaire
    /// À appeler dans `onAppear` ou `scenePhase`
    func refreshOnAppActivation() {
        updateSettingsStatistics()
    }
}
