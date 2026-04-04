# 📱 Aperçu des Réglages iOS

Ce document montre à quoi ressembleront les réglages dans l'app Réglages d'iOS.

## Page principale (Root.plist)

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ ⚙️  Réglages                  ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                              ┃
┃  🏠 Général                  ┃
┃  🔔 Notifications            ┃
┃  📱 Temps d'écran            ┃
┃  ...                         ┃
┃                              ┃
┃  ━━━━━━━━━━━━━━━━━━━━━━━━━  ┃
┃                              ┃
┃  📱 Voucher Wallet       >   ┃  ← L'utilisateur tape ici
┃                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## Page Voucher Wallet

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ ⬅️  Voucher Wallet            ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                              ┃
┃  APPRENTISSAGE AUTOMATIQUE   ┃
┃  ┌──────────────────────────┐┃
┃  │ L'application mémorise   │┃
┃  │ automatiquement vos      │┃
┃  │ préférences d'enseignes  │┃
┃  │ et de couleurs pour vous │┃
┃  │ faire gagner du temps.   │┃
┃  └──────────────────────────┘┃
┃                              ┃
┃  Statistiques            >   ┃
┃                              ┃
┃  ━━━━━━━━━━━━━━━━━━━━━━━━━  ┃
┃                              ┃
┃  GESTION DES DONNÉES         ┃
┃  ┌──────────────────────────┐┃
┃  │ Activez cette option     │┃
┃  │ puis ouvrez l'app pour   │┃
┃  │ réinitialiser toutes les │┃
┃  │ données d'apprentissage. │┃
┃  └──────────────────────────┘┃
┃                              ┃
┃  Demander réinit.    [ OFF ] ┃  ← Toggle principal
┃                              ┃
┃  ━━━━━━━━━━━━━━━━━━━━━━━━━  ┃
┃                              ┃
┃  À PROPOS                    ┃
┃                              ┃
┃  Version              1.0    ┃
┃                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## Page Statistiques (Statistics.plist)

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃ ⬅️  Statistiques              ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                              ┃
┃  STATISTIQUES D'APPRENTISSAGE┃
┃  ┌──────────────────────────┐┃
┃  │ Ces statistiques sont    │┃
┃  │ mises à jour             │┃
┃  │ automatiquement.         │┃
┃  └──────────────────────────┘┃
┃                              ┃
┃  Enseignes mémorisées    12  ┃
┃  Préférences de couleurs  8  ┃
┃                              ┃
┃  ━━━━━━━━━━━━━━━━━━━━━━━━━  ┃
┃                              ┃
┃  ENSEIGNES FAVORITES         ┃
┃  ┌──────────────────────────┐┃
┃  │ Les enseignes que vous   │┃
┃  │ utilisez le plus souvent.│┃
┃  └──────────────────────────┘┃
┃                              ┃
┃  1ère place   Carrefour (15) ┃
┃  2ème place   Auchan (8)     ┃
┃  3ème place   Leclerc (5)    ┃
┃                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

## Scénario d'utilisation

### 1. L'utilisateur active le toggle

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  Demander réinit.    [ ON ]  ┃  ← Passe à ON
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

### 2. L'utilisateur ouvre Voucher Wallet

```
┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓
┃  📱 Voucher Wallet            ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┫
┃                              ┃
┃  ⚠️  Alerte apparaît         ┃
┃                              ┃
┃  ┌──────────────────────────┐┃
┃  │ Réinitialiser            │┃
┃  │ l'apprentissage ?        │┃
┃  │                          │┃
┃  │ Toutes les données       │┃
┃  │ d'apprentissage seront   │┃
┃  │ supprimées (enseignes    │┃
┃  │ mémorisées, préférences  │┃
┃  │ de couleurs). Vos bons   │┃
┃  │ d'achat ne seront pas    │┃
┃  │ affectés.                │┃
┃  │                          │┃
┃  │  [ Annuler ]             │┃
┃  │  [ Réinitialiser ]       │┃
┃  └──────────────────────────┘┃
┃                              ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

### 3a. Si l'utilisateur annule

```
→ Le toggle repasse à OFF automatiquement
→ Rien n'est supprimé
```

### 3b. Si l'utilisateur confirme

```
→ Les données sont supprimées
→ Le toggle repasse à OFF automatiquement
→ Les statistiques passent à 0
→ Message de confirmation affiché
```

## États du toggle

### État initial (par défaut)
```
Demander réinit.    [ OFF ]
```

### Après activation par l'utilisateur
```
Demander réinit.    [ ON ]   ← En attente de confirmation
```

### Après confirmation ou annulation
```
Demander réinit.    [ OFF ]  ← Automatiquement remis à OFF
```

## Mise à jour automatique des statistiques

Les valeurs se mettent à jour :

```
Avant apprentissage :
Enseignes mémorisées    0
Préférences de couleurs 0
1ère place              -
2ème place              -
3ème place              -

↓ L'utilisateur ajoute des bons et valide des enseignes

Après apprentissage :
Enseignes mémorisées    12
Préférences de couleurs 8
1ère place              Carrefour (15)
2ème place              Auchan (8)
3ème place              Leclerc (5)

↓ L'utilisateur réinitialise

Après réinitialisation :
Enseignes mémorisées    0
Préférences de couleurs 0
1ère place              -
2ème place              -
3ème place              -
```

## Avantages de cette approche

✅ **Pas de bouton dans l'app principale**
   - L'app reste simple et focalisée sur les bons
   - Les réglages avancés sont dans les Réglages iOS

✅ **Cohérent avec les apps Apple**
   - Safari, Mail, Messages ont leurs réglages dans Réglages iOS
   - Expérience utilisateur familière

✅ **Statistiques en temps réel**
   - Pas besoin d'ouvrir l'app pour voir les stats
   - Mise à jour automatique

✅ **Sécurité**
   - Double confirmation pour la réinitialisation
   - Le toggle se désactive automatiquement après action

✅ **Transparence**
   - L'utilisateur voit exactement ce qui est mémorisé
   - Possibilité de tout effacer à tout moment

## Navigation

```
Réglages iOS
    └─> Voucher Wallet
            ├─> Statistiques (sous-page)
            │       ├─ Enseignes mémorisées
            │       ├─ Préférences de couleurs
            │       └─ Top 3 enseignes
            │
            ├─> Demander réinitialisation (toggle)
            └─> Version

Voucher Wallet (app)
    └─> Alerte de confirmation (si toggle activé)
            ├─> Annuler → toggle OFF
            └─> Confirmer → suppression + toggle OFF
```

---

**Note** : Les captures d'écran ASCII ci-dessus sont des représentations simplifiées. L'interface réelle utilisera le style iOS natif avec les polices San Francisco, les séparateurs système, et le thème clair/sombre automatique.
