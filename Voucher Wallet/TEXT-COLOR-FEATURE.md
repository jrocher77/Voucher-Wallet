# Fonctionnalité : Couleur de Texte Personnalisée

## 📝 Vue d'ensemble

Cette fonctionnalité permet aux utilisateurs de personnaliser la couleur du texte sur leurs cartes de bons d'achat, en plus de la couleur de fond déjà existante. Le système inclut :

- **Validation de contraste** : Empêche de choisir des couleurs trop similaires
- **Apprentissage automatique** : Mémorise les préférences par enseigne
- **Suggestions intelligentes** : Propose des couleurs adaptées selon le fond
- **Aperçu en temps réel** : Visualisation instantanée du résultat

## 🎨 Fonctionnalités Principales

### 1. Sélection de couleur de texte

**Où ?** 
- Vue d'ajout de bon (`AddVoucherView`)
- Vue d'édition de bon (`EditVoucherView`)

**Comment ?**
- 2 ColorPickers : un pour le fond, un pour le texte
- 4 couleurs de texte préréglées :
  - Blanc (#FFFFFF)
  - Noir (#000000)
  - Gris clair (#E5E5EA)
  - Gris foncé (#3A3A3C)

### 2. Validation de contraste

**Algorithme utilisé :**
- Calcul de luminosité relative selon la formule W3C WCAG
- Ratio de contraste minimum : 3:1
- Recommandé : 4.5:1 (WCAG AA)

**Feedback utilisateur :**
```
⚠️ Les couleurs sont trop similaires. Le texte sera difficile à lire.
```

**Aperçu en temps réel :**
- Carte miniature affichant le résultat
- Mise à jour instantanée lors du changement de couleur
- Affichage du nom de l'enseigne et du numéro

### 3. Apprentissage automatique

**Stockage :**
- UserDefaults : `learnedTextColors`
- Format : `[nomEnseigne: couleurHex]`
- Clé normalisée en minuscules

**Comportement :**
```swift
// Lors de l'enregistrement
StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)

// Lors de l'import multiple
if let learnedTextColor = StoreNameLearning.shared.getLearnedTextColor(for: storeName) {
    textColorHex = learnedTextColor
} else {
    textColorHex = "#FFFFFF"  // Blanc par défaut
}
```

### 4. Suggestion automatique

**Algorithme :**
```swift
func suggestTextColor(for backgroundColor: String) -> String {
    let luminance = calculateLuminance(hex: backgroundColor)
    return luminance > 0.5 ? "#000000" : "#FFFFFF"
}
```

**Utilisation :**
- Fond clair (luminance > 0.5) → Texte noir
- Fond foncé (luminance ≤ 0.5) → Texte blanc

## 🏗️ Architecture Technique

### Modèle de données

**Voucher.swift**
```swift
@Model
final class Voucher {
    var storeColor: String      // Hex color code (fond)
    var textColor: String        // Hex color code (texte) ⭐ NOUVEAU
    
    init(
        // ...
        storeColor: String = "#007AFF",
        textColor: String = "#FFFFFF"  // ⭐ NOUVEAU
    ) {
        // ...
    }
}
```

### Vue de carte

**VoucherCardView.swift**
```swift
struct VoucherCardView: View {
    let voucher: Voucher
    
    private var textColor: Color {
        Color(hex: voucher.textColor)
    }
    
    var body: some View {
        VStack {
            Text(voucher.storeName)
                .foregroundStyle(textColor)  // ⭐ Utilise la couleur personnalisée
            // ...
        }
        .background(Color(hex: voucher.storeColor))
    }
}
```

### Système d'apprentissage

**StoreNameLearning+TextColor.swift** (Extension)

#### Méthodes principales :

```swift
// Enregistrer une préférence
func learnTextColor(_ textColorHex: String, for storeName: String)

// Récupérer une préférence
func getLearnedTextColor(for storeName: String) -> String?

// Suggérer une couleur
func suggestTextColor(for backgroundColor: String) -> String

// Valider le contraste
func hasGoodContrast(foreground: String, background: String) -> Bool

// Réinitialiser
func resetLearnedTextColors()

// Tout récupérer
func getAllLearnedTextColors() -> [String: String]
```

### Formulaires d'édition

**EditVoucherView.swift & AddVoucherView.swift**

#### Validation de contraste :
```swift
private func areColorsTooSimilar(_ color1: Color, _ color2: Color) -> Bool {
    let contrastRatio = calculateContrastRatio(color1, color2)
    return contrastRatio < 3.0
}
```

#### Aperçu en temps réel :
```swift
HStack {
    VStack(alignment: .leading) {
        Text(storeName)
            .foregroundStyle(selectedTextColor)
        Text(voucherNumber)
            .foregroundStyle(selectedTextColor.opacity(0.8))
    }
    Spacer()
    Text(amount)
        .foregroundStyle(selectedTextColor)
}
.padding()
.background(
    RoundedRectangle(cornerRadius: 12)
        .fill(selectedColor)
)
```

## 📊 Flux de données

### 1. Création d'un nouveau bon

```
Utilisateur sélectionne les couleurs
    ↓
Validation du contraste
    ↓
Aperçu en temps réel
    ↓
Enregistrement du voucher
    ↓
Apprentissage des préférences
    ↓
Stockage dans UserDefaults
```

### 2. Import PDF avec bons multiples

```
Analyse du PDF
    ↓
Détection des enseignes
    ↓
Pour chaque bon :
    - Récupération couleur de fond apprise
    - Récupération couleur de texte apprise
    - Si non appris → suggestion automatique
    ↓
Création des vouchers
    ↓
Apprentissage des nouvelles préférences
```

### 3. Édition d'un bon existant

```
Chargement des couleurs actuelles
    ↓
Modification par l'utilisateur
    ↓
Validation temps réel du contraste
    ↓
Sauvegarde
    ↓
Mise à jour de l'apprentissage
```

## 🧪 Scénarios de test

### Test 1 : Contraste insuffisant
```
1. Sélectionner fond blanc (#FFFFFF)
2. Sélectionner texte blanc (#FFFFFF)
   → ⚠️ Avertissement affiché
3. Aperçu montre texte invisible
```

### Test 2 : Contraste bon
```
1. Sélectionner fond bleu foncé (#0055A5)
2. Sélectionner texte blanc (#FFFFFF)
   → ✅ Pas d'avertissement
3. Aperçu montre texte lisible
```

### Test 3 : Apprentissage
```
1. Créer bon "Carrefour" avec fond bleu, texte blanc
2. Créer nouveau bon "Carrefour"
   → Couleurs pré-remplies automatiquement
```

### Test 4 : Suggestion automatique
```
1. Import PDF avec enseigne nouvelle
2. Couleur de fond claire détectée
   → Texte noir suggéré automatiquement
3. Couleur de fond foncée détectée
   → Texte blanc suggéré automatiquement
```

## ✅ Checklist d'implémentation

- [x] Ajouter propriété `textColor` au modèle `Voucher`
- [x] Mettre à jour `VoucherCardView` pour utiliser la couleur de texte
- [x] Ajouter ColorPicker dans `EditVoucherView`
- [x] Ajouter ColorPicker dans `AddVoucherView`
- [x] Implémenter validation de contraste
- [x] Créer aperçu en temps réel
- [x] Créer extension `StoreNameLearning+TextColor`
- [x] Ajouter méthodes d'apprentissage
- [x] Ajouter méthode de suggestion automatique
- [x] Mettre à jour `saveVoucher()` pour inclure la couleur de texte
- [x] Mettre à jour `importSelectedVouchers()` pour inclure la couleur de texte
- [x] Ajouter préréglages de couleurs de texte
- [x] Tester avec différentes combinaisons de couleurs
- [x] Documenter la fonctionnalité

## 🎯 Améliorations futures possibles

1. **Thèmes prédéfinis**
   - Combinaisons de couleurs harmonieuses
   - Thèmes par catégorie (luxe, sport, tech, etc.)

2. **Détection automatique de logo**
   - Vision Framework pour extraire les couleurs dominantes
   - Suggestion de palette basée sur le logo

3. **Accessibilité avancée**
   - Support des modes d'accessibilité système
   - Contraste renforcé (WCAG AAA - 7:1)
   - Support du mode à contraste élevé d'iOS

4. **Prévisualisation étendue**
   - Vue détaillée avec code-barres
   - Mode sombre/clair
   - Différentes tailles de texte

5. **Export de thème**
   - Partager une palette de couleurs
   - Importer des palettes depuis d'autres utilisateurs

6. **IA générative**
   - Suggestion de combinaisons basée sur l'enseigne
   - Analyse de sentiment couleur (confiance, luxe, etc.)

## 📝 Notes de développement

### Performance
- Les calculs de luminosité sont rapides (O(1))
- Pas d'impact sur les performances de rendu
- UserDefaults pour un accès instantané

### Compatibilité
- iOS 17.0+ (SwiftData)
- Compatible avec tous les modèles de couleur SwiftUI
- Support du mode sombre natif

### Migration
- Les bons existants utilisent blanc par défaut (#FFFFFF)
- Pas de migration de données nécessaire
- Rétrocompatible avec les anciennes versions

### Accessibilité
- Validation WCAG 2.1 niveau A (3:1)
- Support de VoiceOver
- Textes alternatifs pour les couleurs
- Support du mode à contraste élevé

## 🐛 Résolution de problèmes

### Problème : L'avertissement ne s'affiche pas
**Solution :** Vérifier que le ratio de contraste est bien < 3.0

### Problème : Les couleurs ne sont pas sauvegardées
**Solution :** S'assurer que `learnTextColor()` est appelé après `modelContext.save()`

### Problème : Les couleurs apprises ne sont pas appliquées
**Solution :** Vérifier que le nom de l'enseigne est identique (normalisation en minuscules)

---

**Créé par :** JEREMY
**Date :** 04/04/2026
**Version :** 1.0
