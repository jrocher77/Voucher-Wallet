# 🎫 Voucher Wallet

Application iOS pour gérer et organiser vos bons d'achat numériquement, avec support des codes-barres et import PDF intelligent.

---

## 📱 Fonctionnalités

### ✨ Gestion des Bons
- **Ajout manuel** : Créez vos bons avec formulaire complet
- **Import PDF** : Analysez vos PDF de bons avec OCR (Vision Framework)
- **Co-branding Fnac/Darty** : Normalisation automatique en `Fnac / Darty` quand les deux enseignes sont détectées
- **Import multiple** : Détectez et importez plusieurs bons depuis un PDF
- **Codes-barres** : Génération automatique de QR codes et codes-barres Code128
- **Cartes colorées** : Chaque enseigne a sa couleur personnalisable
- **Personnalisation complète** : Couleur de fond ET de texte pour chaque bon

### 🎨 Personnalisation
- **Préréglages de couleurs** : 54 enseignes populaires pré-configurées
- **ColorPicker natif** : Choisissez n'importe quelle couleur
- **Couleur de texte** : Personnalisez la couleur du texte sur vos cartes
- **Validation de contraste** : Avertissement automatique si les couleurs sont trop similaires
- **Aperçu temps réel** : Visualisez le résultat instantanément

### 🧠 Apprentissage Automatique
- **Mémorisation des enseignes** : Le système apprend vos préférences
- **Suggestion de couleurs** : Couleurs pré-remplies pour les enseignes connues
- **Contraste intelligent** : Suggestion automatique de texte blanc/noir selon le fond
- **Gestion des mappings** : Noms détectés automatiquement mappés aux noms validés

### 🔍 Organisation
- **Filtres multi-critères** :
  - Recherche par nom d'enseigne
  - Filtrage par montant (min/max)
  - Tri par date d'expiration
- **Favoris rapides** : Ajout/retrait d'un favori directement depuis l'étoile sur la carte en écran d'accueil
- **États visuels** :
  - Badge "Expiré" automatique
  - Affichage du solde restant
  - Code PIN masqué/révélable

### 📊 Protection et Sécurité
- **Protection contre les doublons** : Détection automatique basée sur le numéro de bon
- **Avertissements visuels** : Indicateurs en temps réel lors de la saisie
- **Filtrage intelligent** : Import multiple avec exclusion automatique des doublons
- **Alertes récapitulatives** : Rapport détaillé des bons ignorés

### ⚙️ Réglages iOS
- **Statistiques d'apprentissage** : Consultez les données apprises
- **Réinitialisation** : Effacez les préférences apprises
- **Synchronisation** : Mise à jour automatique entre l'app et les Réglages
- **À propos** : Version et informations de l'app

---

## 🏗️ Architecture

### Modèles de Données (SwiftData)

```swift
@Model
class Voucher {
    var storeName: String
    var voucherNumber: String
    var pinCode: String?
    var amount: Double
    var remainingAmount: Double
    var expirationDate: Date
    var storeColor: String     // Couleur de fond (hex)
    var textColor: String      // Couleur de texte (hex) - NOUVEAU
    var creationDate: Date
    var note: String?
}
```

### Système d'Apprentissage

Le système d'apprentissage repose sur `StoreNameLearning` (singleton) :

#### Couleurs de fond
```swift
StoreNameLearning.shared.learnStoreColor("#FF6B6B", for: "Carrefour")
let color = StoreNameLearning.shared.getLearnedColor(for: "Carrefour")
```

#### Couleurs de texte (Extension)
```swift
StoreNameLearning.shared.learnTextColor("#FFFFFF", for: "Carrefour")
let textColor = StoreNameLearning.shared.getLearnedTextColor(for: "Carrefour")
```

#### Validation de contraste (WCAG)
```swift
let isGood = StoreNameLearning.shared.hasGoodContrast(
    backgroundColor: "#0055A5",
    textColor: "#FFFFFF"
)
// Retourne true si le ratio est ≥ 3:1
```

#### Suggestion automatique
```swift
let suggested = StoreNameLearning.shared.suggestTextColor(
    for: "#0055A5" // Fond bleu foncé
)
// Retourne "#FFFFFF" (blanc) car le fond est sombre
```

### Stockage
- **SwiftData** : Modèles de données persistants
- **UserDefaults** : Préférences d'apprentissage
  - `learnedStoreColors` : Dictionnaire `[String: String]`
  - `learnedTextColors` : Dictionnaire `[String: String]`
  - `learnedStoreMappings` : Dictionnaire `[String: String]`
  - `reset_learning_requested` : Toggle de réinitialisation

---

## 🎨 Validation de Contraste (WCAG 2.1)

### Standards Implémentés

| Niveau | Ratio Minimum | Description |
|--------|---------------|-------------|
| **A** | 3:1 | Minimum requis |
| **AA** | 4.5:1 | Recommandé |
| **AAA** | 7:1 | Optimal |

### Algorithmes

#### 1. Luminosité Relative (W3C)
```swift
func calculateLuminance(hex: String) -> Double {
    // Conversion hex → RGB
    // Normalisation 0-1
    // Linéarisation sRGB
    // Y = 0.2126*R + 0.7152*G + 0.0722*B
}
```

#### 2. Ratio de Contraste (WCAG)
```swift
func calculateContrastRatio(color1: String, color2: String) -> Double {
    let lum1 = calculateLuminance(hex: color1)
    let lum2 = calculateLuminance(hex: color2)
    let lighter = max(lum1, lum2)
    let darker = min(lum1, lum2)
    return (lighter + 0.05) / (darker + 0.05)
}
```

---

## 🛡️ Protection contre les Doublons

### Critère de Détection
Un bon est considéré comme un doublon si son **numéro de bon** (`voucherNumber`) existe déjà dans la base de données.

### Comportements

#### Saisie Manuelle
1. Avertissement visuel en temps réel
2. Bouton "Enregistrer" désactivé
3. Utilisateur doit modifier le numéro

#### Import Unique (1 bon dans le PDF)
1. Alerte modale si doublon détecté
2. Import annulé
3. Message : "Le bon avec le numéro XXX existe déjà"

#### Import Multiple (plusieurs bons dans le PDF)
1. Filtrage automatique des doublons
2. Import des bons valides uniquement
3. Alerte récapitulative listant les doublons ignorés
4. Console : "✅ X bon(s) importé(s), ⚠️ Y doublon(s) ignoré(s)"

### Implémentation

```swift
@Query private var existingVouchers: [Voucher]

private func isVoucherNumberDuplicate(_ number: String) -> Bool {
    existingVouchers.contains { $0.voucherNumber == number }
}
```

### Fichiers Concernés
- `ViewsAddVoucherView.swift`
- `ViewComponentsMultiVoucherList.swift`
- `ViewComponentsVoucherEditorView.swift`

---

## 📦 Structure du Projet

```
Voucher Wallet/
│
├── 📱 App
│   └── Voucher_WalletApp.swift
│
├── 🗂️ Models
│   ├── Voucher.swift
│   ├── StorePreset.swift
│   └── Expense.swift
│
├── 🎨 Views
│   ├── Main Views
│   │   ├── ContentView.swift
│   │   ├── VoucherCardView.swift
│   │   ├── VoucherDetailView.swift
│   │   ├── AddVoucherView.swift
│   │   └── EditVoucherView.swift
│   │
│   ├── Import & Selection
│   │   ├── AddVoucherView.swift (flux unique: ajout manuel + PDF + partage)
│   │   └── ViewComponentsMultiVoucherList.swift
│   │
│   ├── Expenses
│   │   ├── AddExpenseView.swift
│   │   └── ExpenseListView.swift
│   │
│   └── Stats & Demo
│       ├── TextColorExampleView.swift
│       └── AppIconShowcase.swift
│
├── 🛠️ Utilities
│   ├── Generators & Analyzers
│   │   ├── BarcodeGenerator.swift
│   │   └── PDFAnalyzer.swift
│   │
│   ├── Learning System
│   │   ├── StoreNameLearning.swift
│   │   └── StoreNameLearning+TextColor.swift
│   │
│   ├── Settings
│   │   └── SettingsManager.swift
│   │
│   └── Extensions
│       ├── Color+Extensions.swift
│       ├── Date+Extensions.swift
│       └── Double+Extensions.swift
│
├── 🎯 Modifiers
│   └── SettingsMonitorModifier.swift
│
├── 📦 Settings.bundle
│   ├── Root.plist
│   └── Statistics.plist
│
└── 🎨 Assets
    └── Assets.xcassets
```

---

## 🚀 Installation et Configuration

### Prérequis
- **Xcode 15.0+**
- **iOS 17.0+** (pour SwiftData)
- **Swift 5.9+**

### 1. Cloner le projet
```bash
git clone [URL_DU_REPO]
cd Voucher-Wallet
```

### 2. Ouvrir dans Xcode
```bash
open "Voucher Wallet.xcodeproj"
```

### 3. Configurer Info.plist

Assurez-vous que les permissions suivantes sont présentes :

```xml
<key>NSCameraUsageDescription</key>
<string>Pour scanner les codes-barres de vos bons d'achat</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Pour accéder aux PDF de vos bons d'achat</string>

<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeIdentifier</key>
        <string>com.adobe.pdf</string>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
        </array>
    </dict>
</array>
```

### 4. Build et Run
```
Cmd + R
```

---

## 🧪 Tests et Débogage

### Vue de Démonstration

`TextColorExampleView` fournit 8 exemples de combinaisons de couleurs :

```swift
NavigationLink {
    TextColorExampleView()
} label: {
    Label("Exemples de couleurs", systemImage: "paintpalette")
}
```

### Tests Recommandés

#### Test 1 : Création de bon avec validation
1. Créer un bon "Test"
2. Fond : blanc (#FFFFFF)
3. Texte : blanc (#FFFFFF)
4. ✅ Vérifier l'avertissement de contraste faible

#### Test 2 : Apprentissage automatique
1. Créer "Carrefour" avec fond bleu (#0055A5) et texte blanc
2. Créer un nouveau bon "Carrefour"
3. ✅ Vérifier que les couleurs sont pré-remplies

#### Test 3 : Import PDF avec doublon
1. Importer un PDF
2. Réimporter le même PDF
3. ✅ Vérifier l'alerte de doublon

#### Test 4 : Réglages iOS
1. Créer quelques bons
2. Ouvrir Réglages iOS → Voucher Wallet
3. ✅ Vérifier les statistiques
4. Activer "Réinitialiser"
5. Retourner dans l'app
6. ✅ Vérifier l'alerte de réinitialisation

### Logs de Débogage

Les logs suivants sont générés :

```
✅ X bon(s) importé(s) avec succès
⚠️ Y doublon(s) ignoré(s)
📊 Statistiques mises à jour
🔔 Notification de réinitialisation reçue
```

---

## 🎯 Fonctionnalités Clés par Fichier

### VoucherCardView.swift
- Affichage style Apple Wallet
- Couleurs personnalisées (fond + texte)
- Badge "Expiré"
- Montant restant

### AddVoucherView.swift
- Formulaire de création
- Sélection de couleurs (fond + texte)
- Validation de contraste
- Aperçu temps réel
- Protection contre les doublons (saisie manuelle)
- Import PDF simple et multiple

### EditVoucherView.swift
- Modification de bon existant
- Sélection de couleurs
- Validation de contraste
- Aperçu temps réel

### PDFAnalyzer.swift
- OCR avec Vision Framework
- Détection de codes-barres
- Extraction de :
  - Numéros de bon
  - Codes PIN
  - Montants
  - Dates d'expiration

### StoreNameLearning.swift
- Singleton d'apprentissage
- Mémorisation des couleurs
- Mappings de noms
- Statistiques

### StoreNameLearning+TextColor.swift
- Extension pour couleurs de texte
- Validation de contraste WCAG
- Suggestion automatique
- Algorithmes de luminosité

---

## 🔮 Améliorations Futures

### Court Terme
- [ ] Vue de statistiques des couleurs apprises
- [ ] Export/Import des préférences
- [ ] Plus de préréglages de couleurs

### Moyen Terme
- [ ] Synchronisation iCloud
- [ ] Mode à contraste élevé avancé
- [ ] Thèmes prédéfinis (luxe, sport, tech)
- [ ] Détection automatique de logo (Vision)

### Long Terme
- [ ] IA générative pour palettes
- [ ] Partage de thèmes entre utilisateurs
- [ ] Support Apple Wallet avec couleurs personnalisées
- [ ] Widgets pour l'écran d'accueil

---

## 📊 Métriques du Projet

### Code
- **Fichiers Swift** : ~30
- **Lignes de code** : ~3000
- **Modèles SwiftData** : 2 (Voucher, Expense)
- **Vues principales** : 10+
- **Extensions** : 4

### Fonctionnalités
- **ColorPickers** : 2 par formulaire
- **Préréglages** : 54 enseignes + couleurs de texte associées
- **Algorithmes** : 3 (luminosité, contraste, suggestion)
- **Notifications** : 1 (réinitialisation)

---

## 🤝 Contribution

### Guidelines
1. Utiliser SwiftUI et Swift Concurrency (async/await)
2. Respecter l'architecture MVC
3. Documenter les nouvelles fonctionnalités
4. Tester sur iOS 17.0 minimum
5. Ajouter des Previews SwiftUI

### Tests
- Tester sur simulateur et appareil réel
- Vérifier les cas limites (doublons, contraste, etc.)
- Valider l'accessibilité (VoiceOver, Dynamic Type)

---

## 📞 Support

### Problèmes Connus
- Les statistiques peuvent mettre quelques secondes à se synchroniser
- Le ColorPicker ne supporte pas l'opacité (volontaire)
- L'OCR peut échouer sur certains PDF très complexes

### Résolution
1. Vérifier les logs de débogage dans la console Xcode
2. Nettoyer le build folder (⇧⌘K)
3. Supprimer l'app du simulateur et réinstaller
4. Vérifier que toutes les permissions Info.plist sont présentes

---

## 📄 Licence

Ce projet est un exemple éducatif.

---

## ✨ Crédits

**Développé par** : JEREMY  
**Date de création** : Avril 2026  
**Version actuelle** : 1.1.0  
**Statut** : ✅ Production Ready

---

## 🎉 Remerciements

- **Apple** pour SwiftUI, SwiftData et Vision Framework
- **WCAG** pour les standards d'accessibilité
- **W3C** pour les algorithmes de luminosité

---

**Profitez de vos bons d'achat numériques ! 🎫✨**
