# CLAUDE.md — Voucher Wallet

## Présentation du projet

Application iOS native de gestion de bons d'achat (gift cards, coupons). Permet d'importer des PDFs, d'extraire automatiquement les informations via OCR, de générer des codes-barres/QR, et de personnaliser l'affichage des cartes.

**Stack :** Swift + SwiftUI + SwiftData + PDFKit + Vision Framework
**Cible iOS :** 17.0 minimum (requis pour SwiftData)
**Langue de l'interface :** Français
**Pas de dépendances externes** — uniquement des frameworks Apple natifs

---

## Build & Run

```bash
# Ouvrir dans Xcode, puis :
Cmd + R   # Build + lancer dans le simulateur
Cmd + B   # Build uniquement
```

Pas de CocoaPods, SPM, ni scripts de build automatisés.

---

## Architecture

Pattern **MVVM** avec gestion d'état SwiftUI.

```
Voucher Wallet/
├── Models/          ModelsVoucher.swift, ModelsExpense.swift, ModelsStorePreset.swift
├── Views/           Views*.swift (toutes les vues SwiftUI)
├── Utilities/       Utilities*.swift (logique métier, analyse PDF, générateurs)
├── Modifiers/       Modifiers*.swift (view modifiers SwiftUI)
├── Previews/        Previews*.swift + UtilitiesPreviewData.swift
└── Settings.bundle/ Configuration iOS Settings natif
```

### Conventions de nommage des fichiers

| Préfixe | Usage |
|---------|-------|
| `Views*.swift` | Vues SwiftUI |
| `Models*.swift` | Modèles SwiftData |
| `Utilities*.swift` | Logique métier, helpers |
| `Modifiers*.swift` | View modifiers SwiftUI |
| `Previews*.swift` | Configurations de preview |

### Persistance des données

- **SwiftData** — données principales (Voucher, Expense)
- **UserDefaults** — préférences et données du système d'apprentissage
- **PDFs embarqués** — stockés en tant que `Data` dans le modèle `Voucher`

### Singletons

- `StoreNameLearning.shared` — apprentissage des noms de magasins
- `SettingsManager.shared` — pont entre l'app et iOS Settings

---

## Fichiers clés

| Fichier | Rôle |
|---------|------|
| `Voucher_WalletApp.swift` | Point d'entrée, init ModelContainer, URLHandler |
| `ContentView.swift` | Liste principale des bons d'achat |
| `ViewsAddVoucherView.swift` | Import PDF + saisie manuelle (1 169 lignes) |
| `ViewsVoucherDetailView.swift` | Détail avec barcode/QR, historique dépenses |
| `ViewsVoucherCardView.swift` | Composant carte style Wallet |
| `UtilitiesPDFAnalyzer.swift` | Analyse PDF via Vision (OCR + détection codes) |
| `UtilitiesBarcodeGenerator.swift` | Génération Code128 et QR via CoreImage |
| `UtilitiesStoreNameLearning.swift` | Apprentissage noms de magasins (UserDefaults) |
| `UtilitiesStoreNameLearning+TextColor.swift` | Apprentissage couleur texte, calcul contraste WCAG |
| `URLHandler.swift` | Gestion deep links / partage de PDF depuis d'autres apps |

---

## Patterns à respecter

### Gestion d'état SwiftUI
- `@State` pour l'état local d'une vue
- `@Query` pour les requêtes SwiftData
- `@Environment(\.modelContext)` pour le contexte de persistance
- `@Observable` pour les classes observables (URLHandler)

### Couleurs et accessibilité
- Toujours valider le contraste couleur fond/texte selon **WCAG 2.1**
- Utiliser `hasGoodContrast()` de `StoreNameLearning+TextColor` avant de proposer une couleur
- Les `StorePreset` définissent les couleurs par défaut pour ~15 enseignes françaises

### Analyse PDF (async/await)
- `PDFAnalyzer` utilise `async/await` avec callbacks de progression
- Ne pas bloquer le thread principal — toujours appeler depuis une `Task {}`

### Pas de tests unitaires automatisés
- Les tests passent par les **SwiftUI Previews** (`#Preview`)
- `UtilitiesPreviewData.swift` fournit les données de preview

---

## À ne pas faire

- Ne pas introduire de dépendances externes (CocoaPods, SPM tiers) sans discussion
- Ne pas descendre la cible iOS sous 17.0 (SwiftData requis)
- Ne pas contourner la validation de contraste WCAG pour les couleurs
- Ne pas accéder aux fichiers PDF sans `startAccessingSecurityScopedResource()` / `stopAccessingSecurityScopedResource()`
- Ne pas générer de fichiers .MD à chaque ajout de fonctionnalité ou chaque modification du code.
