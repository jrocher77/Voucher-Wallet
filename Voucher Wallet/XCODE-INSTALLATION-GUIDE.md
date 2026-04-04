# 🛠️ Guide d'installation du Settings.bundle dans Xcode

## Étape par étape avec captures visuelles

### Étape 1 : Créer le Settings Bundle

1. **Ouvrez Xcode** et votre projet Voucher Wallet

2. **Clic droit** sur le dossier principal du projet (celui avec l'icône bleue)
   ```
   Voucher Wallet
   ├── Views
   ├── Models
   ├── Utilities
   └── ...
   ```

3. Sélectionnez **File → New → File...** (ou **⌘N**)

4. Dans la fenêtre qui apparaît :
   - Tapez "settings" dans la barre de recherche
   - Sélectionnez **Settings Bundle** (sous "Resource")
   - Cliquez sur **Next**

5. Laissez le nom par défaut `Settings.bundle`
   - Cliquez sur **Create**

✅ **Résultat** : Un dossier `Settings.bundle` apparaît dans votre projet avec un fichier `Root.plist` par défaut.

---

### Étape 2 : Remplacer Root.plist

Le fichier `Root.plist` généré par défaut n'est pas celui que nous voulons.

1. **Supprimez** le fichier `Root.plist` actuel :
   - Sélectionnez `Root.plist` dans `Settings.bundle`
   - Clic droit → **Delete**
   - Choisissez **Move to Trash**

2. **Ajoutez le nouveau Root.plist** :
   - Localisez le fichier `Root.plist` que l'assistant a créé (dans votre dossier de travail)
   - **Glissez-déposez** ce fichier dans `Settings.bundle` dans Xcode
   
3. Dans la fenêtre qui apparaît :
   - ✅ Cochez **Copy items if needed**
   - ✅ Sélectionnez **Voucher Wallet** dans "Add to targets"
   - Cliquez sur **Finish**

---

### Étape 3 : Ajouter Statistics.plist

1. **Clic droit** sur `Settings.bundle` dans le navigateur de projet

2. Sélectionnez **Add Files to "Settings.bundle"...**

3. **Naviguez** jusqu'au fichier `Statistics.plist` créé par l'assistant

4. **Sélectionnez** `Statistics.plist` et cliquez **Add**

5. Dans les options :
   - ✅ Cochez **Copy items if needed**
   - ✅ Assurez-vous que "Added folders" est sur **Create groups**
   - Cliquez sur **Add**

✅ **Résultat** : Votre `Settings.bundle` contient maintenant :
```
Settings.bundle
├── Root.plist
└── Statistics.plist
```

---

### Étape 4 : Vérifier la structure dans Xcode

Votre navigateur de projet devrait ressembler à :

```
📁 Voucher Wallet
├── 📁 Views
│   ├── ContentView.swift          ← (Déjà modifié)
│   ├── SettingsView.swift
│   └── ...
├── 📁 Models
│   └── ...
├── 📁 Utilities
│   ├── SettingsManager.swift      ← (Nouveau)
│   ├── StoreNameLearning.swift    ← (Modifié)
│   └── ...
├── 📁 Modifiers
│   ├── SettingsMonitorModifier.swift  ← (Nouveau)
│   └── ...
├── 📦 Settings.bundle              ← (Nouveau bundle)
│   ├── Root.plist
│   └── Statistics.plist
└── ...
```

---

### Étape 5 : Vérifier que Settings.bundle est inclus dans la cible

1. **Sélectionnez** `Settings.bundle` dans le navigateur de projet

2. Dans **l'inspecteur de fichiers** (panneau de droite) :
   - Vérifiez la section **Target Membership**
   - ✅ **Voucher Wallet** doit être coché

3. Si ce n'est pas coché :
   - Cochez la case **Voucher Wallet**

---

### Étape 6 : Construire et tester

1. **Sélectionnez un simulateur** ou un appareil

2. **Lancez l'application** (⌘R)
   - L'app doit se lancer sans erreur
   - Vous pouvez la fermer directement

3. **Ouvrez l'app Réglages** sur le simulateur/appareil

4. **Faites défiler** vers le bas jusqu'à voir :
   ```
   App Store
   Books
   ...
   Voucher Wallet  ←  🎉 C'est ici !
   ```

5. **Tapez** sur "Voucher Wallet"

6. **Vérifiez** que vous voyez :
   - Section "Apprentissage automatique"
   - Bouton "Statistiques >"
   - Section "Gestion des données"
   - Toggle "Demander réinitialisation"
   - Section "À propos" avec version

✅ **Si tout est là : c'est parfait ! 🎉**

---

### Étape 7 : Tester le flux complet

1. **Dans l'app Voucher Wallet** :
   - Ajoutez quelques bons d'achat
   - Validez des noms d'enseignes
   - Choisissez des couleurs

2. **Retournez dans Réglages iOS** :
   - Voucher Wallet → Statistiques
   - Vérifiez que les chiffres ont changé (pas à 0)

3. **Testez la réinitialisation** :
   - Activez le toggle "Demander réinitialisation"
   - Retournez dans Voucher Wallet (l'app)
   - Une alerte devrait apparaître
   - Testez "Annuler" → le toggle repasse à OFF
   - Réactivez le toggle et testez "Réinitialiser"
   - Vérifiez dans Réglages que les stats sont à 0

✅ **Tout fonctionne ? Bravo ! 🎊**

---

## 🆘 Résolution de problèmes

### Problème : "Voucher Wallet" n'apparaît pas dans Réglages iOS

**Solutions** :

1. **Vérifiez que Settings.bundle est dans le projet**
   - Il doit être visible dans le navigateur de projet
   
2. **Vérifiez Target Membership**
   - Sélectionnez Settings.bundle
   - Inspecteur de fichiers → Target Membership
   - Cochez "Voucher Wallet"

3. **Vérifiez Build Phases**
   - Sélectionnez le projet (icône bleue en haut)
   - Target "Voucher Wallet"
   - Onglet "Build Phases"
   - "Copy Bundle Resources"
   - Settings.bundle doit être dans la liste
   - Si absent, cliquez sur "+" et ajoutez-le

4. **Nettoyez et reconstruisez**
   - Product → Clean Build Folder (⇧⌘K)
   - Product → Build (⌘B)
   - Relancez l'app

5. **Sur simulateur uniquement**
   - Device → Erase All Content and Settings
   - Relancez l'app

### Problème : Les statistiques ne se mettent pas à jour

**Solutions** :

1. **Vérifiez que ContentView a le modifier**
   ```swift
   .monitorSettingsChanges()
   ```

2. **Vérifiez les fichiers Swift**
   - UtilitiesSettingsManager.swift présent
   - ModifiersSettingsMonitorModifier.swift présent
   - StoreNameLearning.swift avec les notifications

3. **Forcez la mise à jour**
   - Quittez complètement l'app (balayez vers le haut)
   - Relancez l'app
   - Retournez dans Réglages

### Problème : Le toggle ne déclenche rien

**Solutions** :

1. **Vérifiez le nom de la clé dans Root.plist**
   - Doit être : `reset_learning_requested`

2. **Vérifiez que c'est un PSToggleSwitchSpecifier**
   - Pas un PSTitleValueSpecifier

3. **Testez manuellement**
   ```swift
   // Dans un breakpoint ou la console
   po UserDefaults.standard.bool(forKey: "reset_learning_requested")
   ```

### Problème : Erreur de compilation

**Solutions** :

1. **Vérifiez les imports**
   ```swift
   import SwiftUI
   import Foundation
   ```

2. **Vérifiez que tous les fichiers sont dans la cible**
   - SettingsManager.swift
   - SettingsMonitorModifier.swift
   - Tous doivent avoir Target Membership coché

---

## 📝 Checklist finale

Avant de considérer l'installation comme terminée, vérifiez :

- [ ] Settings.bundle existe dans le projet
- [ ] Root.plist est présent dans Settings.bundle
- [ ] Statistics.plist est présent dans Settings.bundle
- [ ] UtilitiesSettingsManager.swift est dans le projet
- [ ] ModifiersSettingsMonitorModifier.swift est dans le projet
- [ ] ContentView.swift contient `.monitorSettingsChanges()`
- [ ] StoreNameLearning.swift envoie les notifications
- [ ] L'app compile sans erreur
- [ ] "Voucher Wallet" apparaît dans Réglages iOS
- [ ] Les statistiques s'affichent correctement
- [ ] Le toggle de réinitialisation fonctionne
- [ ] Les statistiques se mettent à jour automatiquement

---

## 🎓 Ressources supplémentaires

- **README-SETTINGS.md** : Vue d'ensemble du système
- **SETTINGS-CONFIGURATION.md** : Configuration détaillée
- **SETTINGS-PREVIEW.md** : Aperçu visuel des réglages
- **verify-settings-setup.sh** : Script de vérification automatique

Pour exécuter le script de vérification :
```bash
cd /path/to/project
chmod +x verify-settings-setup.sh
./verify-settings-setup.sh
```

---

**Bon développement ! 🚀**
