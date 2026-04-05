# Protection contre les doublons - Documentation

## 📋 Vue d'ensemble

Cette fonctionnalité empêche les utilisateurs d'ajouter des bons d'achat en double dans le wallet. La détection se base sur le **numéro de bon** (`voucherNumber`), qui est considéré comme l'identifiant unique de chaque bon d'achat.

## 🎯 Classes modifiées

### 1. **AddVoucherView.swift**
Vue principale pour ajouter des bons manuellement ou via scan PDF.

#### Modifications :
- ✅ Ajout d'une `@Query` pour récupérer tous les bons existants
- ✅ Ajout d'états pour gérer les alertes de doublons
- ✅ Fonction `isVoucherNumberDuplicate()` pour vérifier l'existence d'un numéro
- ✅ Validation améliorée dans `isFormValid` qui bloque l'enregistrement si doublon
- ✅ Avertissement visuel en temps réel dans le formulaire si le numéro existe déjà
- ✅ Protection dans `saveVoucher()` avec alerte avant l'enregistrement
- ✅ Protection dans `importSelectedVouchers()` pour l'import multiple avec filtrage intelligent

#### Comportement :
- **Saisie manuelle** : Avertissement visuel en temps réel + blocage du bouton "Enregistrer"
- **Import unique** : Alerte modale si le bon existe déjà
- **Import multiple** : Filtrage automatique des doublons + alerte récapitulative

---

### 2. **PDFImportHandler.swift**
Vue pour gérer l'import de PDF via le partage système (share extension).

#### Modifications :
- ✅ Ajout d'une `@Query` pour récupérer tous les bons existants
- ✅ Ajout d'états pour gérer les alertes de doublons
- ✅ Fonction `isVoucherNumberDuplicate()` pour vérifier l'existence d'un numéro
- ✅ Validation améliorée dans `isFormValid`
- ✅ Avertissement visuel en temps réel dans le formulaire
- ✅ Protection dans `saveVoucher()` et `importSelectedVouchers()`

#### Comportement :
Identique à `AddVoucherView` mais pour les imports via le système de partage iOS.

---

### 3. **MultiVoucherSelectionView.swift**
Vue dédiée à la sélection multiple de bons détectés dans un PDF.

#### Modifications :
- ✅ Ajout d'une `@Query` pour récupérer tous les bons existants
- ✅ Ajout d'états pour gérer les alertes de doublons
- ✅ Fonction `isVoucherNumberDuplicate()` pour vérifier l'existence d'un numéro
- ✅ Filtrage intelligent dans `importSelectedVouchers()` qui :
  - Sépare les bons valides des doublons
  - Affiche une alerte récapitulative
  - Importe uniquement les bons valides
  - Ne ferme la vue que si au moins un bon a été importé

#### Comportement :
Lors de l'import multiple, les doublons sont automatiquement filtrés et l'utilisateur reçoit un rapport détaillé.

---

## 🔍 Logique de détection

### Critère de doublon
Un bon est considéré comme un doublon si son **numéro de bon** (`voucherNumber`) existe déjà dans la base de données SwiftData.

```swift
private func isVoucherNumberDuplicate(_ number: String) -> Bool {
    existingVouchers.contains { $0.voucherNumber == number }
}
```

### Pourquoi le numéro de bon ?
- Chaque bon d'achat physique possède un numéro unique
- C'est l'identifiant le plus fiable pour éviter les doublons
- Un utilisateur pourrait avoir plusieurs bons de la même enseigne avec des montants différents

---

## 💡 Expérience utilisateur

### Scénario 1 : Saisie manuelle d'un doublon
1. L'utilisateur saisit un numéro de bon
2. Si le numéro existe déjà, un avertissement rouge s'affiche en temps réel
3. Le bouton "Enregistrer" est désactivé
4. L'utilisateur doit modifier le numéro pour continuer

### Scénario 2 : Import unique d'un doublon (PDF avec un seul bon)
1. L'utilisateur sélectionne un PDF contenant un bon déjà importé
2. Le PDF est analysé et le formulaire est pré-rempli
3. L'utilisateur clique sur "Enregistrer"
4. Une alerte s'affiche : "Le bon avec le numéro XXX existe déjà dans votre wallet"
5. L'import est annulé

### Scénario 3 : Import multiple avec doublons (PDF avec plusieurs bons)
1. L'utilisateur sélectionne un PDF contenant 5 bons, dont 2 sont déjà importés
2. L'utilisateur sélectionne les 5 bons
3. Lors de l'import :
   - Les 3 bons valides sont importés
   - Une alerte affiche les 2 numéros en doublon
   - La vue se ferme car au moins un bon a été importé
4. Console : "✅ 3 bon(s) importé(s) avec succès" et "⚠️ 2 doublon(s) ignoré(s)"

### Scénario 4 : Tous les bons sont des doublons
1. L'utilisateur tente d'importer 3 bons déjà présents
2. Une alerte liste tous les numéros en doublon
3. La vue reste ouverte (aucun import effectué)
4. L'utilisateur peut annuler ou modifier sa sélection

---

## 🎨 Interface utilisateur

### Avertissement en temps réel
```swift
if !voucherNumber.isEmpty && isVoucherNumberDuplicate(voucherNumber) {
    Label {
        Text("Ce numéro de bon existe déjà dans votre wallet")
    } icon: {
        Image(systemName: "exclamationmark.triangle.fill")
    }
    .font(.caption)
    .foregroundStyle(.red)
}
```

### Alerte de doublon unique
```
Titre : "Bon(s) déjà importé(s)"
Message : "Le bon avec le numéro 1234567890 existe déjà dans votre wallet."
```

### Alerte de doublons multiples
```
Titre : "Bon(s) déjà importé(s)"
Message : "Les bons suivants existent déjà dans votre wallet :

1234567890
0987654321
5555555555"
```

---

## 🛡️ Sécurité et robustesse

### Points forts
✅ Vérification avant insertion dans SwiftData
✅ Aucune dépendance à des services externes
✅ Comparaison exacte des numéros (pas de tolérance aux erreurs)
✅ Fonctionne pour tous les modes d'import :
   - Saisie manuelle
   - Scan PDF unique
   - Scan PDF multiple
   - Import via partage système

### Limitations
⚠️ La comparaison est sensible à la casse (case-sensitive)
⚠️ Les espaces comptent (un espace en plus = numéro différent)
⚠️ Si deux bons ont le même numéro mais des enseignes différentes, le second sera rejeté

---

## 🧪 Tests recommandés

### Test 1 : Saisie manuelle d'un doublon
1. Créer un bon avec le numéro "123456"
2. Essayer d'ajouter un nouveau bon avec le même numéro
3. ✅ Vérifier que l'avertissement s'affiche
4. ✅ Vérifier que le bouton est désactivé

### Test 2 : Import PDF avec doublon
1. Importer un PDF contenant le bon "123456"
2. Réimporter le même PDF
3. ✅ Vérifier que l'alerte s'affiche
4. ✅ Vérifier qu'aucun doublon n'est créé

### Test 3 : Import multiple mixte
1. Créer 2 bons manuellement
2. Importer un PDF contenant ces 2 bons + 3 nouveaux
3. ✅ Vérifier que seuls les 3 nouveaux sont importés
4. ✅ Vérifier que l'alerte mentionne les 2 doublons

### Test 4 : Import 100% doublons
1. Créer 3 bons
2. Importer un PDF contenant uniquement ces 3 bons
3. ✅ Vérifier que l'alerte s'affiche
4. ✅ Vérifier que la vue reste ouverte
5. ✅ Vérifier qu'aucun bon n'est ajouté

---

## 📊 Logs de débogage

Les logs suivants ont été ajoutés pour faciliter le débogage :

```
✅ 3 bon(s) importé(s) avec succès
⚠️ 2 doublon(s) ignoré(s)
```

---

## 🔮 Améliorations futures possibles

### Suggestions
1. **Comparaison intelligente** : Ignorer la casse et les espaces
2. **Suggestion de modification** : Si un bon très similaire existe, proposer de l'éditer
3. **Historique des doublons** : Logger les tentatives de doublons pour analyse
4. **Mode "mise à jour"** : Permettre de remplacer un bon existant
5. **Badge visuel** : Indiquer visuellement dans la liste de sélection les bons déjà importés

### Exemple de comparaison intelligente
```swift
private func normalizeVoucherNumber(_ number: String) -> String {
    number.trimmingCharacters(in: .whitespaces)
          .lowercased()
          .replacingOccurrences(of: " ", with: "")
}

private func isVoucherNumberDuplicate(_ number: String) -> Bool {
    let normalized = normalizeVoucherNumber(number)
    return existingVouchers.contains { 
        normalizeVoucherNumber($0.voucherNumber) == normalized 
    }
}
```

---

## ✅ Résumé

Cette protection contre les doublons est :
- ✅ **Complète** : Couvre tous les chemins d'import
- ✅ **Transparente** : L'utilisateur comprend pourquoi l'import échoue
- ✅ **Intelligente** : Filtre automatiquement les doublons en import multiple
- ✅ **Robuste** : Basée sur SwiftData Query et non sur des états manuels
- ✅ **User-friendly** : Avertissements visuels en temps réel

---

**Date de création** : 5 avril 2026
**Version** : 1.0
**Auteur** : Assistant AI
