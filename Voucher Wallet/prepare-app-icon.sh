#!/bin/bash

# Script pour préparer les assets d'icône pour Voucher Wallet
# Usage: ./prepare-app-icon.sh <path-to-1024x1024-icon.png>

set -e

echo "🎨 Générateur d'Icônes iOS pour Voucher Wallet"
echo "=============================================="
echo ""

# Vérifier qu'ImageMagick est installé
if ! command -v convert &> /dev/null; then
    echo "❌ ImageMagick n'est pas installé."
    echo "📦 Installez-le avec: brew install imagemagick"
    exit 1
fi

# Vérifier qu'un fichier source est fourni
if [ -z "$1" ]; then
    echo "❌ Veuillez fournir une image source 1024x1024px"
    echo "Usage: ./prepare-app-icon.sh icon-source.png"
    exit 1
fi

SOURCE_IMAGE="$1"

# Vérifier que le fichier existe
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "❌ Le fichier $SOURCE_IMAGE n'existe pas"
    exit 1
fi

# Créer le dossier de sortie
OUTPUT_DIR="AppIcon.appiconset"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "📁 Création du dossier: $OUTPUT_DIR"
echo ""

# Définir les tailles à générer
declare -A SIZES=(
    # iPhone
    ["iphone-60x60@2x.png"]=120
    ["iphone-60x60@3x.png"]=180
    
    # iPad
    ["ipad-20x20.png"]=20
    ["ipad-20x20@2x.png"]=40
    ["ipad-29x29.png"]=29
    ["ipad-29x29@2x.png"]=58
    ["ipad-40x40.png"]=40
    ["ipad-40x40@2x.png"]=80
    ["ipad-76x76.png"]=76
    ["ipad-76x76@2x.png"]=152
    ["ipad-83.5x83.5@2x.png"]=167
    
    # App Store
    ["app-store.png"]=1024
)

# Générer toutes les tailles
echo "🔄 Génération des icônes..."
for filename in "${!SIZES[@]}"; do
    size=${SIZES[$filename]}
    echo "   → $filename (${size}x${size}px)"
    convert "$SOURCE_IMAGE" -resize ${size}x${size} "$OUTPUT_DIR/$filename"
done

echo ""
echo "📄 Création du fichier Contents.json..."

# Créer le Contents.json
cat > "$OUTPUT_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "iphone-60x60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "iphone-60x60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "ipad-20x20.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "20x20"
    },
    {
      "filename" : "ipad-20x20@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "ipad-29x29.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "29x29"
    },
    {
      "filename" : "ipad-29x29@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "ipad-40x40.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "40x40"
    },
    {
      "filename" : "ipad-40x40@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "ipad-76x76.png",
      "idiom" : "ipad",
      "scale" : "1x",
      "size" : "76x76"
    },
    {
      "filename" : "ipad-76x76@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "76x76"
    },
    {
      "filename" : "ipad-83.5x83.5@2x.png",
      "idiom" : "ipad",
      "scale" : "2x",
      "size" : "83.5x83.5"
    },
    {
      "filename" : "app-store.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo ""
echo "✅ Terminé !"
echo ""
echo "📦 Toutes les icônes ont été générées dans: $OUTPUT_DIR"
echo ""
echo "🚀 Prochaines étapes:"
echo "   1. Ouvrez votre projet Xcode"
echo "   2. Allez dans Assets.xcassets"
echo "   3. Supprimez l'ancien AppIcon (si existant)"
echo "   4. Glissez-déposez le dossier '$OUTPUT_DIR'"
echo ""
echo "💡 Conseil: Vérifiez que l'icône est nette à petite taille (60x60px)"
echo ""
