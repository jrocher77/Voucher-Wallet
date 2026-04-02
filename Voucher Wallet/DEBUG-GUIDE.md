# 🐛 Guide de Débogage - Voucher Wallet

## Problèmes courants et solutions

### 1. ❌ Le code-barres ne s'affiche pas

#### Causes possibles :

**A. Le numéro contient des caractères non-ASCII**
- Les codes-barres Code128 n'acceptent **que** les caractères ASCII
- Pas d'accents, pas de caractères spéciaux

**Solution :**
- Le code nettoie automatiquement les espaces et tirets
- Vérifie dans la **Console Xcode** (Cmd + Shift + Y) les logs :
  ```
  🔢 Génération code-barres pour: 1234567890123
  ✅ Code-barres généré avec succès
  ```
  ou
  ```
  ❌ Impossible de convertir en ASCII: ...
  ```

**B. Le numéro est vide ou invalide**
- Vérifie que le champ "Numéro du bon" n'est pas vide
- Essaye avec un numéro simple : `1234567890123`

**C. Le type de code est mal choisi**
- Si tu as choisi "Code-barres" mais le numéro n'est pas compatible
- Essaye de changer pour "QR Code" (plus flexible)

---

### 2. 🏪 Le nom de l'enseigne n'est pas reconnu

#### Comment ça marche ?

L'app cherche ces mots dans le PDF (insensible à la casse) :
- Carrefour, Decathlon, Fnac, Amazon, Ikea
- Auchan, Leclerc, Boulanger, Darty, Intersport
- H&M, Zara, Sephora, Galeries Lafayette, Printemps

#### Diagnostic :

**Ouvre la Console Xcode** pendant l'analyse du PDF :

```
📄 Texte extrait du PDF:
[Tout le texte du PDF s'affiche ici]
---
🏪 Enseigne trouvée: Carrefour
```

ou

```
❌ Aucune enseigne détectée
```

#### Solutions :

**A. L'enseigne n'est pas dans la liste**
- Entre le nom manuellement dans le champ "Enseigne"
- Si c'est une enseigne courante, demande-moi de l'ajouter au code

**B. Le PDF est mal scanné (texte illisible)**
- L'OCR ne peut pas lire le texte
- Entre les informations manuellement

**C. Le nom est écrit différemment**
- Exemple : "E.Leclerc" au lieu de "Leclerc"
- Le code gère déjà plusieurs variations, mais pas toutes
- Entre le nom exact pour avoir la bonne couleur

---

### 3. 📱 Voir tous les logs de débogage

#### Étapes :

1. **Ouvre Xcode**
2. **Lance l'app** sur ton iPhone ou simulateur (Cmd + R)
3. **Ouvre la console** : Cmd + Shift + Y
4. **Importe un PDF** dans l'app

#### Tu verras :

```
📄 Texte extrait du PDF:
CARREFOUR
Bon d'achat de 50€
Valable jusqu'au 31/12/2026
Code: 1234567890123
PIN: 5678
---
🔢 Code-barres détecté: 1234567890123
🔢 Numéros extraits du texte: ["1234567890123"]
✅ Numéros détectés: ["1234567890123"]
🏪 Enseigne trouvée: Carrefour
```

#### Si tu vois des ❌ :
- Note le message d'erreur
- Vérifie les logs pour comprendre ce qui bloque

---

### 4. 🧪 Tester avec un bon simple

#### Créer un bon de test manuellement :

1. **Appuie sur "+"** → **"Saisie manuelle"**
2. Remplis :
   - **Enseigne** : `Carrefour` (avec majuscule)
   - **Montant** : `50`
   - **Numéro** : `1234567890123` (que des chiffres)
   - **Type** : Code-barres
3. **Enregistre**

✅ **Résultat attendu :**
- Carte bleue Carrefour dans la liste
- Code-barres visible en détail (fond blanc)

---

### 5. 🔍 Vérifier qu'une enseigne est reconnue

#### Test rapide :

Dans le champ "Enseigne", tape exactement (respecte la casse) :
- `Carrefour` → Couleur bleue (#0055A5)
- `Decathlon` → Couleur bleue claire (#0082C3)
- `Fnac` → Couleur jaune/or (#E1A925)
- `Amazon` → Couleur orange (#FF9900)

#### Si la carte reste bleue par défaut :
- Le nom n'est pas reconnu
- Vérifie l'orthographe exacte
- Regarde dans `ModelsStorePreset.swift` la liste complète

---

### 6. 📄 Mon PDF n'est pas analysé correctement

#### Checklist :

- [ ] Le PDF s'ouvre-t-il correctement dans d'autres apps ?
- [ ] Le texte est-il sélectionnable dans le PDF ? (pas juste une image)
- [ ] Y a-t-il effectivement un code-barres/QR visible ?
- [ ] Les informations sont-elles en français ?

#### Si c'est un PDF "image" (scan) :
- L'OCR Vision peut avoir du mal
- La qualité doit être bonne
- Essaye d'augmenter la résolution du scan

#### Si rien n'est détecté :
- **Entre les infos manuellement**
- C'est pour ça qu'on a les 2 modes (scan + manuel)

---

### 7. 🎨 La couleur de l'enseigne ne s'applique pas

#### Vérifications :

**A. Le nom est-il exactement celui de la liste ?**
```swift
"Carrefour"  // ✅ Fonctionne
"carrefour"  // ✅ Fonctionne (recherche insensible à la casse)
"Carrefour Market" // ✅ Fonctionne (recherche partielle)
"Cora"  // ❌ Ne fonctionne pas (pas dans la liste)
```

**B. Regarde les logs :**
```
🏪 Enseigne trouvée: Carrefour
```

Si tu vois ça, mais la carte reste bleue par défaut, c'est un bug. Signale-le !

---

### 8. 🔧 Commandes utiles Xcode

#### Nettoyer et reconstruire :
```
Cmd + Shift + K  (Clean Build Folder)
Cmd + B          (Build)
Cmd + R          (Run)
```

#### Voir les logs :
```
Cmd + Shift + Y  (Ouvrir la console)
```

#### Redémarrer le simulateur :
```
Device → Erase All Content and Settings
```

#### Réinstaller l'app :
```
Supprime l'app du simulateur
Relance depuis Xcode
```

---

### 9. 💾 Les bons ne se sauvegardent pas

#### Symptômes :
- Tu ajoutes un bon
- Il apparaît
- Tu fermes l'app
- Il a disparu

#### Solution :
- C'est un problème SwiftData
- Vérifie que `Voucher_WalletApp.swift` a bien `.modelContainer(for: Voucher.self)`
- Vérifie que tous les fichiers de vues ont bien `@Environment(\.modelContext)`

---

### 10. 📞 Obtenir de l'aide

#### Informations à fournir :

1. **Logs de la console** (copie-colle)
2. **Capture d'écran** du problème
3. **Description** :
   - Enseigne testée (Carrefour, Fnac, etc.)
   - Type de code (barcode ou QR)
   - Méthode utilisée (PDF ou manuel)
   - Comportement attendu vs réel

---

## ✅ Checklist de test complète

- [ ] L'app compile sans erreur
- [ ] Je peux ajouter un bon manuellement
- [ ] La carte apparaît avec la bonne couleur
- [ ] Le code-barres s'affiche en détail (fond blanc)
- [ ] Je peux importer un PDF
- [ ] Le PDF est analysé (je vois les logs)
- [ ] Les suggestions apparaissent si des infos sont détectées
- [ ] Je peux enregistrer le bon
- [ ] Le bon persiste après fermeture de l'app
- [ ] Les filtres fonctionnent
- [ ] Je peux supprimer un bon

---

## 🎯 Tests spécifiques par enseigne

### Carrefour
- **Couleur attendue** : Bleu (#0055A5)
- **Type code** : Généralement code-barres EAN-13

### Fnac
- **Couleur attendue** : Jaune/Or (#E1A925)
- **Type code** : Code-barres

### Decathlon
- **Couleur attendue** : Bleu clair (#0082C3)
- **Type code** : Souvent QR code

---

**Besoin d'aide supplémentaire ? Partage les logs de la console !** 🚀
