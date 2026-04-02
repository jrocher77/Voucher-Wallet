# Voucher Wallet - Guide de Développement

## 📱 Vue d'ensemble

Application iOS native pour gérer vos bons d'achat type Wallet. Supporte l'import de PDF, l'analyse automatique, et l'affichage de codes-barres scannables.

## 🏗️ Architecture

### Models
- **Voucher.swift** : Modèle SwiftData principal
- **StorePreset.swift** : Préréglages de couleurs pour 15 enseignes françaises

### Views
- **ContentView.swift** : Vue principale avec liste et filtres
- **VoucherCardView.swift** : Carte style Wallet avec couleurs personnalisées
- **VoucherDetailView.swift** : Vue détaillée avec code scannable
- **AddVoucherView.swift** : Ajout de bon (scan PDF ou manuel)
- **PDFImportHandler.swift** : Gestion du partage depuis d'autres apps

### Utilities
- **BarcodeGenerator.swift** : Génération de codes-barres et QR codes
- **PDFAnalyzer.swift** : Analyse intelligente de PDF avec Vision Framework
- **PreviewData.swift** : Données de test

## ✨ Fonctionnalités Implémentées

### ✅ Étape 1 : Modèle et Interface de base
- [x] Modèle SwiftData complet
- [x] Liste des bons avec design type Wallet
- [x] Couleurs personnalisées par enseigne (15 enseignes)
- [x] Filtres multi-critères (enseigne + expiration)
- [x] État vide avec onboarding

### ✅ Étape 2 : Vue détaillée et codes scannables
- [x] Génération de QR codes (CoreImage)
- [x] Génération de codes-barres Code128 (CoreImage)
- [x] Vue détaillée complète
- [x] Luminosité automatique à 100% pour scan
- [x] Code PIN masqué/révélable
- [x] Alerte pour bons expirés
- [x] Suppression de bon avec confirmation

### ✅ Étape 3 : Import et analyse de PDF
- [x] Sélecteur de fichiers PDF natif
- [x] Analyse automatique avec Vision Framework
- [x] OCR pour extraction de texte
- [x] Détection de codes-barres et QR codes
- [x] Extraction intelligente :
  - Numéros de bon (patterns multiples)
  - Codes PIN (4 chiffres)
  - Montants en euros
  - Dates d'expiration
- [x] Formulaire avec suggestions basées sur l'analyse
- [x] Saisie manuelle en alternative
- [x] Stockage du PDF original
- [x] Support du partage depuis d'autres apps

## 🔧 Technologies Utilisées (100% Native iOS)

- **SwiftUI** : Interface utilisateur
- **SwiftData** : Persistence locale
- **PDFKit** : Manipulation de PDF
- **Vision Framework** : OCR et détection de codes-barres
- **CoreImage** : Génération de codes-barres/QR
- **UniformTypeIdentifiers** : Gestion des types de fichiers

## 📋 Configuration Requise

### Info.plist

Consultez le fichier `Info.plist-Configuration.md` pour les configurations nécessaires :

1. **CFBundleDocumentTypes** : Déclarer les types de documents supportés (PDF)
2. **UTImportedTypeDeclarations** : Permettre l'import de PDF
3. Permissions caméra/photos (pour futures fonctionnalités)

### Capabilities

Aucune capability spéciale n'est requise pour les fonctionnalités actuelles.

## 🚀 Prochaines Étapes Possibles

### Étape 4 : Améliorations et polish
- [ ] Partage de bon (Share Sheet)
- [ ] Visualiseur PDF intégré
- [ ] Export de liste en PDF
- [ ] Recherche dans les bons
- [ ] Tri personnalisé
- [ ] Widgets iOS
- [ ] Notifications d'expiration
- [ ] Synchronisation iCloud
- [ ] Scan par caméra (OCR direct)
- [ ] Support Apple Wallet (fichier .pkpass)
- [ ] Dark mode optimisé
- [ ] Animations fluides
- [ ] Haptic feedback

### Améliorations de l'analyse PDF
- [ ] IA pour reconnaissance automatique d'enseigne
- [ ] Détection de logo pour couleur automatique
- [ ] Support de plus de formats de codes-barres
- [ ] Amélioration des patterns de détection
- [ ] Support multilingue

## 📊 Structure des Données

```swift
Voucher {
    id: UUID
    storeName: String
    amount: Double?
    voucherNumber: String
    pinCode: String?
    codeType: CodeType (.barcode | .qrCode)
    codeImageData: Data?
    expirationDate: Date?
    dateAdded: Date
    pdfData: Data?
    storeColor: String (hex)
}
```

## 🎨 Design

- Cartes style iOS Wallet
- Couleurs authentiques des enseignes
- Typographie système
- SF Symbols
- Design adaptatif
- Support du mode sombre
- Animations natives

## 🧪 Tests

Les Previews SwiftUI sont disponibles pour toutes les vues avec données de test.

Pour tester l'import PDF :
1. Utiliser le sélecteur de fichiers dans l'app
2. Partager un PDF depuis Mail/Safari/Fichiers vers l'app

## 📝 Notes de Développement

### Performance
- Les codes-barres sont générés une fois et stockés
- L'analyse PDF est asynchrone (async/await)
- SwiftData gère automatiquement la persistance

### Sécurité
- Les PDFs sont stockés localement uniquement
- Aucune donnée n'est envoyée sur le réseau
- Respect de la confidentialité utilisateur

### Compatibilité
- iOS 17.0+ (requis pour SwiftData)
- iPhone uniquement
- Portrait orientation recommandée

## 🐛 Known Issues / Limitations

- L'analyse PDF dépend de la qualité du document
- Certains formats de codes-barres exotiques ne sont pas supportés
- La détection automatique n'est pas parfaite (d'où la saisie manuelle)

## 👨‍💻 Développeur

JEREMY - Avril 2026

---

**Ready to build!** 🚀
