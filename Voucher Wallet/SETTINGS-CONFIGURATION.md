# Configuration des Réglages iOS

Ce document explique comment configurer le `Settings.bundle` pour afficher les paramètres de l'application dans l'app Réglages iOS.

## 📁 Structure des fichiers

Les fichiers suivants ont été créés pour gérer les réglages iOS :

```
Settings.bundle/
├── Root.plist          # Page principale des réglages
└── Statistics.plist    # Sous-page des statistiques

Utilities/
└── SettingsManager.swift   # Gestionnaire de synchronisation

Modifiers/
└── SettingsMonitorModifier.swift   # Modifier SwiftUI pour surveiller les changements
```

## 🔧 Installation dans Xcode

### Étape 1 : Ajouter le Settings.bundle au projet

1. **Créer le bundle Settings** :
   - Dans Xcode, cliquez droit sur le dossier principal du projet
   - Sélectionnez **New File...**
   - Recherchez "Settings Bundle" dans les templates
   - Cliquez sur **Next** puis **Create**

2. **Remplacer Root.plist** :
   - Supprimez le fichier `Root.plist` généré automatiquement
   - Ajoutez le fichier `Root.plist` créé (depuis le dossier `Settings.bundle/`)

3. **Ajouter Statistics.plist** :
   - Faites un clic droit sur `Settings.bundle` dans Xcode
   - Sélectionnez **Add Files to "Settings.bundle"...**
   - Ajoutez le fichier `Statistics.plist`

### Étape 2 : Vérifier l'intégration

Les fichiers suivants devraient déjà être intégrés :
- ✅ `UtilitiesSettingsManager.swift`
- ✅ `ModifiersSettingsMonitorModifier.swift`
- ✅ `ContentView.swift` (mis à jour avec `.monitorSettingsChanges()`)

## 🎯 Fonctionnalités

### Dans les Réglages iOS

L'utilisateur peut accéder à :

1. **Statistiques d'apprentissage** :
   - Nombre d'enseignes mémorisées
   - Nombre de préférences de couleurs
   - Top 3 des enseignes favorites

2. **Réinitialisation** :
   - Toggle "Demander réinitialisation"
   - Lorsqu'il est activé, l'app affichera une alerte de confirmation au prochain lancement

### Dans l'application

- Les statistiques sont **mises à jour automatiquement** quand l'app devient active
- Lorsque l'utilisateur active le toggle de réinitialisation dans les Réglages iOS :
  1. L'app détecte le changement au prochain lancement
  2. Une alerte de confirmation s'affiche
  3. Si confirmé : les données sont supprimées et le toggle est remis à OFF
  4. Si annulé : le toggle est remis à OFF sans supprimer les données

## 🔄 Mise à jour des statistiques

Les statistiques sont automatiquement mises à jour via le `SettingsMonitorModifier` :

```swift
.monitorSettingsChanges() // Ajouté au ContentView
```

Ce modifier :
- Surveille les changements de `scenePhase`
- Met à jour les statistiques quand l'app devient active
- Détecte les demandes de réinitialisation
- Affiche les alertes de confirmation

## 🧪 Test

Pour tester la fonctionnalité :

1. **Lancez l'application** pour initialiser les réglages
2. **Quittez l'app** et ouvrez **Réglages iOS**
3. **Faites défiler** jusqu'à trouver "Voucher Wallet"
4. **Vérifiez** que les statistiques s'affichent
5. **Activez** le toggle "Demander réinitialisation"
6. **Retournez dans l'app** → une alerte devrait apparaître
7. **Testez** les deux options (Annuler / Réinitialiser)

## 📝 Notes importantes

- Les bons d'achat ne sont **jamais supprimés** lors de la réinitialisation
- Seules les données d'apprentissage sont concernées :
  - Enseignes mémorisées
  - Préférences de couleurs
  - Associations de noms
  - Compteurs d'utilisation

## 🔍 Débogage

Pour vérifier les valeurs dans UserDefaults :

```swift
// Dans la console Xcode
po UserDefaults.standard.dictionaryRepresentation()
```

Clés utilisées :
- `learned_stores_count` : Nombre d'enseignes mémorisées
- `color_preferences_count` : Nombre de préférences de couleurs
- `top_store_1/2/3` : Enseignes favorites
- `reset_learning_requested` : Toggle de réinitialisation
- `version_preference` : Version de l'app

## 🎨 Personnalisation

Pour modifier les réglages :

1. **Root.plist** : Modifier la structure principale
2. **Statistics.plist** : Ajouter/retirer des statistiques
3. **SettingsManager.swift** : Ajouter de nouvelles clés ou logique

Types de contrôles disponibles :
- `PSGroupSpecifier` : Titre de section
- `PSToggleSwitchSpecifier` : Interrupteur ON/OFF
- `PSTitleValueSpecifier` : Affichage lecture seule
- `PSTextFieldSpecifier` : Champ de texte
- `PSSliderSpecifier` : Curseur
- `PSMultiValueSpecifier` : Liste de choix
- `PSChildPaneSpecifier` : Sous-page

Documentation Apple : https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/UserDefaults/
