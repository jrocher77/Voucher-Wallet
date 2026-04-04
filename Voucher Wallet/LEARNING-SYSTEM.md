# Système d'Apprentissage et Score de Confiance

## 📚 Vue d'ensemble

Le système d'apprentissage de Voucher Wallet améliore automatiquement la détection des enseignes au fil du temps. Chaque fois que vous validez un bon, l'application apprend et mémorise :
- Le nom de l'enseigne pour améliorer les futures détections
- La couleur de fond préférée pour chaque enseigne
- La couleur de texte préférée pour chaque enseigne

## 🎯 Fonctionnalités principales

### 1. **Apprentissage automatique**
- Mémorisation des enseignes validées par l'utilisateur
- Création d'associations entre noms détectés et noms validés
- Compteurs d'utilisation pour chaque enseigne
- **🎨 NOUVEAU :** Apprentissage des préférences de couleur de fond
- **🎨 NOUVEAU :** Apprentissage des préférences de couleur de texte

### 2. **Score de confiance**
Chaque détection d'enseigne reçoit un score de 0 à 100% basé sur :

#### Méthode de détection (40% du score)
- **Enseigne connue** : 40% (liste prédéfinie)
- **Enseigne apprise** : 35% (mémorisée précédemment)
- **Label "Enseigne:"** : 35% (trouvée après un label explicite)
- **URL** : 30% (extraite d'un domaine web)
- **Ligne en majuscules** : 30% (première ligne en CAPS)
- **Première ligne** : 25% (première ligne du document)
- **Title Case** : 20% (format Capitalisé)

#### Historique d'utilisation (20% du score)
- +4% par utilisation précédente (max 20%)
- Plus une enseigne est utilisée, plus elle est fiable

#### Contexte de détection (30% du score)
- **URL correspondante** : +15%
- **Présence dans les premières lignes** : +10%
- **Texte en majuscules** : +5%

#### Longueur du nom (10% du score)
- Noms de 4 à 30 caractères : +10%
- Évite les détections trop courtes ou trop longues

### 3. **Badges visuels de confiance**

Les scores sont affichés avec des couleurs et icônes :

| Score | Couleur | Icône | Signification |
|-------|---------|-------|---------------|
| 80-100% | 🟢 Vert | ✓ | Très fiable |
| 60-79% | 🔵 Bleu | ✓ | Fiable |
| 40-59% | 🟠 Orange | ⚠️ | À vérifier |
| 0-39% | 🔴 Rouge | ? | Peu fiable |

## 🔧 Architecture technique

### `StoreNameLearning` (Singleton)
Gestionnaire principal de l'apprentissage.

#### Méthodes principales :
```swift
// Enregistrer une enseigne validée
func learnStoreName(_ storeName: String, detectedAs detectedName: String?)

// 🎨 NOUVEAU : Enregistrer la couleur de fond préférée
func learnStoreColor(_ colorHex: String, for storeName: String)

// 🎨 NOUVEAU : Enregistrer la couleur de texte préférée
func learnTextColor(_ textColorHex: String, for storeName: String)

// 🎨 NOUVEAU : Récupérer la couleur de fond apprise
func getLearnedStoreColor(for storeName: String) -> String?

// 🎨 NOUVEAU : Récupérer la couleur de texte apprise
func getLearnedTextColor(for storeName: String) -> String?

// 🎨 NOUVEAU : Suggérer une couleur de texte appropriée
func suggestTextColor(for backgroundColor: String) -> String

// 🎨 NOUVEAU : Valider le contraste entre deux couleurs
func hasGoodContrast(foreground: String, background: String) -> Bool

// Récupérer les enseignes apprises
func getLearnedStoreNames() -> [String]

// Calculer le score de confiance
func calculateConfidenceScore(
    for storeName: String,
    detectionMethod: DetectionMethod,
    context: DetectionContext
) -> Double

// Trouver un nom validé depuis un nom détecté
func findValidatedName(for detectedName: String) -> String?

// Statistiques
func getMostUsedStores(limit: Int) -> [(String, Int)]
```

#### Stockage :
- **UserDefaults** pour la persistance
- Clés utilisées :
  - `learnedStoreNames` : Liste des enseignes apprises
  - `storeNameCounts` : Compteurs d'utilisation
  - `storeNameMappings` : Associations nom détecté → nom validé
  - `learnedStoreColors` : 🎨 **NOUVEAU** - Couleurs de fond par enseigne
  - `learnedTextColors` : 🎨 **NOUVEAU** - Couleurs de texte par enseigne

### `PDFAnalyzer` (Modifications)

#### Structures mises à jour :
```swift
struct AnalysisResult {
    var detectedStoreName: String?
    var storeNameConfidence: Double  // ⭐ Nouveau
    var detectionMethod: StoreNameLearning.DetectionMethod?  // ⭐ Nouveau
    // ...
}

struct DetectedVoucher {
    var storeName: String?
    var storeNameConfidence: Double  // ⭐ Nouveau
    // ...
}
```

#### Fonction de détection :
```swift
// Retourne maintenant un tuple avec score et méthode
private static func detectStoreName(from text: String) 
    -> (name: String?, confidence: Double, method: DetectionMethod?)
```

### `PDFImportHandler` (Modifications)

#### Apprentissage lors de l'enregistrement :
```swift
// Import simple
private func saveVoucher() {
    // ... création du voucher
    
    // 📚 Apprentissage
    let detectedName = analysisResult?.detectedStoreName
    StoreNameLearning.shared.learnStoreName(storeName, detectedAs: detectedName)
    
    // ... sauvegarde
}

// Import multiple
private func importSelectedVouchers() {
    for detectedVoucher in selectedVouchers {
        // ... création du voucher
        
        // 📚 Apprentissage
        if let storeName = detectedVoucher.storeName {
            StoreNameLearning.shared.learnStoreName(storeName)
        }
    }
}
```

#### Affichage du score :
- Badge de confiance dans la liste multi-bons
- Section d'information dans le formulaire simple
- Avertissement si score < 70%

## 📊 Vue des statistiques

`LearningStatsView` permet de :
- Voir le nombre d'enseignes mémorisées
- Consulter la liste des enseignes apprises
- Afficher les enseignes les plus utilisées avec graphique
- Exporter les données d'apprentissage (JSON)
- Réinitialiser l'apprentissage

## 💡 Exemples d'utilisation

### Scénario 1 : Première utilisation
```
1. Import d'un bon "King Jouet"
2. Détection par heuristique (ligne en majuscules)
   → Score : 55% (orange)
3. L'utilisateur valide "King Jouet"
4. L'enseigne est mémorisée
```

### Scénario 2 : Deuxième import
```
1. Nouvel import "King Jouet"
2. Détection dans les enseignes apprises
   → Score : 75% (bleu)
3. Validation automatique plus confiante
```

### Scénario 3 : Après 5 imports
```
1. Import "King Jouet"
2. Détection dans les enseignes apprises
3. Bonus historique : +20% (5 utilisations)
   → Score : 90% (vert)
4. Détection très fiable
```

### Scénario 4 : Variation de nom
```
1. Import détecte "KING-JOUET"
2. Mapping trouvé : "KING-JOUET" → "King Jouet"
3. Utilise automatiquement "King Jouet"
   → Score : 85% (vert)
```

## 🔍 Débogage

### Logs de détection
```
🏪 Enseigne connue trouvée: Carrefour
  📊 Score de confiance: 85%

🏪 Enseigne apprise trouvée: King Jouet
  📊 Score de confiance: 75%

  → Candidat ligne 1 (majuscules): MA PETITE ENSEIGNE
🏪 Enseigne détectée par heuristique: Ma Petite Enseigne
  📊 Score de confiance: 50%
```

### Logs d'apprentissage
```
📚 Enseigne apprise: King Jouet
🔗 Association créée: "KING-JOUET" → "King Jouet"
```

## 🚀 Améliorations futures possibles

1. **Machine Learning** : Utiliser Core ML pour détecter les patterns
2. **Cloud sync** : Synchroniser l'apprentissage via iCloud
3. **Suggestions intelligentes** : Proposer des corrections basées sur l'historique
4. **Détection de logos** : Reconnaissance visuelle des logos d'enseignes
5. **API externe** : Base de données d'enseignes en ligne

## 📝 Tests recommandés

1. **Test d'apprentissage basique**
   - Importer un bon d'une nouvelle enseigne
   - Vérifier que l'enseigne est mémorisée
   - Réimporter un bon de la même enseigne
   - Vérifier que le score a augmenté

2. **Test de mappings**
   - Importer un bon avec "KING-JOUET"
   - Valider avec "King Jouet"
   - Réimporter avec "KING JOUET" (variante)
   - Vérifier que "King Jouet" est suggéré

3. **Test de réinitialisation**
   - Aller dans les statistiques
   - Réinitialiser l'apprentissage
   - Vérifier que toutes les données sont effacées

4. **Test d'export**
   - Apprendre plusieurs enseignes
   - Exporter les données
   - Vérifier le format JSON

## 🐛 Résolution de problèmes

### Problème : Score toujours bas
**Solution** : Vérifier que l'enseigne est correctement validée lors de l'enregistrement

### Problème : Enseigne non mémorisée
**Solution** : S'assurer que `learnStoreName()` est appelé après `modelContext.save()`

### Problème : Mappings non fonctionnels
**Solution** : Vérifier que les noms sont normalisés en uppercase pour la comparaison

## 📚 Ressources

- `UtilitiesStoreNameLearning.swift` : Logique d'apprentissage
- `UtilitiesStoreNameLearning+TextColor.swift` : 🎨 **NOUVEAU** - Extension pour les couleurs de texte
- `UtilitiesPDFAnalyzer.swift` : Détection avec scoring
- `ViewsPDFImportHandler.swift` : Intégration UI
- `ViewsLearningStatsView.swift` : Vue des statistiques
- `TEXT-COLOR-FEATURE.md` : 🎨 **NOUVEAU** - Documentation de la fonctionnalité couleur de texte
