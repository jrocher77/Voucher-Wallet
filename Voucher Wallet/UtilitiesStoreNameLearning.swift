//
//  StoreNameLearning.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//

import Foundation

/// Gestionnaire d'apprentissage des noms d'enseignes
/// Mémorise les enseignes détectées et validées par l'utilisateur
class StoreNameLearning {
    
    // Singleton pour accès global
    static let shared = StoreNameLearning()
    
    private let userDefaultsKey = "learnedStoreNames"
    private let storeCountKey = "storeNameCounts"
    
    private init() {}
    
    // MARK: - Apprentissage
    
    /// Enregistre une enseigne comme validée par l'utilisateur
    /// - Parameters:
    ///   - storeName: Le nom de l'enseigne à mémoriser
    ///   - detectedName: Le nom qui avait été détecté (peut être différent)
    func learnStoreName(_ storeName: String, detectedAs detectedName: String? = nil) {
        var learnedStores = getLearnedStoreNames()
        
        // Ajouter le nom validé
        if !learnedStores.contains(storeName) {
            learnedStores.append(storeName)
            saveLearnedStoreNames(learnedStores)
            print("📚 Enseigne apprise: \(storeName)")
        }
        
        // Incrémenter le compteur pour améliorer le scoring
        incrementStoreCount(storeName)
        
        // Si le nom détecté était différent, créer une association
        if let detected = detectedName, detected != storeName {
            saveStoreNameMapping(from: detected, to: storeName)
            print("🔗 Association créée: \"\(detected)\" → \"\(storeName)\"")
        }
    }
    
    /// Récupère la liste des enseignes apprises
    func getLearnedStoreNames() -> [String] {
        return UserDefaults.standard.stringArray(forKey: userDefaultsKey) ?? []
    }
    
    /// Sauvegarde la liste des enseignes apprises
    private func saveLearnedStoreNames(_ names: [String]) {
        UserDefaults.standard.set(names, forKey: userDefaultsKey)
    }
    
    // MARK: - Compteurs et statistiques
    
    /// Incrémente le compteur d'utilisation d'une enseigne
    private func incrementStoreCount(_ storeName: String) {
        var counts = getStoreCounts()
        counts[storeName, default: 0] += 1
        saveStoreCounts(counts)
    }
    
    /// Récupère le nombre de fois qu'une enseigne a été utilisée
    func getStoreCount(_ storeName: String) -> Int {
        let counts = getStoreCounts()
        return counts[storeName] ?? 0
    }
    
    /// Récupère tous les compteurs
    private func getStoreCounts() -> [String: Int] {
        return UserDefaults.standard.dictionary(forKey: storeCountKey) as? [String: Int] ?? [:]
    }
    
    /// Sauvegarde les compteurs
    private func saveStoreCounts(_ counts: [String: Int]) {
        UserDefaults.standard.set(counts, forKey: storeCountKey)
    }
    
    // MARK: - Mappings (associations de noms)
    
    private let mappingKey = "storeNameMappings"
    
    /// Crée une association entre un nom détecté et le nom validé
    private func saveStoreNameMapping(from detected: String, to validated: String) {
        var mappings = getStoreNameMappings()
        mappings[detected.uppercased()] = validated
        UserDefaults.standard.set(mappings, forKey: mappingKey)
    }
    
    /// Récupère les associations de noms
    private func getStoreNameMappings() -> [String: String] {
        return UserDefaults.standard.dictionary(forKey: mappingKey) as? [String: String] ?? [:]
    }
    
    /// Cherche si un nom détecté correspond à un nom validé connu
    func findValidatedName(for detectedName: String) -> String? {
        let mappings = getStoreNameMappings()
        return mappings[detectedName.uppercased()]
    }
    
    // MARK: - Scoring et confiance
    
    /// Calcule un score de confiance pour un nom d'enseigne détecté
    /// - Parameters:
    ///   - storeName: Le nom détecté
    ///   - detectionMethod: La méthode de détection utilisée
    ///   - context: Contexte additionnel (présence d'URL, position dans le texte, etc.)
    /// - Returns: Un score entre 0.0 et 1.0
    func calculateConfidenceScore(
        for storeName: String,
        detectionMethod: DetectionMethod,
        context: DetectionContext
    ) -> Double {
        var score: Double = 0.0
        
        // 1. Score de base selon la méthode de détection (0.0 - 0.4)
        switch detectionMethod {
        case .knownStore:
            score += 0.4  // Très fiable
        case .learnedStore:
            score += 0.35 // Très fiable aussi
        case .urlExtraction:
            score += 0.3
        case .firstLine:
            score += 0.25
        case .uppercaseLine:
            score += 0.3
        case .labeledStore:
            score += 0.35
        case .titleCase:
            score += 0.2
        }
        
        // 2. Bonus si l'enseigne a été utilisée plusieurs fois (0.0 - 0.2)
        let useCount = getStoreCount(storeName)
        if useCount > 0 {
            score += min(Double(useCount) * 0.04, 0.2)
        }
        
        // 3. Bonus selon le contexte (0.0 - 0.3)
        if context.hasMatchingURL {
            score += 0.15
        }
        if context.isInFirstLines {
            score += 0.1
        }
        if context.isAllUppercase {
            score += 0.05
        }
        
        // 4. Bonus si le nom est raisonnablement long (0.0 - 0.1)
        let nameLength = storeName.count
        if nameLength >= 4 && nameLength <= 30 {
            score += 0.1
        }
        
        // Limiter entre 0.0 et 1.0
        return min(max(score, 0.0), 1.0)
    }
    
    // MARK: - Types de support
    
    enum DetectionMethod {
        case knownStore      // Enseigne dans la liste prédéfinie
        case learnedStore    // Enseigne apprise précédemment
        case urlExtraction   // Extraite d'une URL
        case firstLine       // Première ligne du document
        case uppercaseLine   // Ligne en majuscules
        case labeledStore    // Après un label "Enseigne:" ou "Store:"
        case titleCase       // Format Title Case
    }
    
    struct DetectionContext {
        var hasMatchingURL: Bool = false
        var isInFirstLines: Bool = false
        var isAllUppercase: Bool = false
        var lineNumber: Int = 0
    }
    
    // MARK: - Statistiques
    
    /// Retourne les enseignes les plus utilisées
    func getMostUsedStores(limit: Int = 10) -> [(String, Int)] {
        let counts = getStoreCounts()
        return counts.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }
    
    /// Exporte les données d'apprentissage (pour debug ou transfert)
    func exportLearningData() -> [String: Any] {
        return [
            "learnedStores": getLearnedStoreNames(),
            "storeCounts": getStoreCounts(),
            "mappings": getStoreNameMappings()
        ]
    }
    
    /// Réinitialise toutes les données d'apprentissage
    func resetLearningData() {
        UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        UserDefaults.standard.removeObject(forKey: storeCountKey)
        UserDefaults.standard.removeObject(forKey: mappingKey)
        print("🗑️ Données d'apprentissage réinitialisées")
    }
}
