//
//  AddVoucherView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddVoucherView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Requête pour récupérer tous les bons existants
    @Query private var existingVouchers: [Voucher]
    
    @State private var addMethod: AddMethod = .scan
    @State private var showingDocumentPicker = false
    @State private var isAnalyzing = false
    @State private var analysisResult: PDFAnalyzer.AnalysisResult?
    @State private var selectedPDFData: Data?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDuplicateAlert = false
    @State private var duplicateVoucherNumbers: [String] = []
    
    // Pour la gestion multi-bons
    @State private var detectedVouchers: [PDFAnalyzer.DetectedVoucher] = []
    @State private var selectedVoucherIds: Set<UUID> = []
    @State private var editingVoucher: PDFAnalyzer.DetectedVoucher?
    @State private var showingVoucherEditor = false
    
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
    
    enum AddMethod {
        case scan
        case manual
    }
    
    // Mode d'affichage : formulaire unique ou sélection multiple
    private var showingMultipleVouchers: Bool {
        detectedVouchers.count > 1
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Choix de la méthode
                Section {
                    Picker("Méthode d'ajout", selection: $addMethod) {
                        Label("Scanner un PDF", systemImage: "doc.text.viewfinder")
                            .tag(AddMethod.scan)
                        Label("Saisie manuelle", systemImage: "keyboard")
                            .tag(AddMethod.manual)
                    }
                    .pickerStyle(.segmented)
                }
                
                if addMethod == .scan {
                    scanSection
                    
                    // Afficher la liste des bons si plusieurs détectés
                    if showingMultipleVouchers {
                        multipleVouchersSection
                    } else {
                        // Sinon, afficher le formulaire classique
                        voucherFormSection
                    }
                } else {
                    manualEntrySection
                    voucherFormSection
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
                        .disabled(!isFormValid)
                    }
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
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
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Bon(s) déjà importé(s)", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if duplicateVoucherNumbers.count == 1 {
                    Text("Le bon avec le numéro \(duplicateVoucherNumbers[0]) existe déjà dans votre wallet.")
                } else {
                    Text("Les bons suivants existent déjà dans votre wallet :\n\n\(duplicateVoucherNumbers.joined(separator: "\n"))")
                }
            }
        }
    }
    
    // MARK: - Scan Section
    
    private var scanSection: some View {
        Section {
            if isAnalyzing {
                HStack {
                    ProgressView()
                    Text("Analyse du PDF en cours...")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
            } else if let result = analysisResult {
                VStack(alignment: .leading, spacing: 12) {
                    Label("PDF analysé avec succès", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                    
                    if showingMultipleVouchers {
                        Text("• \(detectedVouchers.count) bon(s) détecté(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        if !result.barcodes.isEmpty {
                            Text("• \(result.barcodes.count) code(s)-barres détecté(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if !result.qrCodes.isEmpty {
                            Text("• \(result.qrCodes.count) QR code(s) détecté(s)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Button {
                        resetAndShowPicker()
                    } label: {
                        Label("Analyser un autre PDF", systemImage: "arrow.clockwise")
                    }
                }
                .padding(.vertical, 8)
            } else {
                Button {
                    showingDocumentPicker = true
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.badge.plus")
                            .font(.system(size: 50))
                            .foregroundStyle(.blue)
                        
                        Text("Sélectionner un PDF")
                            .font(.headline)
                        
                        Text("Le PDF sera analysé automatiquement")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Import PDF")
        } footer: {
            if !showingMultipleVouchers {
                Text("Importez le PDF de votre bon d'achat. L'application extraira automatiquement les informations.")
            }
        }
    }
    
    // MARK: - Multiple Vouchers Section
    
    private var multipleVouchersSection: some View {
        Section {
            // Bouton tout sélectionner
            HStack {
                Button {
                    if selectedVoucherIds.count == detectedVouchers.count {
                        selectedVoucherIds.removeAll()
                    } else {
                        selectedVoucherIds = Set(detectedVouchers.map { $0.id })
                    }
                } label: {
                    HStack {
                        Image(systemName: selectedVoucherIds.count == detectedVouchers.count ? "checkmark.square.fill" : "square")
                        Text(selectedVoucherIds.count == detectedVouchers.count ? "Tout désélectionner" : "Tout sélectionner")
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text("\(selectedVoucherIds.count)/\(detectedVouchers.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Liste des bons
            ForEach(detectedVouchers) { voucher in
                VoucherSelectionRowCompact(
                    voucher: voucher,
                    isSelected: selectedVoucherIds.contains(voucher.id),
                    onTap: {
                        toggleSelection(voucher.id)
                    },
                    onEdit: {
                        editingVoucher = voucher
                        showingVoucherEditor = true
                    }
                )
            }
        } header: {
            Text("Bons détectés")
        } footer: {
            Text("Appuyez sur un bon pour le modifier, ou sur le cercle pour le sélectionner/désélectionner.")
        }
    }
    
    // MARK: - Manual Entry Section
    
    private var manualEntrySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "keyboard")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                
                Text("Saisie manuelle")
                    .font(.headline)
                
                Text("Remplissez les champs ci-dessous")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Form Section
    
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
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                Text(detectedName)
                                    .font(.headline)
                                
                                confidenceBadge(for: result.storeNameConfidence)
                            }
                        }
                        
                        Spacer()
                        
                        if result.storeNameConfidence < 0.7 {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                                .font(.title3)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if result.storeNameConfidence < 0.7 {
                        Text("La détection automatique n'est pas très sûre. Vérifiez le nom de l'enseigne.")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
                    .foregroundStyle(.red)
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
                
                if let result = analysisResult, !result.possiblePinCodes.isEmpty {
                    Menu("Codes PIN suggérés") {
                        ForEach(result.possiblePinCodes, id: \.self) { pin in
                            Button(pin) {
                                pinCode = pin
                            }
                        }
                    }
                    .font(.caption)
                }
            }
            
            Section("Type de code") {
                Picker("Type", selection: $codeType) {
                    Label("Code-barres", systemImage: "barcode")
                        .tag(CodeType.barcode)
                    Label("QR Code", systemImage: "qrcode")
                        .tag(CodeType.qrCode)
                }
                .pickerStyle(.segmented)
                
                if let result = analysisResult {
                    if !result.barcodes.isEmpty && result.qrCodes.isEmpty {
                        Text("Code-barres détecté dans le PDF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if result.barcodes.isEmpty && !result.qrCodes.isEmpty {
                        Text("QR Code détecté dans le PDF")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    
                    if let result = analysisResult, !result.possibleDates.isEmpty {
                        Menu("Dates suggérées") {
                            ForEach(result.possibleDates, id: \.self) { date in
                                Button(date.frenchLongFormat) {
                                    expirationDate = date
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
            }
            
            Section("Couleur de la carte") {
                ColorPicker("Couleur de fond", selection: $selectedColor, supportsOpacity: false)
                    .onChange(of: selectedColor) { oldValue, newValue in
                        // 🎨 Suggestion automatique de couleur de texte basée sur la couleur de fond
                        // Seulement si les couleurs actuelles sont trop similaires
                        if areColorsTooSimilar(newValue, selectedTextColor) {
                            let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: newValue.toHex())
                            selectedTextColor = Color(hex: suggestedTextColor)
                            print("💡 Suggestion automatique de couleur de texte: \(suggestedTextColor)")
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
                
                // Préréglages de couleurs populaires pour le fond
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
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        // Vérifier que les champs essentiels sont remplis
        guard !storeName.isEmpty && !voucherNumber.isEmpty else {
            return false
        }
        
        // 🚫 Vérifier que le bon n'existe pas déjà
        guard !isVoucherNumberDuplicate(voucherNumber) else {
            return false
        }
        
        // 🎨 INTERDICTION : empêcher l'enregistrement si les couleurs sont trop similaires
        guard !areColorsTooSimilar(selectedColor, selectedTextColor) else {
            return false
        }
        
        return true
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
    
    // MARK: - Actions
    
    private func resetAndShowPicker() {
        detectedVouchers.removeAll()
        selectedVoucherIds.removeAll()
        analysisResult = nil
        selectedPDFData = nil
        showingDocumentPicker = true
    }
    
    private func toggleSelection(_ id: UUID) {
        if selectedVoucherIds.contains(id) {
            selectedVoucherIds.remove(id)
        } else {
            selectedVoucherIds.insert(id)
        }
    }
    
    private func updateVoucher(_ updatedVoucher: PDFAnalyzer.DetectedVoucher) {
        if let index = detectedVouchers.firstIndex(where: { $0.id == updatedVoucher.id }) {
            detectedVouchers[index] = updatedVoucher
        }
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            
            // Accéder au fichier de manière sécurisée
            guard url.startAccessingSecurityScopedResource() else {
                throw PDFAnalyzerError.invalidPDF
            }
            defer { url.stopAccessingSecurityScopedResource() }
            
            let data = try Data(contentsOf: url)
            selectedPDFData = data
            
            // Analyser le PDF
            Task {
                await analyzePDF(data: data)
            }
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
    
    private func analyzePDF(data: Data) async {
        isAnalyzing = true
        
        do {
            let result = try await PDFAnalyzer.analyzePDF(data: data)
            
            await MainActor.run {
                analysisResult = result
                isAnalyzing = false
                
                // Si plusieurs bons détectés, préparer la sélection
                if result.detectedVouchers.count > 1 {
                    print("🎉 \(result.detectedVouchers.count) bons détectés")
                    detectedVouchers = result.detectedVouchers
                    // Sélectionner tous par défaut
                    selectedVoucherIds = Set(detectedVouchers.map { $0.id })
                    return
                }
                
                // Si un seul bon détecté, pré-remplir avec ses données
                if let singleVoucher = result.detectedVouchers.first {
                    print("✅ 1 bon détecté, pré-remplissage automatique")
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
                    print("  ✓ Confidence: \(String(format: "%.0f%%", singleVoucher.storeNameConfidence * 100))")
                    
                    return
                }
                
                // Sinon, mode de détection global (ancien comportement)
                print("⚠️ Aucun bon complet détecté, utilisation des suggestions")
                
                // Pré-remplir le nom de l'enseigne si détecté
                if let detectedStore = result.detectedStoreName {
                    storeName = detectedStore
                    selectedColor = Color(hex: StorePreset.getColor(for: detectedStore))
                }
                
                // Pré-remplir les champs avec les résultats
                if let firstNumber = result.possibleVoucherNumbers.first {
                    voucherNumber = firstNumber
                }
                
                if let firstPin = result.possiblePinCodes.first {
                    pinCode = firstPin
                }
                
                if let firstAmount = result.possibleAmounts.first {
                    amount = String(format: "%.2f", firstAmount)
                }
                
                if let firstDate = result.possibleDates.first {
                    expirationDate = firstDate
                    hasExpirationDate = true
                }
                
                // Déterminer le type de code
                if !result.qrCodes.isEmpty && result.barcodes.isEmpty {
                    codeType = .qrCode
                } else if !result.barcodes.isEmpty && result.qrCodes.isEmpty {
                    codeType = .barcode
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erreur lors de l'analyse : \(error.localizedDescription)"
                showingError = true
                isAnalyzing = false
            }
        }
    }
    
    private func importSelectedVouchers() {
        let vouchersToImport = detectedVouchers.filter { selectedVoucherIds.contains($0.id) }
        
        // 🚫 Filtrer les doublons
        var duplicates: [String] = []
        var validVouchers: [PDFAnalyzer.DetectedVoucher] = []
        
        for voucher in vouchersToImport {
            if isVoucherNumberDuplicate(voucher.voucherNumber) {
                duplicates.append(voucher.voucherNumber)
            } else {
                validVouchers.append(voucher)
            }
        }
        
        // Afficher une alerte si des doublons sont détectés
        if !duplicates.isEmpty {
            duplicateVoucherNumbers = duplicates
            showingDuplicateAlert = true
            
            // Si tous les bons sont des doublons, on s'arrête là
            if validVouchers.isEmpty {
                return
            }
        }
        
        // Importer seulement les bons valides
        for detectedVoucher in validVouchers {
            // Utiliser la couleur du bon détecté ou la couleur par défaut pour l'enseigne
            let colorHex = detectedVoucher.storeColor ?? StorePreset.getColor(for: detectedVoucher.storeName ?? "")
            
            // Récupérer la couleur de texte apprise ou utiliser blanc par défaut
            let textColorHex: String
            if let storeName = detectedVoucher.storeName,
               let learnedTextColor = StoreNameLearning.shared.getLearnedTextColor(for: storeName) {
                textColorHex = learnedTextColor
            } else {
                textColorHex = "#FFFFFF"  // Blanc par défaut
            }
            
            let voucher = Voucher(
                storeName: detectedVoucher.storeName ?? "Bon d'achat",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: detectedVoucher.codeImageData,
                expirationDate: detectedVoucher.expirationDate,
                pdfData: selectedPDFData,
                storeColor: colorHex,
                textColor: textColorHex
            )
            
            modelContext.insert(voucher)
            
            // 📚 Apprentissage : enregistrer chaque enseigne validée
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
                
                // 🎨 Apprentissage : enregistrer les préférences de couleur
                StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
                StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ \(validVouchers.count) bon(s) importé(s) avec succès")
            if !duplicates.isEmpty {
                print("⚠️ \(duplicates.count) doublon(s) ignoré(s)")
            }
            
            // Fermer seulement si au moins un bon a été importé
            if !validVouchers.isEmpty {
                dismiss()
            }
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func saveVoucher() {
        // 🚫 Vérifier si le bon existe déjà
        if isVoucherNumberDuplicate(voucherNumber) {
            duplicateVoucherNumbers = [voucherNumber]
            showingDuplicateAlert = true
            return
        }
        
        // Générer l'image du code
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
            pdfData: selectedPDFData,
            storeColor: colorHex,
            textColor: textColorHex
        )
        
        modelContext.insert(voucher)
        
        do {
            try modelContext.save()
            
            // 📚 Apprentissage : enregistrer le nom de l'enseigne validé
            let detectedName = analysisResult?.detectedStoreName
            StoreNameLearning.shared.learnStoreName(storeName, detectedAs: detectedName)
            
            // 🎨 Apprentissage : enregistrer les préférences de couleur
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
        
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text("\(percentage)%")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
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

// MARK: - Voucher Selection Row Compact

struct VoucherSelectionRowCompact: View {
    let voucher: PDFAnalyzer.DetectedVoucher
    let isSelected: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: onTap) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .gray)
            }
            .buttonStyle(.plain)
            
            // Info du bon (cliquable pour éditer)
            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        HStack(spacing: 6) {
                            Text(voucher.storeName ?? "Bon d'achat")
                                .font(.body)
                                .fontWeight(.medium)
                            
                            // Badge de confiance
                            if voucher.storeNameConfidence > 0 {
                                confidenceBadge(for: voucher.storeNameConfidence)
                            }
                        }
                        
                        Spacer()
                        
                        if let amount = voucher.amount {
                            Text(amount, format: .currency(code: "EUR"))
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                        
                        Image(systemName: "pencil.circle")
                            .font(.body)
                            .foregroundStyle(.blue)
                    }
                    
                    HStack(spacing: 8) {
                        Label("Page \(voucher.pageNumber)", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if voucher.codeType == .qrCode {
                            Image(systemName: "qrcode")
                                .font(.caption)
                        } else {
                            Image(systemName: "barcode")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(.secondary)
                    
                    Text(voucher.voucherNumber)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    /// Badge de confiance pour la détection de l'enseigne
    @ViewBuilder
    private func confidenceBadge(for confidence: Double) -> some View {
        let percentage = Int(confidence * 100)
        let (color, icon) = confidenceStyle(for: confidence)
        
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text("\(percentage)%")
                .font(.system(size: 10, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.15))
        .foregroundStyle(color)
        .clipShape(Capsule())
    }
    
    /// Style selon le score de confiance
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

// MARK: - Voucher Editor View

struct VoucherEditorView: View {
    @Environment(\.dismiss) private var dismiss
    
    let voucher: PDFAnalyzer.DetectedVoucher
    let onSave: (PDFAnalyzer.DetectedVoucher) -> Void
    
    @State private var storeName: String
    @State private var amount: String
    @State private var voucherNumber: String
    @State private var pinCode: String
    @State private var codeType: CodeType
    @State private var expirationDate: Date?
    @State private var hasExpirationDate: Bool
    @State private var selectedColor: Color
    
    init(voucher: PDFAnalyzer.DetectedVoucher, onSave: @escaping (PDFAnalyzer.DetectedVoucher) -> Void) {
        self.voucher = voucher
        self.onSave = onSave
        
        _storeName = State(initialValue: voucher.storeName ?? "")
        _amount = State(initialValue: voucher.amount != nil ? String(format: "%.2f", voucher.amount!) : "")
        _voucherNumber = State(initialValue: voucher.voucherNumber)
        _pinCode = State(initialValue: voucher.pinCode ?? "")
        _codeType = State(initialValue: voucher.codeType)
        _expirationDate = State(initialValue: voucher.expirationDate)
        _hasExpirationDate = State(initialValue: voucher.expirationDate != nil)
        
        // Initialiser la couleur à partir du hex stocké ou utiliser la couleur par défaut
        if let hexColor = voucher.storeColor {
            _selectedColor = State(initialValue: Color(hex: hexColor))
        } else {
            let defaultHex = StorePreset.getColor(for: voucher.storeName ?? "")
            _selectedColor = State(initialValue: Color(hex: defaultHex))
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Informations du bon") {
                    TextField("Enseigne", text: $storeName)
                    
                    TextField("Montant (optionnel)", text: $amount)
                        .keyboardType(.decimalPad)
                    
                    TextField("Numéro du bon", text: $voucherNumber)
                        .textContentType(.none)
                        .autocorrectionDisabled()
                    
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
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                    }
                }
                
                Section("Couleur de la carte") {
                    ColorPicker("Couleur", selection: $selectedColor, supportsOpacity: false)
                    
                    // Préréglages de couleurs populaires
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(ColorPresets.allPresets, id: \.hex) { preset in
                                Button {
                                    selectedColor = Color(hex: preset.hex)
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
                
                Section {
                    HStack {
                        Label("Page \(voucher.pageNumber)", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Modifier le bon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        saveChanges()
                    }
                    .disabled(storeName.isEmpty || voucherNumber.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        // Générer l'image du code si le numéro ou type a changé
        var codeImageData = voucher.codeImageData
        if voucherNumber != voucher.voucherNumber || codeType != voucher.codeType {
            let codeImage: UIImage?
            if codeType == .qrCode {
                codeImage = BarcodeGenerator.generateQRCode(from: voucherNumber)
            } else {
                codeImage = BarcodeGenerator.generateBarcode(from: voucherNumber)
            }
            codeImageData = codeImage.flatMap { BarcodeGenerator.imageToData($0) }
        }
        
        let updatedVoucher = PDFAnalyzer.DetectedVoucher(
            id: voucher.id,
            pageNumber: voucher.pageNumber,
            voucherNumber: voucherNumber,
            codeType: codeType,
            storeName: storeName.isEmpty ? nil : storeName,
            amount: Double(amount),
            pinCode: pinCode.isEmpty ? nil : pinCode,
            expirationDate: hasExpirationDate ? expirationDate : nil,
            codeImageData: codeImageData,
            storeColor: selectedColor.toHex()
        )
        
        onSave(updatedVoucher)
        dismiss()
    }
}

#Preview {
    AddVoucherView()
        .modelContainer(for: Voucher.self, inMemory: true)
}
