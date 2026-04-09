//
//  ShareViewController.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

/// Vue pour gérer l'import de PDF via le partage système
struct PDFImportHandler: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Requête pour récupérer tous les bons existants
    @Query private var existingVouchers: [Voucher]
    
    let pdfData: Data
    
    @State private var isAnalyzing = true
    @State private var analysisResult: PDFAnalyzer.AnalysisResult?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var duplicateVoucherIds: Set<UUID> = [] // IDs des bons déjà présents
    
    // États pour la progression de l'analyse
    @State private var progressMessage = "Chargement du PDF..."
    @State private var progressValue: Double = 0.0
    @State private var totalPages: Int = 1
    
    // Pour la gestion multi-bons
    @State private var detectedVouchers: [PDFAnalyzer.DetectedVoucher] = []
    @State private var selectedVoucherIds: Set<UUID> = []
    @State private var editingVoucher: PDFAnalyzer.DetectedVoucher?
    @State private var showingVoucherEditor = false
    
    // Couleurs globales pour l'import multi-bons
    @State private var globalCardColor = Color(hex: "#007AFF")
    @State private var globalTextColor = Color(hex: "#FFFFFF")
    
    // Champs du formulaire (pour un seul bon)
    @State private var storeName = ""
    @State private var amount = ""
    @State private var voucherNumber = ""
    @State private var pinCode = ""
    @State private var codeType: CodeType = .barcode
    @State private var expirationDate: Date?
    @State private var hasExpirationDate = false
    @State private var selectedColor = Color(hex: "#007AFF")
    @State private var selectedTextColor = Color(hex: "#FFFFFF")
    
    // Mode d'affichage : formulaire unique ou sélection multiple
    private var showingMultipleVouchers: Bool {
        detectedVouchers.count > 1
    }
    
    var body: some View {
        NavigationStack {
            Form {
                if isAnalyzing {
                    Section {
                        VStack(spacing: 16) {
                            // Barre de progression
                            ProgressView(value: progressValue, total: 1.0)
                                .progressViewStyle(.linear)
                                .tint(.blue)
                            
                            // Message de progression
                            VStack(spacing: 4) {
                                Text(progressMessage)
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                Text("\(Int(progressValue * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    if analysisResult != nil {
                        Section {
                            Label("PDF analysé avec succès", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .fontWeight(.semibold)
                            
                            if showingMultipleVouchers {
                                Text("\(detectedVouchers.count) bons détectés")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Afficher la liste des bons si plusieurs détectés
                    if showingMultipleVouchers {
                        multipleVouchersSection
                    } else {
                        // Sinon, afficher le formulaire classique
                        voucherFormSection
                    }
                }
            }
            .navigationTitle("Nouveau Bon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    if showingMultipleVouchers {
                        Button("Importer (\(selectedVoucherIds.count))") {
                            importSelectedVouchers()
                        }
                        .disabled(selectedVoucherIds.isEmpty)
                    } else {
                        Button("Enregistrer") {
                            saveVoucher()
                        }
                        .disabled(isAnalyzing || !isFormValid)
                    }
                }
            }
            .task {
                await analyzePDF()
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingVoucherEditor) {
                if let voucher = editingVoucher {
                    VoucherEditorView(
                        voucher: voucher,
                        onSave: { updatedVoucher in
                            updateVoucher(updatedVoucher)
                            showingVoucherEditor = false
                        }
                    )
                }
            }
        }
    }
    
    private var voucherFormSection: some View {
        Group {
            // Afficher le score de confiance si disponible
            if let result = analysisResult,
               let detectedName = result.detectedStoreName,
               result.storeNameConfidence > 0 {
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Enseigne détectée")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 8) {
                                Text(detectedName)
                                    .font(.headline)
                                
                                confidenceBadge(for: result.storeNameConfidence)
                            }
                        }
                        
                        Spacer()
                        
                        if result.storeNameConfidence < 0.7 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if result.storeNameConfidence < 0.7 {
                        Text("La détection automatique n'est pas très sûre. Vérifiez le nom de l'enseigne.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            Section("Informations du bon") {
                TextField("Enseigne", text: $storeName)
                
                TextField("Montant (optionnel)", text: $amount)
                    .keyboardType(.decimalPad)
                
                TextField("Numéro du bon", text: $voucherNumber)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                
                // ⚠️ Avertissement si le numéro existe déjà
                if !voucherNumber.isEmpty && isVoucherNumberDuplicate(voucherNumber) {
                    Label {
                        Text("Ce numéro de bon existe déjà dans votre wallet")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
                
                if let result = analysisResult, !result.possibleVoucherNumbers.isEmpty {
                    Menu("Numéros suggérés") {
                        ForEach(result.possibleVoucherNumbers, id: \.self) { number in
                            Button(number) {
                                voucherNumber = number
                            }
                        }
                    }
                    .font(.caption)
                }
                
                TextField("Code PIN (optionnel)", text: $pinCode)
                    .textContentType(.none)
                    .autocorrectionDisabled()
            }
            
            Section("Type de code") {
                Picker("Type", selection: $codeType) {
                    Label("Code-barres", systemImage: "barcode")
                        .tag(CodeType.barcode)
                    Label("QR Code", systemImage: "qrcode")
                        .tag(CodeType.qrCode)
                }
                .pickerStyle(.segmented)
            }
            
            Section("Date d'expiration") {
                Toggle("Ajouter une date d'expiration", isOn: $hasExpirationDate)
                
                if hasExpirationDate {
                    DatePicker(
                        "Date",
                        selection: Binding(
                            get: { expirationDate ?? Date() },
                            set: { expirationDate = $0 }
                        ),
                        displayedComponents: .date
                    )
                }
            }
            
            Section("Couleur de la carte") {
                ColorPicker("Couleur de fond", selection: $selectedColor, supportsOpacity: false)
                    .onChange(of: selectedColor) { oldValue, newValue in
                        // 🎨 Suggestion automatique de couleur de texte basée sur la couleur de fond
                        if areColorsTooSimilar(newValue, selectedTextColor) {
                            let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: newValue.toHex())
                            selectedTextColor = Color(hex: suggestedTextColor)
                        }
                    }
                
                ColorPicker("Couleur du texte", selection: $selectedTextColor, supportsOpacity: false)
                
                // ⚠️ Avertissement si couleurs trop similaires
                if areColorsTooSimilar(selectedColor, selectedTextColor) {
                    Label {
                        Text("⚠️ Les couleurs sont identiques ou trop similaires. Le texte sera illisible.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
                
                // ✅ Indicateur de bon contraste
                if !areColorsTooSimilar(selectedColor, selectedTextColor) {
                    Label {
                        Text("Bon contraste pour la lisibilité")
                    } icon: {
                        Image(systemName: "checkmark.circle.fill")
                    }
                    .font(.caption)
                    .foregroundStyle(.green)
                }
                
                // Prévisualisation de la carte
                VStack(alignment: .leading, spacing: 8) {
                    Text("Aperçu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(storeName.isEmpty ? "Enseigne" : storeName)
                                .font(.headline)
                                .foregroundStyle(selectedTextColor)
                            
                            Text(voucherNumber.isEmpty ? "1234567890" : voucherNumber)
                                .font(.caption)
                                .foregroundStyle(selectedTextColor.opacity(0.8))
                        }
                        Spacer()
                        if let amt = Double(amount) {
                            Text(amt.formattedEuro)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(selectedTextColor)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedColor)
                    )
                }
                
                // Préréglages de couleurs populaires
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couleurs de fond populaires")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ColorPresets.allPresets, id: \.hex) { preset in
                                Button {
                                    selectedColor = Color(hex: preset.hex)
                                    // 🎨 Suggestion automatique de couleur de texte
                                    let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: preset.hex)
                                    selectedTextColor = Color(hex: suggestedTextColor)
                                } label: {
                                    VStack(spacing: 4) {
                                        Circle()
                                            .fill(Color(hex: preset.hex))
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                if selectedColor.isSimilar(to: Color(hex: preset.hex)) {
                                                    Circle()
                                                        .stroke(Color.primary, lineWidth: 3)
                                                }
                                            }
                                        
                                        Text(preset.name)
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                // Préréglages pour la couleur de texte
                VStack(alignment: .leading, spacing: 8) {
                    Text("Couleurs de texte populaires")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack(spacing: 12) {
                        ForEach([
                            ("Blanc", "#FFFFFF"),
                            ("Noir", "#000000"),
                            ("Gris clair", "#E5E5EA"),
                            ("Gris foncé", "#3A3A3C")
                        ], id: \.1) { preset in
                            Button {
                                selectedTextColor = Color(hex: preset.1)
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: preset.1))
                                        .frame(width: 40, height: 40)
                                        .overlay {
                                            Circle()
                                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                            if selectedTextColor.isSimilar(to: Color(hex: preset.1)) {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 3)
                                            }
                                        }
                                    
                                    Text(preset.0)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    private var multipleVouchersSection: some View {
        Group {
            Section {
                // Afficher un message si des doublons sont détectés
                if !duplicateVoucherIds.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(duplicateVoucherIds.count) bon(s) déjà présent(s)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Ces bons ne peuvent pas être importés à nouveau")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                ForEach(detectedVouchers) { voucher in
                    let isDuplicate = duplicateVoucherIds.contains(voucher.id)
                    
                    HStack {
                        // Checkbox
                        Button {
                            toggleSelection(voucher.id)
                        } label: {
                            Image(systemName: isDuplicate ? "xmark.circle.fill" : (selectedVoucherIds.contains(voucher.id) ? "checkmark.circle.fill" : "circle"))
                                .foregroundColor(isDuplicate ? .red : (selectedVoucherIds.contains(voucher.id) ? .blue : .gray))
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .disabled(isDuplicate)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(voucher.storeName ?? "Enseigne inconnue")
                                    .font(.headline)
                                    .foregroundColor(isDuplicate ? .secondary : .primary)
                                
                                // Badge "Déjà importé"
                                if isDuplicate {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.seal.fill")
                                            .font(.system(size: 10))
                                        Text("Déjà importé")
                                            .font(.system(size: 11, weight: .medium))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.red.opacity(0.15))
                                    .foregroundColor(.red)
                                    .clipShape(Capsule())
                                }
                                // Badge de confiance (seulement si non-dupliqué)
                                else if voucher.storeNameConfidence > 0 {
                                    confidenceBadge(for: voucher.storeNameConfidence)
                                }
                            }
                            
                            Text(voucher.voucherNumber)
                                .font(.caption)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .foregroundColor(.secondary)
                            
                            if let amount = voucher.amount {
                                Text(amount.formattedEuro)
                                    .font(.subheadline)
                                    .foregroundColor(isDuplicate ? .secondary : .blue)
                            }
                        }
                        
                        Spacer()
                        
                        // Bouton modifier (seulement si non-dupliqué)
                        if !isDuplicate {
                            Button {
                                editingVoucher = voucher
                                showingVoucherEditor = true
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if !isDuplicate {
                            toggleSelection(voucher.id)
                        }
                    }
                    .opacity(isDuplicate ? 0.6 : 1.0)
                }
                
                // Bouton pour tout sélectionner/désélectionner
                Button {
                    let nonDuplicateIds = Set(detectedVouchers.filter { !duplicateVoucherIds.contains($0.id) }.map { $0.id })
                    
                    if selectedVoucherIds.count == nonDuplicateIds.count {
                        selectedVoucherIds.removeAll()
                    } else {
                        selectedVoucherIds = nonDuplicateIds
                    }
                } label: {
                    HStack {
                        let nonDuplicateCount = detectedVouchers.filter { !duplicateVoucherIds.contains($0.id) }.count
                        let allNonDuplicatesSelected = selectedVoucherIds.count == nonDuplicateCount
                        
                        Image(systemName: allNonDuplicatesSelected ? "checkmark.circle.fill" : "circle")
                        Text(allNonDuplicatesSelected ? "Tout désélectionner" : "Tout sélectionner")
                    }
                }
            } header: {
                Text("Sélectionnez les bons à importer")
            }
            
            // Section de personnalisation globale des couleurs (EN BAS)
            globalColorCustomizationSection
        }
    }
    
    // MARK: - Global Color Customization Section
    
    private var globalColorCustomizationSection: some View {
        Section {
            ColorPicker("Couleur de fond", selection: $globalCardColor, supportsOpacity: false)
                .onChange(of: globalCardColor) { oldValue, newValue in
                    // 🎨 Suggestion automatique de couleur de texte basée sur la couleur de fond
                    if areColorsTooSimilar(newValue, globalTextColor) {
                        let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: newValue.toHex())
                        globalTextColor = Color(hex: suggestedTextColor)
                    }
                }
            
            ColorPicker("Couleur du texte", selection: $globalTextColor, supportsOpacity: false)
            
            // ⚠️ Avertissement si couleurs trop similaires
            if areColorsTooSimilar(globalCardColor, globalTextColor) {
                Label {
                    Text("⚠️ Les couleurs sont identiques ou trop similaires. Le texte sera illisible.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            
            // ✅ Indicateur de bon contraste
            if !areColorsTooSimilar(globalCardColor, globalTextColor) {
                Label {
                    Text("Bon contraste pour la lisibilité")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.green)
            }
            
            // Prévisualisation de la carte
            VStack(alignment: .leading, spacing: 8) {
                Text("Aperçu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enseigne exemple")
                            .font(.headline)
                            .foregroundStyle(globalTextColor)
                        
                        Text("1234567890")
                            .font(.caption)
                            .foregroundStyle(globalTextColor.opacity(0.8))
                    }
                    Spacer()
                    Text("50,00 €")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(globalTextColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(globalCardColor)
                )
            }
            
            // Préréglages de couleurs pour le fond
            VStack(alignment: .leading, spacing: 8) {
                Text("Couleurs de fond populaires")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ColorPresets.allPresets, id: \.hex) { preset in
                            Button {
                                globalCardColor = Color(hex: preset.hex)
                                // 🎨 Suggestion automatique de couleur de texte
                                let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: preset.hex)
                                globalTextColor = Color(hex: suggestedTextColor)
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if globalCardColor.isSimilar(to: Color(hex: preset.hex)) {
                                                Circle()
                                                    .stroke(Color.primary, lineWidth: 3)
                                            }
                                        }
                                    
                                    Text(preset.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // Préréglages pour la couleur de texte
            VStack(alignment: .leading, spacing: 8) {
                Text("Couleurs de texte populaires")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach([
                        ("Blanc", "#FFFFFF"),
                        ("Noir", "#000000"),
                        ("Gris clair", "#E5E5EA"),
                        ("Gris foncé", "#3A3A3C")
                    ], id: \.1) { preset in
                        Button {
                            globalTextColor = Color(hex: preset.1)
                        } label: {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: preset.1))
                                    .frame(width: 40, height: 40)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                        if globalTextColor.isSimilar(to: Color(hex: preset.1)) {
                                            Circle()
                                                .stroke(Color.primary, lineWidth: 3)
                                        }
                                    }
                                
                                Text(preset.0)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            Text("Personnalisation des couleurs (tous les bons)")
        } footer: {
            Text("Ces couleurs seront appliquées à tous les bons sélectionnés.")
        }
    }
    
    private var isFormValid: Bool {
        !storeName.isEmpty && !voucherNumber.isEmpty && !isVoucherNumberDuplicate(voucherNumber) && !areColorsTooSimilar(selectedColor, selectedTextColor)
    }
    
    /// Vérifie si un numéro de bon existe déjà dans le wallet
    private func isVoucherNumberDuplicate(_ number: String) -> Bool {
        existingVouchers.contains { $0.voucherNumber == number }
    }
    
    /// Vérifie si deux couleurs sont trop similaires pour une bonne lisibilité
    private func areColorsTooSimilar(_ color1: Color, _ color2: Color) -> Bool {
        let hex1 = color1.toHex()
        let hex2 = color2.toHex()
        
        // Comparaison exacte
        if hex1 == hex2 {
            return true
        }
        
        // Calcul de la différence de luminosité
        let luminance1 = calculateLuminance(hex: hex1)
        let luminance2 = calculateLuminance(hex: hex2)
        
        let contrastRatio = max(luminance1, luminance2) / min(luminance1, luminance2)
        
        // Un ratio de contraste < 3:1 est considéré comme insuffisant
        return contrastRatio < 3.0
    }
    
    /// Calcule la luminosité relative d'une couleur (formule W3C)
    private func calculateLuminance(hex: String) -> Double {
        let rgb = hexToRGB(hex)
        
        let r = rgb.r / 255.0
        let g = rgb.g / 255.0
        let b = rgb.b / 255.0
        
        let rLinear = r <= 0.03928 ? r / 12.92 : pow((r + 0.055) / 1.055, 2.4)
        let gLinear = g <= 0.03928 ? g / 12.92 : pow((g + 0.055) / 1.055, 2.4)
        let bLinear = b <= 0.03928 ? b / 12.92 : pow((b + 0.055) / 1.055, 2.4)
        
        return 0.2126 * rLinear + 0.7152 * gLinear + 0.0722 * bLinear
    }
    
    /// Convertit une couleur hex en RGB
    private func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        r = Double((int >> 16) & 0xFF)
        g = Double((int >> 8) & 0xFF)
        b = Double(int & 0xFF)
        return (r, g, b)
    }
    
    // MARK: - Actions Multi-Bons
    
    private func toggleSelection(_ id: UUID) {
        // Ne pas permettre la sélection des doublons
        if duplicateVoucherIds.contains(id) {
            return
        }
        
        if selectedVoucherIds.contains(id) {
            selectedVoucherIds.remove(id)
        } else {
            selectedVoucherIds.insert(id)
        }
    }
    
    /// Identifie les bons qui sont déjà présents dans le wallet
    private func identifyDuplicates() {
        var duplicateIds: Set<UUID> = []
        
        for voucher in detectedVouchers {
            if isVoucherNumberDuplicate(voucher.voucherNumber) {
                duplicateIds.insert(voucher.id)
            }
        }
        
        duplicateVoucherIds = duplicateIds
        
        // Afficher un message informatif si des doublons sont détectés
        if !duplicateIds.isEmpty {
            print("⚠️ \(duplicateIds.count) bon(s) déjà présent(s) dans le wallet")
        }
    }
    
    private func updateVoucher(_ updatedVoucher: PDFAnalyzer.DetectedVoucher) {
        if let index = detectedVouchers.firstIndex(where: { $0.id == updatedVoucher.id }) {
            detectedVouchers[index] = updatedVoucher
        }
    }
    
    private func importSelectedVouchers() {
        let selectedVouchers = detectedVouchers.filter { selectedVoucherIds.contains($0.id) }
        
        // ⚠️ Normalement, tous les doublons sont déjà filtrés, mais vérification supplémentaire
        var validVouchers: [PDFAnalyzer.DetectedVoucher] = []
        
        for voucher in selectedVouchers {
            if !isVoucherNumberDuplicate(voucher.voucherNumber) {
                validVouchers.append(voucher)
            }
        }
        
        // Utiliser les couleurs globales pour tous les bons
        let colorHex = globalCardColor.toHex()
        let textColorHex = globalTextColor.toHex()
        
        // Importer seulement les bons valides
        for detectedVoucher in validVouchers {
            let codeImage: UIImage?
            if detectedVoucher.codeType == .qrCode {
                codeImage = BarcodeGenerator.generateQRCode(from: detectedVoucher.voucherNumber)
            } else {
                codeImage = BarcodeGenerator.generateBarcode(from: detectedVoucher.voucherNumber)
            }
            
            let voucher = Voucher(
                storeName: detectedVoucher.storeName ?? "Enseigne inconnue",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
                expirationDate: detectedVoucher.expirationDate,
                pdfData: pdfData,
                storeColor: colorHex,
                textColor: textColorHex
            )
            
            modelContext.insert(voucher)
            
            // 📚 Apprentissage : enregistrer chaque enseigne validée
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
                
                // 🎨 Apprentissage : enregistrer la préférence de couleur
                StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
                StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ \(validVouchers.count) bon(s) importé(s) avec succès")
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - Analyse PDF
    
    private func analyzePDF() async {
        do {
            print("🔍 PDFImportHandler - Starting PDF analysis...")
            
            // Passer le handler de progression
            let result = try await PDFAnalyzer.analyzePDF(data: pdfData) { progress in
                // Mettre à jour l'UI avec la progression
                progressMessage = progress.userMessage
                progressValue = progress.progress(totalPages: totalPages)
                
                // Extraire le nombre total de pages si disponible
                if case .analyzingPage(_, let total) = progress {
                    totalPages = total
                }
            }
            
            await MainActor.run {
                analysisResult = result
                
                print("📊 Analysis result:")
                print("  - Detected vouchers: \(result.detectedVouchers.count)")
                print("  - Detected store: \(result.detectedStoreName ?? "nil")")
                print("  - Voucher numbers: \(result.possibleVoucherNumbers)")
                print("  - PIN codes: \(result.possiblePinCodes)")
                print("  - Amounts: \(result.possibleAmounts)")
                print("  - Dates: \(result.possibleDates)")
                print("  - Barcodes: \(result.barcodes.count)")
                print("  - QR codes: \(result.qrCodes.count)")
                
                // Si plusieurs bons détectés, préparer la sélection
                if result.detectedVouchers.count > 1 {
                    print("🎉 \(result.detectedVouchers.count) bons détectés - Mode multi-sélection")
                    detectedVouchers = result.detectedVouchers
                    
                    // Identifier les doublons
                    identifyDuplicates()
                    
                    // Sélectionner tous les bons NON dupliqués par défaut
                    selectedVoucherIds = Set(
                        detectedVouchers
                            .filter { !duplicateVoucherIds.contains($0.id) }
                            .map { $0.id }
                    )
                    
                    // 🎨 Initialiser les couleurs globales avec la couleur de la première enseigne détectée
                    if let firstVoucher = detectedVouchers.first {
                        if let hexColor = firstVoucher.storeColor {
                            globalCardColor = Color(hex: hexColor)
                        } else if let storeName = firstVoucher.storeName {
                            globalCardColor = Color(hex: StorePreset.getColor(for: storeName))
                        }
                        
                        // Suggérer automatiquement la couleur de texte
                        let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: globalCardColor.toHex())
                        globalTextColor = Color(hex: suggestedTextColor)
                        
                        print("🎨 Couleurs globales initialisées : fond=\(globalCardColor.toHex()), texte=\(globalTextColor.toHex())")
                    }
                    
                    isAnalyzing = false
                    return
                }
                
                // Si un seul bon complet a été détecté, utiliser ses données
                if let singleVoucher = result.detectedVouchers.first {
                    print("✅ Bon complet détecté, pré-remplissage avec ses données")
                    storeName = singleVoucher.storeName ?? ""
                    voucherNumber = singleVoucher.voucherNumber
                    pinCode = singleVoucher.pinCode ?? ""
                    codeType = singleVoucher.codeType
                    
                    if let amount = singleVoucher.amount {
                        self.amount = String(format: "%.2f", amount)
                    }
                    
                    if let expDate = singleVoucher.expirationDate {
                        expirationDate = expDate
                        hasExpirationDate = true
                    }
                    
                    // Appliquer la couleur du bon détecté
                    if let hexColor = singleVoucher.storeColor {
                        selectedColor = Color(hex: hexColor)
                    } else {
                        selectedColor = Color(hex: StorePreset.getColor(for: storeName))
                    }
                    
                    // 🔧 Copier les infos de détection dans analysisResult pour afficher le badge
                    analysisResult?.detectedStoreName = singleVoucher.storeName
                    analysisResult?.storeNameConfidence = singleVoucher.storeNameConfidence
                    
                    print("  ✓ Store: \(storeName)")
                    print("  ✓ Number: \(voucherNumber)")
                    print("  ✓ PIN: \(pinCode)")
                    print("  ✓ Amount: \(self.amount)")
                    print("  ✓ Confidence: \(String(format: "%.0f%%", singleVoucher.storeNameConfidence * 100))")
                } else {
                    // Sinon, utiliser les suggestions individuelles (ancien comportement)
                    print("⚠️ Aucun bon complet détecté, utilisation des suggestions")
                    
                    // Pré-remplir le nom de l'enseigne si détecté
                    if let detectedStore = result.detectedStoreName {
                        storeName = detectedStore
                        selectedColor = Color(hex: StorePreset.getColor(for: detectedStore))
                        print("✅ Store name set to: \(detectedStore)")
                    }
                    
                    // Pré-remplir les champs
                    if let firstNumber = result.possibleVoucherNumbers.first {
                        voucherNumber = firstNumber
                        print("✅ Voucher number set to: \(firstNumber)")
                    }
                    
                    if let firstPin = result.possiblePinCodes.first {
                        pinCode = firstPin
                        print("✅ PIN code set to: \(firstPin)")
                    }
                    
                    if let firstAmount = result.possibleAmounts.first {
                        amount = String(format: "%.2f", firstAmount)
                        print("✅ Amount set to: \(firstAmount)")
                    }
                    
                    if let firstDate = result.possibleDates.first {
                        expirationDate = firstDate
                        hasExpirationDate = true
                        print("✅ Expiration date set to: \(firstDate)")
                    }
                    
                    // Déterminer le type de code
                    if !result.qrCodes.isEmpty && result.barcodes.isEmpty {
                        codeType = .qrCode
                        print("✅ Code type set to: QR Code")
                    } else if !result.barcodes.isEmpty && result.qrCodes.isEmpty {
                        codeType = .barcode
                        print("✅ Code type set to: Barcode")
                    }
                }
                
                isAnalyzing = false
                print("✅ PDF analysis completed")
            }
        } catch {
            await MainActor.run {
                print("❌ PDF analysis error: \(error.localizedDescription)")
                errorMessage = "Erreur lors de l'analyse : \(error.localizedDescription)"
                showingError = true
                isAnalyzing = false
            }
        }
    }
    
    private func saveVoucher() {
        // 🚫 Vérifier si le bon existe déjà
        if isVoucherNumberDuplicate(voucherNumber) {
            errorMessage = "Le bon avec le numéro \(voucherNumber) existe déjà dans votre wallet."
            showingError = true
            return
        }
        
        let codeImage: UIImage?
        if codeType == .qrCode {
            codeImage = BarcodeGenerator.generateQRCode(from: voucherNumber)
        } else {
            codeImage = BarcodeGenerator.generateBarcode(from: voucherNumber)
        }
        
        let colorHex = selectedColor.toHex()
        let textColorHex = selectedTextColor.toHex()
        
        let voucher = Voucher(
            storeName: storeName,
            amount: Double(amount),
            voucherNumber: voucherNumber,
            pinCode: pinCode.isEmpty ? nil : pinCode,
            codeType: codeType,
            codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: hasExpirationDate ? expirationDate : nil,
            pdfData: pdfData,
            storeColor: colorHex,
            textColor: textColorHex
        )
        
        modelContext.insert(voucher)
        
        do {
            try modelContext.save()
            
            // 📚 Apprentissage : enregistrer le nom de l'enseigne validé
            let detectedName = analysisResult?.detectedStoreName
            StoreNameLearning.shared.learnStoreName(storeName, detectedAs: detectedName)
            
            // 🎨 Apprentissage : enregistrer la préférence de couleur
            StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
            StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
            
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
        }
    }
    
    // MARK: - UI Helpers
    
    /// Crée un badge visuel pour afficher le score de confiance
    @ViewBuilder
    private func confidenceBadge(for confidence: Double) -> some View {
        let percentage = Int(confidence * 100)
        let (color, icon) = confidenceStyle(for: confidence)
        
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 10))
            Text("Confiance \(percentage)%")
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
    
    /// Retourne la couleur et l'icône selon le score de confiance
    private func confidenceStyle(for confidence: Double) -> (Color, String) {
        switch confidence {
        case 0.8...1.0:
            return (.green, "checkmark.circle.fill")
        case 0.6..<0.8:
            return (.blue, "checkmark.circle")
        case 0.4..<0.6:
            return (.orange, "exclamationmark.circle")
        default:
            return (.red, "questionmark.circle")
        }
    }
}
