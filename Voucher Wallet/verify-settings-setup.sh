#!/bin/bash

# Script de vérification de la configuration des Réglages iOS
# Pour Voucher Wallet

echo "🔍 Vérification de la configuration des Réglages iOS..."
echo ""

# Fonction pour vérifier l'existence d'un fichier
check_file() {
    if [ -f "$1" ]; then
        echo "✅ $1"
        return 0
    else
        echo "❌ $1 (manquant)"
        return 1
    fi
}

# Fonction pour vérifier l'existence d'un dossier
check_dir() {
    if [ -d "$1" ]; then
        echo "✅ $1/"
        return 0
    else
        echo "❌ $1/ (manquant)"
        return 1
    fi
}

# Fonction pour vérifier le contenu d'un fichier
check_content() {
    if grep -q "$2" "$1" 2>/dev/null; then
        echo "✅ $1 contient '$2'"
        return 0
    else
        echo "⚠️  $1 ne contient pas '$2'"
        return 1
    fi
}

echo "📁 Structure des fichiers"
echo "========================="

# Vérifier Settings.bundle
check_dir "Settings.bundle"
check_file "Settings.bundle/Root.plist"
check_file "Settings.bundle/Statistics.plist"

echo ""
echo "🔧 Fichiers Swift"
echo "================="

# Vérifier les fichiers Swift
check_file "UtilitiesSettingsManager.swift"
check_file "ModifiersSettingsMonitorModifier.swift"
check_file "UtilitiesStoreNameLearning.swift"
check_file "ContentView.swift"

echo ""
echo "📝 Contenu des fichiers"
echo "======================="

# Vérifier que ContentView utilise le modifier
check_content "ContentView.swift" "monitorSettingsChanges"

# Vérifier que StoreNameLearning envoie les notifications
check_content "UtilitiesStoreNameLearning.swift" "learningDataDidChange"
check_content "UtilitiesStoreNameLearning.swift" "updateSettingsStatistics"

# Vérifier les clés dans Root.plist
if [ -f "Settings.bundle/Root.plist" ]; then
    echo "✅ Root.plist - Vérification des clés"
    
    if grep -q "reset_learning_requested" "Settings.bundle/Root.plist"; then
        echo "  ✅ Clé 'reset_learning_requested' trouvée"
    else
        echo "  ❌ Clé 'reset_learning_requested' manquante"
    fi
    
    if grep -q "PSToggleSwitchSpecifier" "Settings.bundle/Root.plist"; then
        echo "  ✅ Toggle de réinitialisation configuré"
    else
        echo "  ⚠️  Toggle de réinitialisation non configuré"
    fi
fi

echo ""
echo "📚 Documentation"
echo "================"

check_file "README-SETTINGS.md"
check_file "SETTINGS-CONFIGURATION.md"

echo ""
echo "🎯 Résumé"
echo "========="

total_files=9
found_files=0

for file in "Settings.bundle/Root.plist" "Settings.bundle/Statistics.plist" \
            "UtilitiesSettingsManager.swift" "ModifiersSettingsMonitorModifier.swift" \
            "UtilitiesStoreNameLearning.swift" "ContentView.swift" \
            "README-SETTINGS.md" "SETTINGS-CONFIGURATION.md"; do
    if [ -f "$file" ] || [ -d "$file" ]; then
        ((found_files++))
    fi
done

echo "$found_files/$total_files fichiers présents"

if [ $found_files -eq $total_files ]; then
    echo ""
    echo "✅ Configuration complète !"
    echo ""
    echo "📱 Prochaines étapes :"
    echo "   1. Ouvrez le projet dans Xcode"
    echo "   2. Vérifiez que Settings.bundle est dans la cible (target)"
    echo "   3. Lancez l'app sur simulateur ou appareil"
    echo "   4. Ouvrez Réglages iOS → Voucher Wallet"
    echo ""
    exit 0
else
    echo ""
    echo "⚠️  Configuration incomplète"
    echo ""
    echo "📖 Consultez README-SETTINGS.md pour les instructions"
    echo ""
    exit 1
fi
