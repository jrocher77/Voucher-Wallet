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
    @State private var showingDuplicateAlert = false
    @State private var duplicateVoucherNumbers: [String] = []
    
    // États pour la progression de l'analyse
    @State private var progressMessage = "Chargement du PDF..."
    @State private var progressValue: Double = 0.0
    @State private var totalPages: Int = 1
    
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
                                    .foregroundStyle(.primary)
                                
                                Text("\(Int(progressValue * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                } else {
                    if let result = analysisResult {
                        Section {
                            Label("PDF analysé avec succès", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                            
                            if showingMultipleVouchers {
                                Text("\(detectedVouchers.count) bons détectés")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
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
            .alert("Bon(s) déjà importé(s)", isPresented: $showingDuplicateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                if duplicateVoucherNumbers.count == 1 {
                    Text("Le bon avec le numéro \(duplicateVoucherNumbers[0]) existe déjà dans votre wallet.")
                } else {
                    Text("Les bons suivants existent déjà dans votre wallet :\n\n\(duplicateVoucherNumbers.joined(separator: "\n"))")
                }
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
        }
    }
    
    private var multipleVouchersSection: some View {
        Section {
            ForEach(detectedVouchers) { voucher in
                HStack {
                    // Checkbox
                    Button {
                        toggleSelection(voucher.id)
                    } label: {
                        Image(systemName: selectedVoucherIds.contains(voucher.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedVoucherIds.contains(voucher.id) ? .blue : .gray)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(voucher.storeName ?? "Enseigne inconnue")
                                .font(.headline)
                            
                            // Badge de confiance
                            if voucher.storeNameConfidence > 0 {
                                confidenceBadge(for: voucher.storeNameConfidence)
                            }
                        }
                        
                        Text(voucher.voucherNumber)
                            .font(.caption)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.secondary)
                        
                        if let amount = voucher.amount {
                            Text(amount.formattedEuro)
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Spacer()
                    
                    // Bouton modifier
                    Button {
                        editingVoucher = voucher
                        showingVoucherEditor = true
                    } label: {
                        Image(systemName: "pencil.circle")
                            .foregroundStyle(.blue)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggleSelection(voucher.id)
                }
            }
            
            // Bouton pour tout sélectionner/désélectionner
            Button {
                if selectedVoucherIds.count == detectedVouchers.count {
                    selectedVoucherIds.removeAll()
                } else {
                    selectedVoucherIds = Set(detectedVouchers.map { $0.id })
                }
            } label: {
                HStack {
                    Image(systemName: selectedVoucherIds.count == detectedVouchers.count ? "checkmark.circle.fill" : "circle")
                    Text(selectedVoucherIds.count == detectedVouchers.count ? "Tout désélectionner" : "Tout sélectionner")
                }
            }
        } header: {
            Text("Sélectionnez les bons à importer")
        }
    }
    
    private var isFormValid: Bool {
        !storeName.isEmpty && !voucherNumber.isEmpty && !isVoucherNumberDuplicate(voucherNumber)
    }
    
    /// Vérifie si un numéro de bon existe déjà dans le wallet
    private func isVoucherNumberDuplicate(_ number: String) -> Bool {
        existingVouchers.contains { $0.voucherNumber == number }
    }
    
    // MARK: - Actions Multi-Bons
    
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
    
    private func importSelectedVouchers() {
        let selectedVouchers = detectedVouchers.filter { selectedVoucherIds.contains($0.id) }
        
        // 🚫 Filtrer les doublons
        var duplicates: [String] = []
        var validVouchers: [PDFAnalyzer.DetectedVoucher] = []
        
        for voucher in selectedVouchers {
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
            let codeImage: UIImage?
            if detectedVoucher.codeType == .qrCode {
                codeImage = BarcodeGenerator.generateQRCode(from: detectedVoucher.voucherNumber)
            } else {
                codeImage = BarcodeGenerator.generateBarcode(from: detectedVoucher.voucherNumber)
            }
            
            // Utiliser la couleur du bon détecté ou la couleur par défaut pour l'enseigne
            let colorHex = detectedVoucher.storeColor ?? StorePreset.getColor(for: detectedVoucher.storeName ?? "")
            
            let voucher = Voucher(
                storeName: detectedVoucher.storeName ?? "Enseigne inconnue",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
                expirationDate: detectedVoucher.expirationDate,
                pdfData: pdfData,
                storeColor: colorHex
            )
            
            modelContext.insert(voucher)
            
            // 📚 Apprentissage : enregistrer chaque enseigne validée
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
                
                // 🎨 Apprentissage : enregistrer la préférence de couleur
                StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
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
                    // Sélectionner tous par défaut
                    selectedVoucherIds = Set(detectedVouchers.map { $0.id })
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
            duplicateVoucherNumbers = [voucherNumber]
            showingDuplicateAlert = true
            return
        }
        
        let codeImage: UIImage?
        if codeType == .qrCode {
            codeImage = BarcodeGenerator.generateQRCode(from: voucherNumber)
        } else {
            codeImage = BarcodeGenerator.generateBarcode(from: voucherNumber)
        }
        
        let colorHex = selectedColor.toHex()
        
        let voucher = Voucher(
            storeName: storeName,
            amount: Double(amount),
            voucherNumber: voucherNumber,
            pinCode: pinCode.isEmpty ? nil : pinCode,
            codeType: codeType,
            codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: hasExpirationDate ? expirationDate : nil,
            pdfData: pdfData,
            storeColor: colorHex
        )
        
        modelContext.insert(voucher)
        
        do {
            try modelContext.save()
            
            // 📚 Apprentissage : enregistrer le nom de l'enseigne validé
            let detectedName = analysisResult?.detectedStoreName
            StoreNameLearning.shared.learnStoreName(storeName, detectedAs: detectedName)
            
            // 🎨 Apprentissage : enregistrer la préférence de couleur
            StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
            
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
