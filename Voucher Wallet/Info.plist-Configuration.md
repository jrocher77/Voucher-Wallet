# Configuration Info.plist pour Voucher Wallet

Pour permettre à l'application d'importer et d'ouvrir des fichiers PDF, vous devez ajouter les configurations suivantes dans votre fichier `Info.plist` :

## 1. Types de documents supportés

Ajoutez cette clé pour déclarer que l'app peut ouvrir des fichiers PDF :

```xml
<key>CFBundleDocumentTypes</key>
<array>
    <dict>
        <key>CFBundleTypeName</key>
        <string>PDF Document</string>
        <key>LSHandlerRank</key>
        <string>Alternate</string>
        <key>LSItemContentTypes</key>
        <array>
            <string>com.adobe.pdf</string>
        </array>
    </dict>
</array>
```

## 2. Support pour l'ouverture depuis d'autres apps

Ajoutez cette clé pour permettre l'ouverture de PDFs partagés depuis d'autres apps :

```xml
<key>UTImportedTypeDeclarations</key>
<array>
    <dict>
        <key>UTTypeConformsTo</key>
        <array>
            <string>public.data</string>
            <string>public.content</string>
        </array>
        <key>UTTypeDescription</key>
        <string>PDF Document</string>
        <key>UTTypeIdentifier</key>
        <string>com.adobe.pdf</string>
        <key>UTTypeTagSpecification</key>
        <dict>
            <key>public.filename-extension</key>
            <array>
                <string>pdf</string>
            </array>
            <key>public.mime-type</key>
            <array>
                <string>application/pdf</string>
            </array>
        </dict>
    </dict>
</array>
```

## 3. Permissions de confidentialité (si nécessaire)

Si vous utilisez la caméra pour scanner (future fonctionnalité), ajoutez :

```xml
<key>NSCameraUsageDescription</key>
<string>L'appareil photo est utilisé pour scanner les bons d'achat</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Accédez à vos photos pour importer des bons d'achat</string>
```

## Configuration dans Xcode

### Méthode alternative via Xcode :

1. Sélectionnez votre cible dans Xcode
2. Allez dans l'onglet **Info**
3. Dans **Document Types**, cliquez sur **+** et ajoutez :
   - **Name**: PDF Document
   - **Types**: com.adobe.pdf
   - **Role**: Alternate

4. Dans **Imported Type Identifiers**, ajoutez **com.adobe.pdf**

## Test de la fonctionnalité

Une fois configuré, vous pourrez :

✅ Ouvrir des PDFs depuis l'app Fichiers avec "Partager" → "Voucher Wallet"
✅ Recevoir des PDFs depuis Mail, Messages, etc.
✅ Ouvrir des PDFs téléchargés depuis Safari
✅ Utiliser le sélecteur de fichiers dans l'app

## Note importante

Ces configurations permettent à votre app d'apparaître dans la liste des apps compatibles lorsque l'utilisateur souhaite partager ou ouvrir un fichier PDF depuis une autre application.
