//
//  LearningStatsView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//

import SwiftUI

/// Vue affichant les statistiques d'apprentissage des enseignes
struct LearningStatsView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var learnedStores: [String] = []
    @State private var mostUsedStores: [(String, Int)] = []
    @State private var showingResetAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // Section : Résumé
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enseignes mémorisées")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(learnedStores.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "brain.head.profile")
                            .font(.largeTitle)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Statistiques")
                }
                
                // Section : Enseignes apprises
                if !learnedStores.isEmpty {
                    Section {
                        ForEach(learnedStores.sorted(), id: \.self) { store in
                            HStack {
                                Text(store)
                                    .font(.body)
                                
                                Spacer()
                                
                                if let count = mostUsedStores.first(where: { $0.0 == store })?.1 {
                                    Text("\(count) fois")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                    .font(.caption)
                            }
                        }
                    } header: {
                        Text("Enseignes apprises")
                    } footer: {
                        Text("Ces enseignes seront détectées automatiquement lors des prochains imports.")
                            .font(.caption)
                    }
                }
                
                // Section : Enseignes les plus utilisées
                if !mostUsedStores.isEmpty {
                    Section {
                        ForEach(mostUsedStores, id: \.0) { store, count in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store)
                                        .font(.body)
                                    
                                    ProgressView(value: Double(count), total: Double(mostUsedStores.first?.1 ?? 1))
                                        .tint(.blue)
                                }
                                
                                Spacer()
                                
                                Text("\(count)")
                                    .font(.headline)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } header: {
                        Text("Enseignes les plus utilisées")
                    }
                }
                
                // Section : Actions
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        Label("Réinitialiser l'apprentissage", systemImage: "trash")
                    }
                    
                    Button {
                        exportLearningData()
                    } label: {
                        Label("Exporter les données", systemImage: "square.and.arrow.up")
                    }
                } footer: {
                    Text("La réinitialisation supprime toutes les enseignes apprises et les statistiques. Cette action est irréversible.")
                        .font(.caption)
                }
                
                // Section : Explications
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        explanationRow(
                            icon: "brain",
                            title: "Apprentissage automatique",
                            description: "L'application mémorise les enseignes que vous validez lors des imports."
                        )
                        
                        Divider()
                        
                        explanationRow(
                            icon: "chart.bar.fill",
                            title: "Score de confiance",
                            description: "Chaque détection reçoit un score basé sur la méthode utilisée et l'historique."
                        )
                        
                        Divider()
                        
                        explanationRow(
                            icon: "arrow.up.circle.fill",
                            title: "Amélioration continue",
                            description: "Plus vous utilisez l'app, plus la détection devient précise."
                        )
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Comment ça marche ?")
                }
            }
            .navigationTitle("Apprentissage")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
            .alert("Réinitialiser l'apprentissage ?", isPresented: $showingResetAlert) {
                Button("Annuler", role: .cancel) { }
                Button("Réinitialiser", role: .destructive) {
                    resetLearning()
                }
            } message: {
                Text("Toutes les enseignes apprises et les statistiques seront supprimées. Cette action est irréversible.")
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    // MARK: - Helpers
    
    @ViewBuilder
    private func explanationRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadData() {
        let learning = StoreNameLearning.shared
        learnedStores = learning.getLearnedStoreNames()
        mostUsedStores = learning.getMostUsedStores(limit: 10)
    }
    
    private func resetLearning() {
        StoreNameLearning.shared.resetLearningData()
        loadData()
    }
    
    private func exportLearningData() {
        let data = StoreNameLearning.shared.exportLearningData()
        
        // Convertir en JSON pour le partage
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            
            // Utiliser le système de partage iOS
            let activityViewController = UIActivityViewController(
                activityItems: [jsonString],
                applicationActivities: nil
            )
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                rootViewController.present(activityViewController, animated: true)
            }
        }
    }
}

#Preview {
    LearningStatsView()
}
