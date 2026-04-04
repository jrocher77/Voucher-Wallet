# 🎛️ Intégration des Réglages iOS

## 📋 Résumé

Cette fonctionnalité permet à l'utilisateur de gérer les données d'apprentissage automatique directement depuis l'application **Réglages** d'iOS (pas dans l'app Voucher Wallet).

## ✨ Fonctionnalités

### Dans Réglages iOS → Voucher Wallet

1. **Section "Apprentissage automatique"**
   - Explication du système d'apprentissage
   - Lien vers les statistiques détaillées

2. **Statistiques (sous-page)**
   - 📊 Nombre d'enseignes mémorisées
   - 🎨 Nombre de préférences de couleurs
   - 🥇🥈🥉 Top 3 des enseignes favorites (avec nombre de bons)

3. **Gestion des données**
   - ⚠️ Toggle "Demander réinitialisation"
   - Quand activé → l'app affiche une alerte de confirmation

4. **À propos**
   - Version de l'application

## 🚀 Installation rapide

### Étape 1 : Ajouter Settings.bundle dans Xcode

1. Dans Xcode, **File → New → File...**
2. Cherchez **"Settings Bundle"**
3. Cliquez **Create**
4. **Supprimez** le fichier `Root.plist` auto-généré
5. **Glissez-déposez** les fichiers suivants dans `Settings.bundle` :
   - `Root.plist` (créé par l'assistant)
   - `Statistics.plist` (créé par l'assistant)

### Étape 2 : Vérifier les fichiers Swift

Ces fichiers devraient déjà être présents dans votre projet :

- ✅ `UtilitiesSettingsManager.swift`
- ✅ `ModifiersSettingsMonitorModifier.swift`
- ✅ `ContentView.swift` (avec `.monitorSettingsChanges()`)
- ✅ `UtilitiesStoreNameLearning.swift` (mis à jour)

### Étape 3 : Tester

1. **Lancez l'app** sur simulateur ou appareil
2. **Quittez l'app** (balayez vers le haut)
3. Ouvrez **Réglages iOS**
4. Faites défiler jusqu'à **"Voucher Wallet"**
5. Vérifiez que les statistiques s'affichent ✨

## 🔄 Comment ça marche ?

### Flux de réinitialisation

```
┌─────────────────┐
│ Réglages iOS    │
│                 │
│ [X] Demander    │  ← L'utilisateur active le toggle
│     réinit.     │
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ UserDefaults    │
│ reset_learning_ │  ← La valeur passe à true
│ requested = true│
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ L'utilisateur   │
│ ouvre l'app     │  ← L'app devient active
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ SettingsMonitor │
│ Modifier        │  ← Détecte le changement dans scenePhase
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ SettingsManager │
│ .checkFor       │  ← Vérifie le toggle
│ ResetRequest()  │
└─────────────────┘
        │
        ▼
┌─────────────────┐
│ 🚨 Alerte       │
│ "Réinitialiser  │  ← Demande confirmation
│ l'apprentissage"│
└─────────────────┘
        │
        ├───── Annuler ─────┐
        │                   │
        ▼                   ▼
┌─────────────────┐  ┌─────────────────┐
│ Réinitialiser   │  │ Annuler         │
│ les données     │  │ (toggle → OFF)  │
└─────────────────┘  └─────────────────┘
        │                   
        ▼                   
┌─────────────────┐
│ Toggle → OFF    │
│ Stats → 0       │
└─────────────────┘
```

### Mise à jour automatique des statistiques

Les statistiques sont mises à jour :

1. **Quand l'app devient active** (via `scenePhase`)
2. **Quand une enseigne est apprise** (via `NotificationCenter`)
3. **Quand une couleur est apprise** (via `NotificationCenter`)
4. **Après une réinitialisation**

## 📁 Structure des fichiers

```
Settings.bundle/
├── Root.plist              # Page principale
└── Statistics.plist        # Sous-page statistiques

Utilities/
├── SettingsManager.swift           # Gestion des réglages iOS
└── StoreNameLearning.swift         # Apprentissage (mis à jour)

Modifiers/
└── SettingsMonitorModifier.swift   # Observer scenePhase

Views/
└── ContentView.swift               # Avec .monitorSettingsChanges()
```

## 🎯 Clés UserDefaults

| Clé | Type | Description |
|-----|------|-------------|
| `learned_stores_count` | `Int` | Nombre d'enseignes mémorisées |
| `color_preferences_count` | `Int` | Nombre de préférences de couleurs |
| `top_store_1` | `String` | 1ère enseigne favorite |
| `top_store_2` | `String` | 2ème enseigne favorite |
| `top_store_3` | `String` | 3ème enseigne favorite |
| `reset_learning_requested` | `Bool` | Demande de réinitialisation |
| `version_preference` | `String` | Version de l'app |

## 🧪 Débogage

### Vérifier les valeurs UserDefaults

```swift
// Dans la console Xcode ou un breakpoint
po UserDefaults.standard.dictionaryRepresentation().filter { $0.key.contains("learning") || $0.key.contains("store") }
```

### Forcer la mise à jour

```swift
// Dans votre code
SettingsManager.shared.updateSettingsStatistics()
```

### Réinitialiser manuellement

```swift
// Remettre le toggle à OFF
UserDefaults.standard.set(false, forKey: "reset_learning_requested")
```

## ⚠️ Points importants

1. **Les bons ne sont JAMAIS supprimés**
   - Seules les données d'apprentissage sont concernées
   
2. **Le toggle se désactive automatiquement**
   - Après confirmation ou annulation
   - Évite les demandes multiples
   
3. **Les statistiques sont en lecture seule**
   - Elles sont calculées automatiquement
   - Pas d'édition manuelle possible

4. **Settings.bundle doit être dans le projet**
   - Xcode l'inclura automatiquement dans l'app
   - Ne pas oublier de l'ajouter à la cible (target)

## 📚 Documentation complémentaire

Voir `SETTINGS-CONFIGURATION.md` pour plus de détails sur :
- La personnalisation des réglages
- Les types de contrôles disponibles
- Le débogage avancé
- La documentation Apple

## 🎨 Personnalisation

Pour modifier les réglages, éditez :

- `Settings.bundle/Root.plist` : Structure principale
- `Settings.bundle/Statistics.plist` : Page des statistiques
- `SettingsManager.swift` : Logique métier

Types de contrôles disponibles dans les `.plist` :
- `PSGroupSpecifier` : Titre de section
- `PSToggleSwitchSpecifier` : Interrupteur
- `PSTitleValueSpecifier` : Affichage lecture seule
- `PSChildPaneSpecifier` : Sous-page
- `PSTextFieldSpecifier` : Champ texte
- Et bien d'autres...

## 🆘 Problèmes fréquents

### Les réglages n'apparaissent pas dans Réglages iOS

- Vérifiez que `Settings.bundle` est bien dans le projet
- Vérifiez qu'il est coché dans la cible (Build Phases → Copy Bundle Resources)
- Relancez complètement l'app
- Sur simulateur : Reset Content and Settings

### Les statistiques ne se mettent pas à jour

- Vérifiez que le `NotificationCenter` est bien configuré
- Vérifiez que `.monitorSettingsChanges()` est appelé dans `ContentView`
- Lancez l'app, quittez, et réouvrez pour forcer la mise à jour

### Le toggle ne se remet pas à OFF

- Vérifiez que `performReset()` ou `cancelReset()` est bien appelé
- Vérifiez dans UserDefaults que la valeur change bien

---

**Prêt à tester !** 🚀
