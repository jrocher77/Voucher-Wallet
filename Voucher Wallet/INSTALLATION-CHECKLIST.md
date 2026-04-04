# ✓ Checklist d'installation des Réglages iOS

Cochez les cases au fur et à mesure de votre installation.

## Phase 1 : Préparation (1 min)

- [ ] J'ai lu `QUICK-START.md`
- [ ] J'ai ouvert Xcode avec le projet Voucher Wallet
- [ ] J'ai les fichiers `Root.plist` et `Statistics.plist` sous la main

## Phase 2 : Création du Settings.bundle (2 min)

- [ ] J'ai créé le Settings.bundle (File → New → File → Settings Bundle)
- [ ] Le dossier `Settings.bundle` apparaît dans le navigateur de projet
- [ ] J'ai supprimé le fichier `Root.plist` auto-généré
- [ ] J'ai glissé-déposé le nouveau `Root.plist` dans `Settings.bundle`
- [ ] J'ai coché "Copy items if needed" lors de l'ajout
- [ ] J'ai glissé-déposé `Statistics.plist` dans `Settings.bundle`
- [ ] J'ai coché "Copy items if needed" lors de l'ajout

## Phase 3 : Vérification des fichiers Swift (1 min)

- [ ] `UtilitiesSettingsManager.swift` est dans le projet
- [ ] `ModifiersSettingsMonitorModifier.swift` est dans le projet
- [ ] `ContentView.swift` contient `.monitorSettingsChanges()`
- [ ] Tous les fichiers compilent sans erreur (⌘B)

## Phase 4 : Configuration Xcode (1 min)

- [ ] J'ai sélectionné `Settings.bundle` dans le navigateur
- [ ] Dans l'inspecteur de fichiers → Target Membership est coché
- [ ] Le projet compile sans erreur (⌘B)
- [ ] Aucun warning n'apparaît

## Phase 5 : Test sur simulateur/appareil (3 min)

- [ ] J'ai lancé l'app (⌘R)
- [ ] L'app démarre sans crash
- [ ] J'ai quitté l'app (balayé vers le haut)
- [ ] J'ai ouvert l'app **Réglages** iOS
- [ ] J'ai fait défiler jusqu'à trouver "Voucher Wallet"
- [ ] J'ai tapé sur "Voucher Wallet"
- [ ] Je vois la section "Apprentissage automatique"
- [ ] Je vois le bouton "Statistiques >"
- [ ] Je vois le toggle "Demander réinitialisation"
- [ ] Je vois la section "À propos" avec la version

## Phase 6 : Test des statistiques (2 min)

- [ ] J'ai tapé sur "Statistiques >"
- [ ] Je vois "Enseignes mémorisées"
- [ ] Je vois "Préférences de couleurs"
- [ ] Je vois "1ère place", "2ème place", "3ème place"
- [ ] Les valeurs affichées correspondent à mes données

## Phase 7 : Test de la réinitialisation (3 min)

- [ ] J'ai activé le toggle "Demander réinitialisation" (→ ON)
- [ ] J'ai quitté Réglages iOS
- [ ] J'ai ouvert Voucher Wallet
- [ ] Une alerte "Réinitialiser l'apprentissage ?" est apparue
- [ ] J'ai testé le bouton "Annuler"
- [ ] Le toggle est repassé à OFF automatiquement
- [ ] J'ai réactivé le toggle
- [ ] J'ai testé le bouton "Réinitialiser"
- [ ] Un message de confirmation est apparu
- [ ] Le toggle est repassé à OFF
- [ ] Les statistiques dans Réglages iOS sont à 0
- [ ] Mes bons d'achat sont toujours présents dans l'app ✅

## Phase 8 : Test de mise à jour automatique (2 min)

- [ ] J'ai ajouté un nouveau bon dans Voucher Wallet
- [ ] J'ai validé un nom d'enseigne
- [ ] J'ai choisi une couleur
- [ ] J'ai quitté l'app
- [ ] J'ai ouvert Réglages iOS → Voucher Wallet → Statistiques
- [ ] Les chiffres ont augmenté automatiquement
- [ ] Le top 3 des enseignes s'est mis à jour

## ✅ Installation terminée !

Si toutes les cases sont cochées : **Félicitations ! 🎉**

Votre système de Réglages iOS est opérationnel.

---

## 🆘 En cas de problème

### Une case n'est pas cochée ?

Consultez les guides suivants selon votre problème :

| Problème | Guide à consulter |
|----------|------------------|
| Settings.bundle n'apparaît pas | `XCODE-INSTALLATION-GUIDE.md` → Étape 1-3 |
| Erreurs de compilation | `XCODE-INSTALLATION-GUIDE.md` → Résolution de problèmes |
| Réglages n'apparaissent pas dans iOS | `XCODE-INSTALLATION-GUIDE.md` → Étape 5 |
| Statistiques ne se mettent pas à jour | `XCODE-INSTALLATION-GUIDE.md` → Résolution de problèmes |
| Toggle ne fonctionne pas | `XCODE-INSTALLATION-GUIDE.md` → Résolution de problèmes |

### Script de vérification automatique

```bash
chmod +x verify-settings-setup.sh
./verify-settings-setup.sh
```

Ce script vérifiera automatiquement que tous les fichiers sont présents.

---

## 📊 Temps total estimé

- ⏱️ Installation : **10-15 minutes**
- 🧪 Tests : **5-10 minutes**
- **Total : 15-25 minutes**

---

## 🎓 Prochaines étapes

Une fois l'installation terminée :

1. **Personnalisation** (optionnel)
   - Lisez `SETTINGS-CONFIGURATION.md` pour personnaliser les réglages
   
2. **Documentation utilisateur** (optionnel)
   - Créez un guide utilisateur basé sur `SETTINGS-PREVIEW.md`

3. **Tests approfondis** (recommandé)
   - Testez sur plusieurs appareils (iPhone, iPad)
   - Testez avec beaucoup de données
   - Testez les cas limites (0 données, beaucoup de données)

---

**Bonne installation ! 🚀**
