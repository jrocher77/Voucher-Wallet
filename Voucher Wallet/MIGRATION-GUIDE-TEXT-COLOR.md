# 🔄 Guide de Migration : Ajout de la Couleur de Texte

## 📋 Checklist de Migration

### ✅ Modifications automatiques (SwiftData)
- [x] Migration du modèle Voucher
- [x] Valeur par défaut : `#FFFFFF` (blanc)
- [x] Aucune action requise de votre part

### ✅ Fichiers à ajouter au projet Xcode

#### Nouveaux fichiers Swift
1. `UtilitiesStoreNameLearning+TextColor.swift`
   - Extension de StoreNameLearning
   - Gestion des couleurs de texte apprises
   - Algorithmes de validation

2. `ViewsTextColorExampleView.swift` (optionnel)
   - Vue de démonstration
   - Exemples de combinaisons
   - Guide de contraste

#### Nouveaux fichiers Markdown (documentation)
3. `TEXT-COLOR-FEATURE.md`
4. `GUIDE-COULEURS-TEXTE.md`
5. `TEXT-COLOR-IMPLEMENTATION-SUMMARY.md`
6. `QUICK-START-TEXT-COLOR.md`

### ✅ Fichiers modifiés (à remplacer)

1. **ModelsVoucher.swift**
   - Ajout : `var textColor: String`
   - Ajout : paramètre `textColor: String = "#FFFFFF"` à l'init

2. **ViewsVoucherCardView.swift**
   - Ajout : propriété calculée `textColor`
   - Modification : tous les `.foregroundStyle(.white)` → `.foregroundStyle(textColor)`

3. **ViewsEditVoucherView.swift**
   - Ajout : `@State private var selectedTextColor: Color`
   - Ajout : section complète de sélection de couleur
   - Ajout : fonctions de validation

4. **ViewsAddVoucherView.swift**
   - Ajout : `@State private var selectedTextColor`
   - Ajout : section complète de sélection de couleur
   - Ajout : fonctions de validation
   - Modification : `saveVoucher()` et `importSelectedVouchers()`

5. **LEARNING-SYSTEM.md**
   - Ajout : références aux couleurs de texte
   - Ajout : nouvelles méthodes

6. **README.md**
   - Ajout : Étape 4 dans les fonctionnalités
   - Ajout : `textColor` dans la structure de données

## 🔧 Étapes d'installation

### 1. Backup du projet
```bash
# Créer une branche de sauvegarde
git branch backup-before-text-color
git checkout -b feature/text-color
```

### 2. Ajouter les nouveaux fichiers

**Dans Xcode :**
1. File → Add Files to "Voucher Wallet"
2. Sélectionner :
   - `UtilitiesStoreNameLearning+TextColor.swift`
   - `ViewsTextColorExampleView.swift` (optionnel)

### 3. Remplacer les fichiers modifiés

**Option A : Copier-coller**
- Remplacer le contenu de chaque fichier dans Xcode

**Option B : Git**
```bash
# Si vous utilisez Git
git checkout feature/text-color -- ModelsVoucher.swift
git checkout feature/text-color -- ViewsVoucherCardView.swift
git checkout feature/text-color -- ViewsEditVoucherView.swift
git checkout feature/text-color -- ViewsAddVoucherView.swift
```

### 4. Build et test

```bash
# Nettoyage
Cmd + Shift + K

# Build
Cmd + B

# Run
Cmd + R
```

## 🧪 Tests de vérification

### Test 1 : Compilation
```
✅ Le projet compile sans erreur
✅ Pas de warnings critiques
```

### Test 2 : Migration des données
```
1. Lancer l'app
2. Vérifier que les bons existants s'affichent
   ✅ Le texte doit être blanc
   ✅ Les cartes doivent être visibles
```

### Test 3 : Nouvelle fonctionnalité
```
1. Créer un nouveau bon
2. Aller à "Couleur de la carte"
   ✅ 2 ColorPickers visibles
   ✅ Aperçu visible
3. Changer les couleurs
   ✅ Aperçu se met à jour
4. Essayer blanc sur blanc
   ✅ Avertissement affiché
```

### Test 4 : Édition
```
1. Éditer un bon existant
2. Section "Couleur de la carte"
   ✅ Couleur de texte = blanc
   ✅ Peut être modifiée
3. Sauvegarder
   ✅ Modifications appliquées
```

### Test 5 : Apprentissage
```
1. Créer "Test Store" avec texte noir
2. Créer nouveau "Test Store"
   ✅ Texte noir pré-rempli
```

## ⚠️ Problèmes potentiels

### Problème 1 : Erreur de compilation sur `textColor`

**Cause :** Fichier `ModelsVoucher.swift` pas mis à jour

**Solution :**
```swift
// Vérifier que cette ligne existe :
var textColor: String // Hex color code for text

// Et dans l'init :
textColor: String = "#FFFFFF"
```

### Problème 2 : Extension `StoreNameLearning` introuvable

**Cause :** Fichier `StoreNameLearning+TextColor.swift` pas ajouté au projet

**Solution :**
1. Vérifier que le fichier est dans le navigateur de projet
2. Vérifier que "Target Membership" est coché

### Problème 3 : Bons existants avec texte invisible

**Cause :** Migration SwiftData pas effectuée

**Solution :**
1. Supprimer l'app du simulateur
2. Nettoyer (Cmd + Shift + K)
3. Relancer

**Ou :**
```swift
// Migration manuelle temporaire (à retirer ensuite)
extension Voucher {
    var safeTextColor: String {
        if textColor.isEmpty {
            return "#FFFFFF"
        }
        return textColor
    }
}
```

### Problème 4 : Aperçu ne se met pas à jour

**Cause :** États SwiftUI pas liés correctement

**Solution :**
Vérifier que les ColorPickers ont bien :
```swift
ColorPicker("Couleur de fond", selection: $selectedColor, supportsOpacity: false)
ColorPicker("Couleur du texte", selection: $selectedTextColor, supportsOpacity: false)
```

## 📊 Compatibilité

### Versions iOS
- ✅ iOS 17.0+ (requis pour SwiftData)
- ✅ Pas de changement de version minimum

### SwiftData
- ✅ Migration automatique
- ✅ Pas de code de migration nécessaire
- ✅ Valeur par défaut : `#FFFFFF`

### Données utilisateur
- ✅ Aucune perte de données
- ✅ Bons existants conservent toutes leurs infos
- ✅ Texte blanc appliqué automatiquement

## 🔍 Vérification post-installation

### Checklist finale

```
Navigation
├─ ✅ L'app se lance
├─ ✅ La liste des bons s'affiche
├─ ✅ Les bons existants ont du texte blanc
└─ ✅ Pas de crash

Création
├─ ✅ Bouton "+" fonctionne
├─ ✅ Section "Couleur de la carte" visible
├─ ✅ 2 ColorPickers présents
├─ ✅ Aperçu fonctionnel
└─ ✅ Sauvegarde fonctionne

Édition
├─ ✅ Modification de bon fonctionne
├─ ✅ Section couleur visible
├─ ✅ Couleur de texte modifiable
└─ ✅ Sauvegarde fonctionne

Validation
├─ ✅ Avertissement si couleurs similaires
├─ ✅ Aperçu temps réel
└─ ✅ Préréglages fonctionnent

Apprentissage
├─ ✅ Couleurs mémorisées
├─ ✅ Couleurs suggérées
└─ ✅ Réutilisation fonctionne
```

## 🎯 Rollback si nécessaire

### En cas de problème majeur

**Option 1 : Git**
```bash
# Revenir à l'état avant migration
git checkout backup-before-text-color
```

**Option 2 : Suppression manuelle**
```
1. Supprimer UtilitiesStoreNameLearning+TextColor.swift
2. Restaurer les fichiers modifiés depuis backup
3. Clean Build Folder (Cmd + Shift + K)
4. Rebuild
```

**Option 3 : Désactivation temporaire**
```swift
// Dans VoucherCardView, forcer blanc :
private var textColor: Color {
    Color.white  // Au lieu de Color(hex: voucher.textColor)
}
```

## 📞 Support

### En cas de problème

1. **Vérifier** cette checklist
2. **Consulter** `TEXT-COLOR-IMPLEMENTATION-SUMMARY.md`
3. **Tester** avec `TextColorExampleView`
4. **Nettoyer** le build (Cmd + Shift + K)
5. **Supprimer** les données de l'app (simulateur)

### Fichiers de référence
- `TEXT-COLOR-FEATURE.md` - Spécifications
- `GUIDE-COULEURS-TEXTE.md` - Guide utilisateur
- `QUICK-START-TEXT-COLOR.md` - Démarrage rapide

## ✅ C'est fait !

Une fois tous les tests passés :
```bash
# Merge de la fonctionnalité
git add .
git commit -m "✨ Add text color customization feature"
git checkout main
git merge feature/text-color
```

**Félicitations ! 🎉**

La fonctionnalité de couleur de texte est maintenant intégrée à votre projet !

---

**Guide créé le :** 04/04/2026  
**Par :** JEREMY  
**Version :** 1.0
