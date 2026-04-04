# 📝 TODO - Améliorations Futures

## ✅ Fonctionnalités Implémentées

- [x] Choix de la couleur de texte
- [x] Validation de contraste WCAG
- [x] Aperçu en temps réel
- [x] Apprentissage automatique
- [x] Suggestion intelligente
- [x] Préréglages de couleurs
- [x] Documentation complète

---

## 🚀 Améliorations Suggérées

### 🏃 Court Terme (Facile - 1-3h chacune)

#### Vue de statistiques des couleurs
- [ ] Ajouter une vue `LearnedColorsStatsView`
- [ ] Afficher les couleurs apprises par enseigne
- [ ] Graphiques de couleurs populaires
- [ ] Option d'export/import JSON

**Fichiers à modifier :**
- Créer : `ViewsLearnedColorsStatsView.swift`
- Modifier : `ContentView.swift` (ajouter navigation)

---

#### Plus de préréglages de couleurs de texte
- [ ] Passer de 4 à 10 couleurs prédéfinies
- [ ] Ajouter : beige, marron, bleu clair, vert clair, etc.
- [ ] Organiser par catégories (neutres, pastels, vifs)

**Fichiers à modifier :**
- `ViewsAddVoucherView.swift`
- `ViewsEditVoucherView.swift`

---

#### Export/Import des préférences
- [ ] Bouton "Exporter mes préférences"
- [ ] Format JSON pour partage
- [ ] Import depuis un fichier
- [ ] Share Sheet iOS

**Fichiers à créer :**
- `UtilitiesColorPreferencesExporter.swift`

**Fichiers à modifier :**
- Ajouter menu dans `ContentView.swift`

---

### 🏃‍♂️ Moyen Terme (Modéré - 4-8h chacune)

#### Synchronisation iCloud
- [ ] Activer iCloud capability
- [ ] Stocker les préférences dans CloudKit
- [ ] Synchronisation automatique
- [ ] Résolution de conflits

**Fichiers à créer :**
- `UtilitiesiCloudSyncManager.swift`

**Configuration :**
- Activer iCloud dans Xcode
- Configurer CloudKit Container

---

#### Détection automatique de logo
- [ ] Vision Framework pour détecter le logo
- [ ] Extraire les couleurs dominantes
- [ ] Suggérer palette automatiquement
- [ ] Apprentissage visuel

**Fichiers à créer :**
- `UtilitiesLogoDetector.swift`
- `UtilitiesColorExtractor.swift`

**Frameworks :**
- Vision (déjà utilisé)
- Core ML (optionnel)

---

#### Thèmes prédéfinis
- [ ] Créer 10 thèmes (luxe, sport, tech, nature, etc.)
- [ ] Permettre d'appliquer un thème complet
- [ ] Sélecteur de thème dans les settings
- [ ] Prévisualisation des thèmes

**Fichiers à créer :**
- `ModelsColorTheme.swift`
- `ViewsThemeSelectorView.swift`
- `UtilitiesThemePresets.swift`

---

#### Mode à contraste élevé
- [ ] Détecter le mode système
- [ ] Forcer contraste élevé (≥ 7:1)
- [ ] Préréglages optimisés accessibilité
- [ ] Support du mode à contraste élevé iOS

**Fichiers à modifier :**
- `ViewsVoucherCardView.swift`
- `ViewsAddVoucherView.swift`
- `ViewsEditVoucherView.swift`

---

### 🏃‍♀️ Long Terme (Complexe - 12-20h chacune)

#### IA générative pour palettes
- [ ] Intégrer Core ML
- [ ] Entraîner un modèle sur les couleurs harmonieuses
- [ ] Suggérer des palettes complètes
- [ ] Apprendre des choix utilisateur

**Technologies :**
- Core ML
- Create ML
- Vision Framework

**Fichiers à créer :**
- `UtilitiesColorAI.swift`
- `ColorPaletteSuggestion.mlmodel`

---

#### Analyse de sentiment couleur
- [ ] Associer des émotions aux couleurs
- [ ] Détecter l'enseigne et suggérer sentiment
- [ ] Luxe → Or/Noir, Sport → Bleu/Rouge, etc.
- [ ] Base de données de sentiments

**Fichiers à créer :**
- `ModelsColorSentiment.swift`
- `UtilitiesSentimentAnalyzer.swift`

---

#### Partage de thèmes entre utilisateurs
- [ ] Backend (Firebase ou CloudKit public)
- [ ] Upload de thèmes
- [ ] Galerie de thèmes communautaires
- [ ] Système de votes
- [ ] Modération

**Technologies :**
- CloudKit Public Database
- ou Firebase Firestore

**Fichiers à créer :**
- `ServicesThemeSharingService.swift`
- `ViewsCommunityThemesView.swift`
- `ModelsSharedTheme.swift`

---

#### Support Apple Wallet avec couleurs
- [ ] Génération de fichiers .pkpass
- [ ] Transfert des couleurs personnalisées
- [ ] Support du pass builder
- [ ] Signature des passes

**Technologies :**
- PassKit
- Certificat Apple Developer

**Fichiers à créer :**
- `UtilitiesPassKitGenerator.swift`

---

## 🎨 Améliorations UX/UI

### Interface
- [ ] Animations fluides (fade in/out)
- [ ] Haptic feedback lors du changement de couleur
- [ ] Gestes (swipe pour voir l'aperçu)
- [ ] Mode landscape optimisé

### Accessibilité
- [ ] VoiceOver complet
- [ ] Labels explicites
- [ ] Dynamic Type support
- [ ] Reduce Motion support

### Performance
- [ ] Cache des calculs de contraste
- [ ] Lazy loading des préréglages
- [ ] Optimisation SwiftUI (Equatable)

---

## 🧪 Tests

### Tests Unitaires
- [ ] Tests pour `calculateLuminance()`
- [ ] Tests pour `calculateContrastRatio()`
- [ ] Tests pour `suggestTextColor()`
- [ ] Tests d'apprentissage

**Fichiers à créer :**
- `Tests/StoreNameLearningTests.swift`
- `Tests/ColorContrastTests.swift`

### Tests UI
- [ ] Tests de navigation
- [ ] Tests de sélection de couleur
- [ ] Tests d'aperçu
- [ ] Tests d'enregistrement

**Fichiers à créer :**
- `UITests/ColorSelectionUITests.swift`

---

## 📚 Documentation

### À ajouter
- [ ] Vidéo de démonstration
- [ ] Screenshots pour l'App Store
- [ ] Tutoriel interactif dans l'app
- [ ] Changelog détaillé

### À améliorer
- [ ] Diagrammes d'architecture
- [ ] Flowcharts des interactions
- [ ] Captures d'écran annotées

---

## 🐛 Bugs Potentiels à Surveiller

### À vérifier
- [ ] Performance avec 1000+ bons
- [ ] Mémoire lors du changement rapide de couleurs
- [ ] Synchronisation iCloud (conflits)
- [ ] Migration depuis versions antérieures

### À tester
- [ ] Tous les formats de couleurs hex
- [ ] Couleurs avec transparence
- [ ] Mode sombre iOS
- [ ] Différentes tailles d'écran

---

## 🔧 Refactoring

### Code à améliorer
- [ ] Extraire la logique de contraste dans un service dédié
- [ ] Créer un `ColorValidator` protocol
- [ ] Unifier les fonctions de calcul (éviter duplication)
- [ ] Utiliser des ViewModels pour les vues complexes

### Architecture
- [ ] Pattern MVVM pour les vues
- [ ] Repository pattern pour l'apprentissage
- [ ] Dependency Injection

---

## 📊 Analytics (Optionnel)

- [ ] Tracker les combinaisons de couleurs utilisées
- [ ] Analyser les ratios de contraste moyens
- [ ] Mesurer l'utilisation des préréglages
- [ ] A/B testing sur les suggestions

**Privacy-first :**
- Anonyme
- Opt-in
- Local uniquement (pas de serveur)

---

## 🌍 Internationalisation

- [ ] Localisation française (déjà fait)
- [ ] Localisation anglaise
- [ ] Localisation espagnole
- [ ] Localisation allemande

**Fichiers à créer :**
- `Localizable.strings` (en, es, de)

---

## 🎯 Priorités Recommandées

### Phase 1 - Quick Wins (Cette semaine)
1. Vue de statistiques des couleurs
2. Plus de préréglages (10 couleurs)
3. Export/Import JSON

### Phase 2 - Valeur Ajoutée (Ce mois)
4. Synchronisation iCloud
5. Mode à contraste élevé
6. Thèmes prédéfinis

### Phase 3 - Innovation (Ce trimestre)
7. Détection de logo
8. IA générative
9. Partage communautaire

---

## ✅ Checklist de Chaque Nouvelle Fonctionnalité

Quand vous implémentez une amélioration :

- [ ] Code écrit et testé
- [ ] Documentation technique créée
- [ ] Guide utilisateur mis à jour
- [ ] Tests unitaires ajoutés
- [ ] Previews SwiftUI créées
- [ ] README mis à jour
- [ ] CHANGELOG mis à jour
- [ ] Migration documentée (si nécessaire)

---

## 💡 Idées en Vrac

### À explorer
- Mode daltonien (simulation)
- Générateur de dégradés
- Couleurs basées sur la géolocalisation
- Couleurs basées sur l'heure (jour/nuit)
- Gamification (badges pour belles combinaisons)
- Widget iOS pour voir les couleurs favorites
- Complications watchOS
- Extension clavier pour picker couleur système

---

## 📞 Contributions

Si vous implémentez une de ces fonctionnalités :

1. Créer une branche `feature/nom-fonctionnalite`
2. Implémenter + tests
3. Documenter
4. Pull request

---

## 🎉 Conclusion

**N'oubliez pas :**
- ✅ Commencer petit (quick wins)
- ✅ Tester rigoureusement
- ✅ Documenter toujours
- ✅ Penser accessibilité
- ✅ S'amuser ! 🎨

---

**Document créé le :** 04/04/2026  
**Par :** JEREMY  
**Type :** TODO List  
**Version :** 1.0  
**Statut :** 🔄 En cours

**Bon développement ! 🚀**
