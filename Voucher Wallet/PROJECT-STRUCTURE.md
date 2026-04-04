# 📂 Arborescence du projet - Réglages iOS

## Vue d'ensemble de la structure

```
Voucher Wallet/
│
├── 📱 App
│   ├── VoucherWalletApp.swift
│   └── ...
│
├── 🎨 Views
│   ├── ContentView.swift                    ← Modifié (.monitorSettingsChanges)
│   ├── SettingsView.swift                   ← Original (réglages in-app)
│   ├── AddVoucherView.swift
│   ├── VoucherDetailView.swift
│   └── ...
│
├── 🧩 Models
│   ├── Voucher.swift
│   └── ...
│
├── 🛠️ Utilities
│   ├── SettingsManager.swift                ← ✨ NOUVEAU
│   ├── StoreNameLearning.swift              ← Modifié (notifications)
│   ├── PDFAnalyzer.swift
│   └── ...
│
├── 🎭 Modifiers
│   ├── SettingsMonitorModifier.swift        ← ✨ NOUVEAU
│   └── ...
│
├── ⚙️ Settings.bundle                        ← ✨ NOUVEAU DOSSIER
│   ├── Root.plist                           ← Configuration principale
│   └── Statistics.plist                     ← Configuration statistiques
│
├── 📚 Documentation
│   ├── README-SETTINGS.md                   ← ✨ NOUVEAU
│   ├── SETTINGS-CONFIGURATION.md            ← ✨ NOUVEAU
│   ├── SETTINGS-PREVIEW.md                  ← ✨ NOUVEAU
│   ├── XCODE-INSTALLATION-GUIDE.md          ← ✨ NOUVEAU
│   ├── INSTALLATION-CHECKLIST.md            ← ✨ NOUVEAU
│   ├── QUICK-START.md                       ← ✨ NOUVEAU
│   └── ...
│
├── 🧪 Scripts
│   ├── verify-settings-setup.sh             ← ✨ NOUVEAU
│   └── ...
│
└── 📄 Autres
    ├── Info.plist
    ├── Assets.xcassets
    └── ...
```

## Fichiers nouveaux vs modifiés

### ✨ Fichiers créés (nouveaux)

```
✅ Settings.bundle/
   ├── Root.plist                     # Configuration réglages iOS
   └── Statistics.plist               # Configuration statistiques

✅ Utilities/
   └── SettingsManager.swift          # Gestionnaire réglages iOS

✅ Modifiers/
   └── SettingsMonitorModifier.swift  # Observer changements

✅ Documentation/
   ├── README-SETTINGS.md             # Vue d'ensemble
   ├── SETTINGS-CONFIGURATION.md      # Configuration détaillée
   ├── SETTINGS-PREVIEW.md            # Aperçu visuel
   ├── XCODE-INSTALLATION-GUIDE.md    # Guide installation
   ├── INSTALLATION-CHECKLIST.md      # Checklist
   └── QUICK-START.md                 # Démarrage rapide

✅ Scripts/
   └── verify-settings-setup.sh       # Vérification auto
```

### 📝 Fichiers modifiés

```
🔄 Views/
   └── ContentView.swift
       → Ajout de : .monitorSettingsChanges()

🔄 Utilities/
   └── StoreNameLearning.swift
       → Ajout de : updateSettingsStatistics()
       → Ajout de : notification learningDataDidChange
```

## Dépendances entre fichiers

### Flux de données

```
┌─────────────────────────────────────────────────────┐
│                   Réglages iOS                      │
│                                                     │
│  Settings.bundle/                                   │
│  ├── Root.plist           ← Définit l'UI           │
│  └── Statistics.plist     ← Définit les stats      │
│                                                     │
│  Stockage : UserDefaults                           │
│  Clés : reset_learning_requested, etc.             │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│              SettingsManager.swift                  │
│                                                     │
│  • Lit les valeurs UserDefaults                    │
│  • Met à jour les statistiques                     │
│  • Détecte demande réinitialisation                │
│  • Effectue la réinitialisation                    │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│        SettingsMonitorModifier.swift                │
│                                                     │
│  • Observe scenePhase (app devient active)         │
│  • Appelle SettingsManager.checkForResetRequest()  │
│  • Affiche les alertes de confirmation             │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│                ContentView.swift                    │
│                                                     │
│  • Applique .monitorSettingsChanges()              │
│  • Point d'entrée de l'app                         │
└─────────────────────────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────┐
│           StoreNameLearning.swift                   │
│                                                     │
│  • Stocke les données d'apprentissage              │
│  • Envoie notification learningDataDidChange       │
│  • SettingsManager écoute et met à jour stats      │
└─────────────────────────────────────────────────────┘
```

## Flux d'exécution

### Au démarrage de l'app

```
1. VoucherWalletApp.swift
   └─> ContentView.swift
       └─> .monitorSettingsChanges()
           └─> SettingsMonitorModifier
               ├─> SettingsManager.shared (init)
               │   └─> Enregistre observers
               │
               └─> onChange(scenePhase)
                   └─> SettingsManager.refreshOnAppActivation()
                       ├─> updateSettingsStatistics()
                       └─> checkForResetRequest()
                           └─> shouldShowResetConfirmation = true
                               └─> Alert s'affiche
```

### Quand l'utilisateur apprend une enseigne

```
1. AddVoucherView.swift
   └─> User valide une enseigne
       └─> StoreNameLearning.learnStoreName(...)
           ├─> Sauvegarde dans UserDefaults
           ├─> Incrémente compteurs
           └─> updateSettingsStatistics()
               └─> NotificationCenter.post(.learningDataDidChange)
                   └─> SettingsManager.learningDataDidChange()
                       └─> updateSettingsStatistics()
                           └─> Met à jour UserDefaults pour Réglages iOS
```

### Quand l'utilisateur demande réinitialisation

```
1. Réglages iOS
   └─> Toggle activé
       └─> UserDefaults["reset_learning_requested"] = true

2. User ouvre Voucher Wallet
   └─> ContentView.monitorSettingsChanges()
       └─> scenePhase devient .active
           └─> SettingsManager.checkForResetRequest()
               └─> Lit UserDefaults["reset_learning_requested"]
                   └─> = true → shouldShowResetConfirmation = true

3. Alert s'affiche
   ├─> Annuler
   │   └─> SettingsManager.cancelReset()
   │       └─> UserDefaults["reset_learning_requested"] = false
   │
   └─> Confirmer
       └─> SettingsManager.performReset()
           ├─> StoreNameLearning.resetLearningData()
           ├─> UserDefaults["reset_learning_requested"] = false
           └─> updateSettingsStatistics() → tout à 0
```

## Tailles approximatives des fichiers

```
Settings.bundle/Root.plist              ~2 KB
Settings.bundle/Statistics.plist        ~1.5 KB
SettingsManager.swift                   ~5 KB
SettingsMonitorModifier.swift           ~2 KB
ContentView.swift (modification)        +1 ligne
StoreNameLearning.swift (modification)  +15 lignes

Total nouveau code : ~10 KB
Total documentation : ~50 KB
```

## Points d'intégration avec le code existant

### 1. ContentView.swift

```swift
// Avant
var body: some View {
    NavigationStack {
        // ...
    }
}

// Après
var body: some View {
    NavigationStack {
        // ...
    }
    .monitorSettingsChanges()  ← Ajout de cette ligne
}
```

### 2. StoreNameLearning.swift

```swift
// Avant
func learnStoreName(...) {
    // ... logique existante
}

// Après
func learnStoreName(...) {
    // ... logique existante
    updateSettingsStatistics()  ← Ajout
}

// Nouvelle méthode
private func updateSettingsStatistics() {
    NotificationCenter.default.post(
        name: .learningDataDidChange, 
        object: nil
    )
}
```

## Dépendances externes

### Frameworks utilisés

```swift
import SwiftUI         // Pour les vues et modifiers
import Foundation      // Pour UserDefaults, NotificationCenter
```

**Aucune dépendance externe supplémentaire** ✅

## Impact sur la taille de l'app

```
Settings.bundle     : +3.5 KB
Code Swift          : +10 KB
─────────────────────────────
Total               : ~13.5 KB
```

**Impact négligeable** ✅

## Compatibilité

```
iOS 17.0+           ✅
SwiftUI             ✅
UserDefaults        ✅ (système standard iOS)
NotificationCenter  ✅ (système standard iOS)
Settings.bundle     ✅ (supporté depuis iOS 2.0)
```

## Résumé

| Aspect | Valeur |
|--------|--------|
| Nouveaux fichiers | 9 |
| Fichiers modifiés | 2 |
| Lignes de code ajoutées | ~200 |
| Taille totale | ~13.5 KB |
| Frameworks supplémentaires | 0 |
| Impact performance | Minimal |
| Compatibilité | iOS 17.0+ |

---

**Architecture propre et modulaire** ✅
**Aucune dépendance externe** ✅
**Impact minimal** ✅
