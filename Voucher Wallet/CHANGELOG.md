# 📝 Changelog

Toutes les modifications notables de Voucher Wallet sont documentées dans ce fichier.

Le format est basé sur [Keep a Changelog](https://keepachangelog.com/fr/1.0.0/).

---

## [1.1.0] - 2026-04-04

### 🎨 Ajouté

#### Personnalisation de la Couleur de Texte
- **Sélection de couleur de texte** : ColorPicker dédié dans les vues d'ajout et d'édition
- **Validation de contraste WCAG** : Calcul automatique du ratio de contraste (minimum 3:1)
- **Aperçu en temps réel** : Mini-carte affichant immédiatement le résultat des couleurs choisies
- **Avertissement visuel** : Alerte si les couleurs sont trop similaires ou ont un contraste insuffisant
- **Préréglages de couleurs de texte** : 4 couleurs optimisées (Blanc, Noir, Gris clair, Gris foncé)
- **Apprentissage automatique** : Mémorisation des préférences de couleur de texte par enseigne
- **Suggestion intelligente** : Proposition automatique de blanc ou noir selon la luminosité du fond

#### Système d'Apprentissage
- **Extension `StoreNameLearning+TextColor`** : Gestion complète de l'apprentissage des couleurs de texte
- **Méthode `learnTextColor()`** : Enregistrement des préférences
- **Méthode `getLearnedTextColor()`** : Récupération des préférences
- **Méthode `suggestTextColor()`** : Suggestion basée sur la luminosité du fond
- **Méthode `hasGoodContrast()`** : Validation du contraste entre deux couleurs
- **Stockage UserDefaults** : Clé `learnedTextColors` pour la persistance

#### Validation et Accessibilité
- **Calcul de luminosité** : Algorithme W3C pour la luminosité relative
- **Ratio de contraste** : Formule WCAG pour le contraste
- **Standards WCAG 2.1** :
  - Niveau A : Ratio ≥ 3:1
  - Niveau AA : Ratio ≥ 4.5:1 (recommandé)
  - Niveau AAA : Ratio ≥ 7:1 (optimal)

#### Interface Utilisateur
- **Section "Couleur de la carte"** enrichie :
  - 2 ColorPickers (fond + texte)
  - Aperçu en temps réel
  - Avertissement si contraste faible
  - Préréglages organisés
- **Vue de démonstration** : `TextColorExampleView` avec 8 exemples de combinaisons

#### Documentation
- **13 nouveaux documents** :
  - `TEXT-COLOR-FEATURE.md` - Spécifications techniques
  - `TEXT-COLOR-IMPLEMENTATION-SUMMARY.md` - Résumé d'implémentation
  - `GUIDE-COULEURS-TEXTE.md` - Guide utilisateur
  - `QUICK-START-TEXT-COLOR.md` - Démarrage rapide
  - `MIGRATION-GUIDE-TEXT-COLOR.md` - Guide de migration
  - `START-HERE.md` - Démarrage en 60 secondes
  - `INDEX.md` - Index de navigation
  - `PROJECT-STRUCTURE.md` - Structure du projet
  - `VISUAL-EXAMPLES.md` - Exemples visuels
  - `TODO-IMPROVEMENTS.md` - Améliorations futures
  - `FINAL-IMPLEMENTATION-SUMMARY.md` - Résumé final
  - `CHANGELOG.md` - Ce fichier
- **Documentation mise à jour** :
  - `LEARNING-SYSTEM.md` - Ajout des couleurs de texte
  - `README.md` - Étape 4 et structure de données

### 🔄 Modifié

#### Modèle de Données
- **`Voucher`** :
  - Ajout propriété `textColor: String` (hex color)
  - Valeur par défaut `#FFFFFF` (blanc)
  - Migration automatique par SwiftData

#### Vues
- **`VoucherCardView`** :
  - Propriété calculée `textColor` pour utiliser la couleur personnalisée
  - Tous les textes utilisent `textColor` au lieu de `.white`
  
- **`AddVoucherView`** :
  - Ajout `@State private var selectedTextColor`
  - Section "Couleur de la carte" complète
  - Fonctions de validation de contraste
  - Mise à jour `saveVoucher()` pour inclure textColor
  - Mise à jour `importSelectedVouchers()` pour récupérer couleur apprise
  
- **`EditVoucherView`** :
  - Ajout `@State private var selectedTextColor`
  - Section "Couleur de la carte" complète
  - Fonctions de validation de contraste
  - Mise à jour `saveChanges()` pour inclure textColor

### ⚙️ Technique

#### Algorithmes Implémentés
- **Luminosité relative** : Formule W3C sRGB avec linéarisation
- **Ratio de contraste** : `(L1 + 0.05) / (L2 + 0.05)` selon WCAG
- **Suggestion** : Basculement à 50% de luminosité (blanc/noir)

#### Performance
- Calculs de luminosité : O(1)
- Pas d'impact sur le rendu
- UserDefaults pour accès instantané

### 📊 Statistiques

#### Code
- **2 nouveaux fichiers** Swift (~420 lignes)
- **4 fichiers modifiés** (~80 lignes ajoutées)
- **Total** : ~500 lignes de code Swift

#### Documentation
- **11 nouveaux fichiers** Markdown (~2800 lignes)
- **2 fichiers mis à jour** (~200 lignes)
- **Total** : ~3000 lignes de documentation

---

## [1.0.0] - 2026-04-02

### ✨ Version Initiale

#### Fonctionnalités de Base
- Modèle SwiftData `Voucher`
- Liste des bons style Wallet
- Cartes colorées par enseigne
- Filtres multi-critères
- État vide avec onboarding

#### Codes-Barres
- Génération QR codes (CoreImage)
- Génération codes-barres Code128
- Vue détaillée avec scan
- Luminosité automatique à 100%
- Code PIN masqué/révélable

#### Import PDF
- Sélecteur de fichiers natif
- Analyse avec Vision Framework
- OCR pour extraction de texte
- Détection de codes-barres
- Extraction intelligente :
  - Numéros de bon
  - Codes PIN
  - Montants
  - Dates d'expiration

#### Personnalisation
- Préréglages de couleurs (15 enseignes)
- Sélection de couleur de fond
- ColorPicker natif

#### Système d'Apprentissage
- Mémorisation des enseignes
- Score de confiance
- Mappings nom détecté → validé
- Statistiques d'utilisation

#### Documentation
- `README.md` - Guide de développement
- `LEARNING-SYSTEM.md` - Système d'apprentissage
- `INFO.plist-Configuration.md` - Configuration
- `DEBUG-GUIDE.md` - Débogage
- Guides icônes d'app

---

## [0.9.0] - 2026-04-01

### 🚧 Pre-release

- Prototypage initial
- Tests de concept
- Architecture de base
- Premiers modèles

---

## Format du Changelog

### Types de Changements
- **Ajouté** : Nouvelles fonctionnalités
- **Modifié** : Changements dans les fonctionnalités existantes
- **Déprécié** : Fonctionnalités bientôt supprimées
- **Supprimé** : Fonctionnalités supprimées
- **Corrigé** : Corrections de bugs
- **Sécurité** : Vulnérabilités corrigées

### Format de Version
Le projet suit le [Semantic Versioning](https://semver.org/lang/fr/) :
- **MAJOR** : Changements incompatibles
- **MINOR** : Nouvelles fonctionnalités compatibles
- **PATCH** : Corrections compatibles

---

## Prochaines Versions Planifiées

### [1.2.0] - À venir
- Vue de statistiques des couleurs apprises
- Export/Import des préférences
- Plus de préréglages (10 couleurs texte)

### [1.3.0] - À venir
- Synchronisation iCloud
- Mode à contraste élevé
- Thèmes prédéfinis

### [2.0.0] - Futur
- Détection automatique de logo
- IA générative pour palettes
- Partage communautaire de thèmes

---

## Notes de Migration

### De 1.0.0 à 1.1.0

**Modèle de données :**
- Migration automatique SwiftData
- Nouvelle propriété `textColor` avec valeur par défaut `#FFFFFF`
- Aucune action requise

**Code :**
- Si personnalisation de `VoucherCardView`, remplacer `.white` par `textColor`
- Vérifier les previews pour inclure `textColor`

**Utilisateurs :**
- Bons existants affichent texte blanc (par défaut)
- Possibilité de modifier via l'édition de bon

**Voir** : `MIGRATION-GUIDE-TEXT-COLOR.md` pour plus de détails

---

## Liens Utiles

- **Documentation complète** : Voir `INDEX.md`
- **Guide de démarrage** : Voir `START-HERE.md`
- **Guide de migration** : Voir `MIGRATION-GUIDE-TEXT-COLOR.md`
- **Améliorations futures** : Voir `TODO-IMPROVEMENTS.md`

---

**Maintenu par :** JEREMY  
**Dernière mise à jour :** 04/04/2026  
**Statut du projet :** ✅ Actif
