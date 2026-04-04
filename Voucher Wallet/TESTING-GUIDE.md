# 🧪 Guide de Test - Système d'Apprentissage

## Test rapide (5 minutes)

### 1. Test du badge de confiance

**Objectif** : Vérifier que le score s'affiche correctement

1. Importez un PDF d'un bon Carrefour
2. Vérifiez la présence d'un badge de confiance :
   - Badge vert (80%+) = ✅ Détection parfaite
   - Badge bleu/orange = ✅ Détection moyenne
   - Badge rouge = ⚠️ Vérifier le nom

**Résultat attendu** : Un badge coloré avec un pourcentage apparaît à côté du nom.

---

### 2. Test de l'apprentissage basique

**Objectif** : Vérifier que l'app mémorise les enseignes

**Étapes** :
1. Importez un PDF d'une enseigne **non standard** (ex: "King Jouet", "Cultura")
2. Notez le score de confiance initial (ex: 55%)
3. Validez et enregistrez le bon
4. Importez un **nouveau PDF de la même enseigne**
5. Comparez le nouveau score

**Résultat attendu** :
```
Import 1 : King Jouet [🟠 55%]
Import 2 : King Jouet [🔵 75%]  ← Score amélioré !
```

---

### 3. Test de l'import multiple

**Objectif** : Vérifier les badges dans la liste

1. Importez un PDF contenant **plusieurs bons** (2+)
2. Vérifiez que chaque bon affiche son badge
3. Comparez les scores entre bons connus/inconnus

**Résultat attendu** :
```
☑️ Carrefour [🟢 92%]
☑️ Fnac [🟢 85%]
☑️ Boutique Xyz [🟠 45%]  ← Score plus bas
```

---

## Test complet (15 minutes)

### 4. Test des statistiques

**Objectif** : Vérifier la vue des stats

1. Après avoir importé plusieurs bons, ouvrez `LearningStatsView`
   - *(Vous devrez l'ajouter dans un menu/paramètres)*
2. Vérifiez :
   - ✅ Le nombre d'enseignes mémorisées
   - ✅ La liste des enseignes apprises
   - ✅ Le graphique des plus utilisées
   - ✅ Le compteur d'utilisations

**Résultat attendu** :
```
Statistiques
┌─────────────────────────────┐
│ Enseignes mémorisées: 5     │
└─────────────────────────────┘

Enseignes apprises
• Carrefour          3 fois
• King Jouet         2 fois
• Cultura            1 fois
```

---

### 5. Test du mapping (associations)

**Objectif** : Vérifier que les variantes sont gérées

**Scénario** :
1. Créez un PDF avec "KING-JOUET" (en majuscules avec tiret)
2. Importez-le, le système détecte "King-Jouet"
3. Corrigez manuellement en "King Jouet" (sans tiret)
4. Validez et enregistrez
5. Créez un autre PDF avec "KING JOUET" (variante)
6. Importez → L'app devrait suggérer "King Jouet"

**Résultat attendu** :
```
PDF 1: "KING-JOUET" → validé comme "King Jouet"
PDF 2: "KING JOUET" → automatiquement "King Jouet" [🔵 75%]
```

**Log attendu** :
```
🔗 Association créée: "KING-JOUET" → "King Jouet"
```

---

### 6. Test de réinitialisation

**Objectif** : Vérifier que la remise à zéro fonctionne

1. Dans `LearningStatsView`, tapez "Réinitialiser l'apprentissage"
2. Confirmez l'alerte
3. Vérifiez que :
   - ✅ Le compteur d'enseignes passe à 0
   - ✅ La liste est vide
   - ✅ Les stats sont effacées
4. Réimportez un ancien bon
5. Le score devrait être **plus bas** qu'avant

**Résultat attendu** :
```
Avant reset : Carrefour [🟢 92%]
Après reset : Carrefour [🟢 85%] ← Score réduit (historique perdu)
```

---

### 7. Test d'export

**Objectif** : Vérifier l'export JSON

1. Dans `LearningStatsView`, tapez "Exporter les données"
2. Partagez/Copiez le JSON
3. Vérifiez la structure :

**Structure JSON attendue** :
```json
{
  "learnedStores": [
    "Carrefour",
    "King Jouet",
    "Cultura"
  ],
  "storeCounts": {
    "Carrefour": 3,
    "King Jouet": 2,
    "Cultura": 1
  },
  "mappings": {
    "KING-JOUET": "King Jouet"
  }
}
```

---

## Test du bug corrigé (PIN)

### 8. Test du bug du PIN

**Objectif** : S'assurer que le PIN n'est plus corrompu

**Avant la correction** (pour référence) :
```
PDF contient: "Code: 1234567890123456"
Bug → PIN extrait: "1234" ❌ (4 premiers chiffres!)
```

**Après la correction** (comportement attendu) :

**Test 1 : PIN valide**
```
PDF contient: "PIN: 5678"
Résultat attendu: PIN = "5678" ✅
```

**Test 2 : Numéro long après "Code"**
```
PDF contient: "Code: 1234567890123456"
Résultat attendu: PIN = vide ✅ (rien capturé)
```

**Test 3 : Code PIN explicite**
```
PDF contient: "Code PIN: 9999"
Résultat attendu: PIN = "9999" ✅
```

**Test 4 : Import multiple**
```
PDF avec 3 bons :
  Bon 1: PIN: 1234
  Bon 2: PIN: 5678
  Bon 3: Code: 9999888877776666

Résultat attendu:
  Bon 1: PIN = "1234" ✅
  Bon 2: PIN = "5678" ✅
  Bon 3: PIN = vide ✅ (le long code n'est pas capturé)
```

---

## Checklist de validation

### Fonctionnalités essentielles
- [ ] Badge de confiance visible
- [ ] Score augmente avec les réutilisations
- [ ] Enseignes mémorisées correctement
- [ ] Mappings fonctionnels (variantes)
- [ ] Statistiques accessibles et exactes
- [ ] Export JSON valide
- [ ] Réinitialisation complète
- [ ] Bug PIN résolu

### Interface utilisateur
- [ ] Badge lisible et coloré
- [ ] Pourcentage affiché
- [ ] Icône adaptée au score
- [ ] Avertissement si score < 70%
- [ ] Liste des stats claire
- [ ] Graphique des utilisations

### Logs console
- [ ] "🏪 Enseigne détectée"
- [ ] "📊 Score de confiance: XX%"
- [ ] "📚 Enseigne apprise"
- [ ] "🔗 Association créée"
- [ ] "✅ Bon importé avec succès"

---

## Scénarios avancés

### 9. Test de montée en puissance

**Objectif** : Voir l'amélioration progressive

Importez le même bon **5 fois** et notez l'évolution :
```
Import 1: [🟠 55%]  ← Première détection
Import 2: [🔵 63%]  ← +1 utilisation
Import 3: [🔵 71%]  ← +2 utilisations
Import 4: [🟢 79%]  ← +3 utilisations
Import 5: [🟢 87%]  ← +4 utilisations (max bonus atteint)
```

---

### 10. Test de détection par URL

**Objectif** : Vérifier le bonus URL

Créez un PDF contenant "www.kingjouet.com"

**Résultat attendu** :
```
Détection: King Jouet
Méthode: urlExtraction
Bonus: +15% (URL correspondante)
Score: ~65-75%
```

---

### 11. Test de première ligne

**Objectif** : Bonus position

PDF avec "Ma Boutique" en toute première ligne (grande taille)

**Résultat attendu** :
```
Détection: Ma Boutique
Méthode: firstLine
Bonus: +10% (premières lignes)
Score: ~55-65%
```

---

## Problèmes courants et solutions

### Problème : Badge ne s'affiche pas
**Solution** : Vérifiez que `storeNameConfidence > 0`

### Problème : Score toujours à 40%
**Solution** : Le bonus historique ne s'applique qu'après validation

### Problème : Enseigne non mémorisée
**Solution** : Vérifiez que `learnStoreName()` est appelé après `save()`

### Problème : Stats vides
**Solution** : Rechargez la vue ou redémarrez l'app

---

## Commandes de debug

### Afficher les données UserDefaults
```swift
print(UserDefaults.standard.stringArray(forKey: "learnedStoreNames") ?? [])
print(UserDefaults.standard.dictionary(forKey: "storeNameCounts") ?? [:])
```

### Forcer une réinitialisation
```swift
StoreNameLearning.shared.resetLearningData()
```

### Logger un score
```swift
let learning = StoreNameLearning.shared
let context = StoreNameLearning.DetectionContext(
    hasMatchingURL: true,
    isInFirstLines: true,
    isAllUppercase: true
)
let score = learning.calculateConfidenceScore(
    for: "Test Store",
    detectionMethod: .knownStore,
    context: context
)
print("Score calculé: \(score)")  // Ex: 0.85
```

---

## Rapport de test

### Template à remplir :

```
Date: _____________
Testeur: _____________

✅ Fonctionnalités testées :
- [ ] Badge de confiance
- [ ] Apprentissage
- [ ] Import multiple
- [ ] Statistiques
- [ ] Mapping
- [ ] Reset
- [ ] Export
- [ ] Bug PIN

⚠️ Problèmes rencontrés :
_________________________________
_________________________________

📝 Notes :
_________________________________
_________________________________

Score global : __/10
```

---

**Bonne chance pour vos tests ! 🚀**
