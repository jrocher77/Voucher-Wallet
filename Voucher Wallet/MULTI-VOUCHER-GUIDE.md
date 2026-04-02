# 📄 Gestion des PDFs Multi-Pages

## 🎯 Nouvelle fonctionnalité

L'app peut maintenant **détecter automatiquement plusieurs bons d'achat** dans un même PDF !

### Cas d'usage :
- Ta banque génère 1 PDF avec 3 bons de 50€ chacun
- Au lieu d'importer 3 fois le PDF, l'app détecte les 3 bons
- Tu choisis ceux que tu veux importer

---

## ✨ Comment ça marche

### 1. **Analyse page par page**

Le PDFAnalyzer analyse maintenant chaque page séparément :

```
📄 PDF avec 3 pages
   ├─ Page 1 → Bon Carrefour 50€ (code-barres)
   ├─ Page 2 → Bon Fnac 25€ (code-barres)
   └─ Page 3 → Bon Amazon 100€ (QR code)
```

### 2. **Détection intelligente**

Pour chaque page, l'app détecte :
- ✅ Le code-barres ou QR code
- ✅ Le numéro du bon
- ✅ L'enseigne (Carrefour, Fnac, etc.)
- ✅ Le montant (€)
- ✅ Le code PIN (si présent)
- ✅ La date d'expiration

### 3. **Trois scénarios possibles**

#### **Scénario A : Plusieurs bons détectés** (nouveau !)
```
📄 Analyse terminée
🎉 3 bons détectés

→ Affichage de la vue de sélection
→ Tu choisis ceux à importer
→ Import multiple en un clic
```

#### **Scénario B : Un seul bon détecté**
```
📄 Analyse terminée
✅ 1 bon détecté

→ Pré-remplissage automatique du formulaire
→ Tu vérifies et enregistres
```

#### **Scénario C : Aucun bon complet détecté**
```
📄 Analyse terminée
⚠️ Détection partielle

→ Suggestions de numéros/montants
→ Saisie manuelle des infos manquantes
```

---

## 📱 Interface de sélection

Quand plusieurs bons sont détectés, tu verras :

```
┌─────────────────────────────────────┐
│  📋 3 bon(s) détecté(s)            │
│  Sélectionnez ceux à importer      │
├─────────────────────────────────────┤
│  [ Tout sélectionner ]             │
├─────────────────────────────────────┤
│                                     │
│  ✓ Carrefour - 50,00 €            │
│    Numéro: 1234567890123           │
│    📄 Page 1  📊 Code-barres       │
│                                     │
│  ✓ Fnac - 25,00 €                 │
│    Numéro: 9876543210987           │
│    📄 Page 2  📊 Code-barres       │
│                                     │
│  ✓ Amazon - 100,00 €              │
│    Numéro: AMZ123456               │
│    📄 Page 3  📱 QR Code           │
│                                     │
├─────────────────────────────────────┤
│  [Annuler]     [Importer (3)]      │
└─────────────────────────────────────┘
```

### Actions :
- ✅ **Tap sur un bon** : Sélectionner/Désélectionner
- ✅ **Tout sélectionner** : Importer tous les bons
- ✅ **Sélection partielle** : Choisir uniquement certains bons
- ✅ **Import** : Ajoute les bons sélectionnés à la liste

---

## 🔧 Logs de débogage

Dans la **Console Xcode**, tu verras :

### Analyse d'un PDF multi-pages :

```
📄 Analyse d'un PDF avec 3 page(s)

📃 Page 1/3
🔢 Code-barres détecté: 1234567890123
🏪 Enseigne trouvée: Carrefour
✅ Bon détecté sur la page 1: 1234567890123

📃 Page 2/3
🔢 Code-barres détecté: 9876543210987
🏪 Enseigne trouvée: Fnac
✅ Bon détecté sur la page 2: 9876543210987

📃 Page 3/3
📱 QR Code détecté: AMZ123456
🏪 Enseigne trouvée: Amazon
✅ Bon détecté sur la page 3: AMZ123456

🎉 3 bon(s) détecté(s) au total
```

### Import avec sélection :

```
🎉 3 bons détectés, affichage de la sélection
✅ Import de 3 bon(s) sélectionné(s)
```

---

## 📊 Structure DetectedVoucher

Chaque bon détecté contient :

```swift
struct DetectedVoucher {
    let pageNumber: Int          // Numéro de page (1, 2, 3...)
    let voucherNumber: String    // Numéro du bon
    let codeType: CodeType       // .barcode ou .qrCode
    let storeName: String?       // "Carrefour", "Fnac", etc.
    let amount: Double?          // 50.0, 25.0, etc.
    let pinCode: String?         // "5678" (optionnel)
    let expirationDate: Date?    // Date d'expiration
    let codeImageData: Data?     // Image du code générée
}
```

---

## 🧪 Comment tester

### Test 1 : PDF avec 1 seul bon

1. **Importe un PDF simple** (1 page, 1 bon)
2. **Résultat attendu** :
   - ✅ Analyse rapide
   - ✅ Formulaire pré-rempli
   - ✅ Pas d'écran de sélection

### Test 2 : PDF avec plusieurs pages

1. **Crée un PDF avec 2-3 pages** (chacune avec un bon différent)
2. **Importe le PDF**
3. **Résultat attendu** :
   - ✅ Analyse page par page
   - ✅ Écran de sélection s'affiche
   - ✅ Liste des bons détectés
   - ✅ Possibilité de sélectionner/désélectionner

### Test 3 : Sélection partielle

1. **Importe un PDF avec 3 bons**
2. **Décoche le 2ème bon**
3. **Clique sur "Importer (2)"**
4. **Résultat attendu** :
   - ✅ Seuls 2 bons sont ajoutés
   - ✅ Le 2ème est ignoré

---

## 💡 Cas particuliers

### PDF avec texte mais sans code visible

Si une page contient du texte mais **aucun code-barres/QR code détectable** :

- ⚠️ La page sera ignorée
- Les autres pages seront quand même analysées
- Tu peux toujours utiliser la saisie manuelle

### Plusieurs codes sur une même page

Si une page contient **plusieurs codes-barres** :

- Le **premier code détecté** sera utilisé
- Les autres codes seront dans les logs (pour debug)
- Vision Framework priorise les codes les plus gros

### Pages avec mauvaise qualité

Si une page est **floue ou mal scannée** :

- L'OCR peut échouer
- Pas de bon détecté pour cette page
- Les autres pages restent analysées normalement

---

## 🚀 Améliorations futures possibles

### 1. **Aperçu des pages**
- Afficher une miniature de chaque page
- Voir visuellement où se trouve le bon

### 2. **Édition avant import**
- Modifier les infos détectées avant import
- Corriger les erreurs de détection

### 3. **Import sélectif de pages**
- Choisir quelles pages analyser
- Ignorer les pages de conditions générales

### 4. **Fusion de bons similaires**
- Détecter les doublons
- Proposer de fusionner

---

## ✅ Checklist de test

- [ ] PDF 1 page = pré-remplissage automatique
- [ ] PDF 2 pages = écran de sélection
- [ ] PDF 3+ pages = écran de sélection
- [ ] Sélection de tous les bons
- [ ] Sélection partielle (1 sur 3)
- [ ] Désélection complète (message d'erreur attendu)
- [ ] Import réussi → bons dans la liste
- [ ] Chaque bon a sa couleur d'enseigne
- [ ] Chaque bon a son code-barres/QR
- [ ] Les logs affichent l'analyse page par page

---

## 📝 Exemple de PDF multi-bons

Si tu veux créer un PDF de test :

1. **Pages** (sur Mac) ou **Google Docs**
2. **Page 1** :
   ```
   CARREFOUR
   Bon d'achat de 50€
   Code: 1234567890123
   Valable jusqu'au 31/12/2026
   ```
3. **Page 2** :
   ```
   FNAC
   Bon d'achat de 25€
   Code: 9876543210987
   Valable jusqu'au 31/12/2026
   ```
4. **Exporte en PDF**
5. **Importe dans l'app** 🎉

---

**La détection multi-bons est maintenant fonctionnelle ! 🎉**

Teste avec tes vrais PDFs de banque et dis-moi si ça fonctionne bien ! 🚀
