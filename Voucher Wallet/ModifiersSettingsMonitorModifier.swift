//
//  SettingsMonitorModifier.swift
//  Voucher Wallet
//
//  Created by JEREMY on 04/04/2026.
//

import SwiftUI

/// Modifier qui surveille les demandes de réinitialisation depuis les Réglages iOS
struct SettingsMonitorModifier: ViewModifier {
    
    @StateObject private var settingsManager = SettingsManager.shared
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var showingResetConfirmation = false
    @State private var showingResetSuccess = false
    
    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    // Mettre à jour les statistiques
                    settingsManager.refreshOnAppActivation()
                    
                    // Vérifier si une réinitialisation a été demandée
                    settingsManager.checkForResetRequest()
                }
            }
            .onChange(of: settingsManager.shouldShowResetConfirmation) { _, shouldShow in
                if shouldShow {
                    showingResetConfirmation = true
                    // Remettre à false pour éviter de redemander
                    settingsManager.shouldShowResetConfirmation = false
                }
            }
            .alert("Réinitialiser l'apprentissage ?", isPresented: $showingResetConfirmation) {
                Button("Annuler", role: .cancel) {
                    settingsManager.cancelReset()
                }
                Button("Réinitialiser", role: .destructive) {
                    settingsManager.performReset()
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
}

// MARK: - Extension pour faciliter l'utilisation

extension View {
    /// Ajoute la surveillance des réglages iOS pour la réinitialisation de l'apprentissage
    func monitorSettingsChanges() -> some View {
        modifier(SettingsMonitorModifier())
    }
}
