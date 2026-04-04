//
//  SettingsMonitorModifier.swift
//  Voucher Wallet
//
//  Created by JEREMY on 04/04/2026.
//

import SwiftUI

/// Modifier qui surveille les demandes de réinitialisation depuis les Réglages iOS
struct SettingsMonitorModifier: ViewModifier {
    
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showingResetConfirmation = false
    @State private var showingResetSuccess = false
    @State private var hasCheckedOnAppear = false
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                print("✨ SettingsMonitorModifier - onAppear")
                checkForReset()
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                print("🔄 ScenePhase changé: \(oldPhase) → \(newPhase)")
                
                if newPhase == .active {
                    print("🔄 App devient active - Vérification des réglages...")
                    checkForReset()
                }
            }
            .alert("Réinitialiser l'apprentissage ?", isPresented: $showingResetConfirmation) {
                Button("Annuler", role: .cancel) {
                    SettingsManager.shared.cancelReset()
                }
                Button("Réinitialiser", role: .destructive) {
                    SettingsManager.shared.performReset()
                    showingResetSuccess = true
                }
            } message: {
                Text("Toutes les données d'apprentissage seront supprimées (enseignes mémorisées, préférences de couleurs). Vos bons d'achat ne seront pas affectés.")
            }
            .alert("Apprentissage réinitialisé", isPresented: $showingResetSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Toutes les données d'apprentissage ont été supprimées.")
            }
    }
    
    // MARK: - Helpers
    
    private func checkForReset() {
        // Mettre à jour les statistiques
        SettingsManager.shared.refreshOnAppActivation()
        
        // Vérifier si une réinitialisation a été demandée
        let resetRequested = UserDefaults.standard.bool(forKey: "reset_learning_requested")
        print("📊 Reset demandé ? \(resetRequested)")
        
        if resetRequested {
            print("⚠️ Affichage de l'alerte de réinitialisation")
            showingResetConfirmation = true
        }
    }
}

// MARK: - Extension pour faciliter l'utilisation

extension View {
    /// Ajoute la surveillance des réglages iOS pour la réinitialisation de l'apprentissage
    func monitorSettingsChanges() -> some View {
        modifier(SettingsMonitorModifier())
    }
}
