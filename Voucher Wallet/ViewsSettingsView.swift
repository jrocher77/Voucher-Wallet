//
//  SettingsView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 04/04/2026.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingResetConfirmation = false
    @State private var showingResetSuccess = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "brain.head.profile")
                                .font(.title)
                                .foregroundStyle(.blue)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Apprentissage automatique")
                                    .font(.headline)
                                
                                Text("L'app mémorise vos préférences")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Text("L'application apprend automatiquement :")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.top, 8)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Les noms d'enseignes que vous validez")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Vos préférences de couleurs par enseigne")
                                    .font(.caption)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                                Text("Les associations entre noms détectés et validés")
                                    .font(.caption)
                            }
                        }
                        .padding(.leading, 4)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("À propos")
                }
                
                Section {
                    // Statistiques
                    learningStatsView
                } header: {
                    Text("Statistiques")
                }
                
                Section {
                    Button(role: .destructive) {
                        showingResetConfirmation = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.circle.fill")
                            Text("Réinitialiser l'apprentissage")
                        }
                    }
                } header: {
                    Text("Données")
                } footer: {
                    Text("Cette action supprimera toutes les données d'apprentissage (enseignes mémorisées, préférences de couleurs). Vos bons ne seront pas affectés.")
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Réinitialiser l'apprentissage ?",
                isPresented: $showingResetConfirmation,
                titleVisibility: .visible
            ) {
                Button("Réinitialiser", role: .destructive) {
                    resetLearningData()
                }
                Button("Annuler", role: .cancel) { }
            } message: {
                Text("Toutes les données d'apprentissage seront supprimées. Cette action est irréversible.")
            }
            .alert("Apprentissage réinitialisé", isPresented: $showingResetSuccess) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Toutes les données d'apprentissage ont été supprimées.")
            }
        }
    }
    
    private var learningStatsView: some View {
        Group {
            // Nombre d'enseignes apprises
            HStack {
                Label("Enseignes mémorisées", systemImage: "building.2")
                Spacer()
                Text("\(StoreNameLearning.shared.getLearnedStoreNames().count)")
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
            
            // Top 3 enseignes les plus utilisées
            if !StoreNameLearning.shared.getMostUsedStores(limit: 3).isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Enseignes favorites")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                    
                    ForEach(Array(StoreNameLearning.shared.getMostUsedStores(limit: 3).enumerated()), id: \.element.0) { index, item in
                        HStack {
                            Text("\(medalEmoji(for: index))")
                                .font(.title3)
                            
                            Text(item.0)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Text("\(item.1) bon\(item.1 > 1 ? "s" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            
            // Nombre total de préférences de couleurs
            HStack {
                Label("Préférences de couleurs", systemImage: "paintpalette")
                Spacer()
                Text("\(countColorPreferences())")
                    .foregroundStyle(.secondary)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func medalEmoji(for index: Int) -> String {
        switch index {
        case 0: return "🥇"
        case 1: return "🥈"
        case 2: return "🥉"
        default: return "•"
        }
    }
    
    private func countColorPreferences() -> Int {
        let data = StoreNameLearning.shared.exportLearningData()
        if let colors = data["storeColors"] as? [String: [String: Int]] {
            return colors.count
        }
        return 0
    }
    
    private func resetLearningData() {
        StoreNameLearning.shared.resetLearningData()
        showingResetSuccess = true
    }
}

#Preview {
    SettingsView()
}
