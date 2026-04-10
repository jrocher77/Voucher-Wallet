//
//  PDFImportHandler.swift
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
    
    // ViewModel centralisé
    @State private var viewModel = VoucherImportViewModel()
    
    // États UI
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
    @State private var detectedStoreConfidence: Double?
    
    var body: some View {
        NavigationStack {
            Form {
                if viewModel.isAnalyzing {
                    analysisProgressSection
                } else {
                    if viewModel.analysisResult != nil {
                        analysisSuccessSection
                    }
                    
                    // Import multiple ou formulaire unique
                    if viewModel.hasMultipleVouchers {
                        multipleVouchersSection
                    } else {
                        singleVoucherSection
                    }
                }
            }
            .navigationTitle("Nouveau Bon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    confirmButton
                }
            }
            .task {
                await analyzeAndSetup()
            }
            .alert("Erreur", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
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
    
    // MARK: - Sections
    
    private var analysisProgressSection: some View {
        Section {
            VStack(spacing: 16) {
                ProgressView(value: viewModel.progressValue, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                VStack(spacing: 4) {
                    Text(viewModel.progressMessage)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Text("\(Int(viewModel.progressValue * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }
    
    private var analysisSuccessSection: some View {
        Section {
            Label("PDF analysé avec succès", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
                .fontWeight(.semibold)
            
            if viewModel.hasMultipleVouchers {
                Text("\(viewModel.detectedVouchers.count) bons détectés")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    @ViewBuilder
    private var confirmButton: some View {
        if viewModel.hasMultipleVouchers {
            Button("Importer (\(viewModel.selectedCount))") {
                importSelectedVouchers()
            }
            .disabled(viewModel.selectedVoucherIds.isEmpty)
        } else {
            Button("Enregistrer") {
                saveVoucher()
            }
            .disabled(viewModel.isAnalyzing || !isFormValid)
        }
    }
    
    private var singleVoucherSection: some View {
        Group {
            VoucherFormFields(
                storeName: $storeName,
                amount: $amount,
                voucherNumber: $voucherNumber,
                pinCode: $pinCode,
                codeType: $codeType,
                expirationDate: $expirationDate,
                hasExpirationDate: $hasExpirationDate,
                analysisResult: viewModel.analysisResult,
                existingVouchers: existingVouchers,
                detectedStoreConfidence: detectedStoreConfidence
            )
            
            Section("Couleur de la carte") {
                ColorCustomizationSection(
                    cardColor: $selectedColor,
                    textColor: $selectedTextColor,
                    previewStoreName: storeName.isEmpty ? "Enseigne" : storeName,
                    previewVoucherNumber: voucherNumber.isEmpty ? "1234567890" : voucherNumber,
                    previewAmount: Double(amount).map { $0.formattedEuro }
                )
            }
        }
    }
    
    private var multipleVouchersSection: some View {
        Group {
            MultiVoucherList(
                vouchers: viewModel.detectedVouchers,
                selectedIds: viewModel.selectedVoucherIds,
                duplicateIds: viewModel.duplicateVoucherIds,
                onToggle: { id in viewModel.toggleSelection(id) },
                onEdit: { voucher in
                    editingVoucher = voucher
                    showingVoucherEditor = true
                }
            )
            
            Section {
                ColorCustomizationSection(
                    cardColor: $viewModel.globalCardColor,
                    textColor: $viewModel.globalTextColor
                )
            } header: {
                Text("Personnalisation des couleurs (tous les bons)")
            } footer: {
                Text("Ces couleurs seront appliquées à tous les bons sélectionnés.")
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !storeName.isEmpty && 
        !voucherNumber.isEmpty && 
        !VoucherDuplicateDetector.isDuplicate(voucherNumber: voucherNumber, in: existingVouchers) &&
        !ColorContrastHelper.areColorsTooSimilar(selectedColor, selectedTextColor)
    }
    
    // MARK: - Actions
    
    private func analyzeAndSetup() async {
        await viewModel.analyzePDF(data: pdfData)
        
        // Setup après l'analyse
        await MainActor.run {
            setupAfterAnalysis()
        }
    }
    
    private func setupAfterAnalysis() {
        guard let result = viewModel.analysisResult else { return }
        
        // Identifier les doublons
        viewModel.identifyDuplicates(comparing: existingVouchers)
        
        // Initialiser les couleurs pour l'import multiple
        if viewModel.hasMultipleVouchers {
            detectedStoreConfidence = nil
            viewModel.initializeGlobalColors()
            viewModel.selectAll()
        } else if let singleVoucher = result.detectedVouchers.first {
            // Pré-remplir pour un seul bon
            populateFormWithSingleVoucher(singleVoucher, result: result)
        } else {
            // Utiliser les suggestions individuelles
            populateFormWithSuggestions(result)
        }
    }
    
    private func populateFormWithSingleVoucher(_ voucher: PDFAnalyzer.DetectedVoucher, result: PDFAnalyzer.AnalysisResult) {
        storeName = voucher.storeName ?? ""
        detectedStoreConfidence = voucher.storeNameConfidence > 0 ? voucher.storeNameConfidence : result.storeNameConfidence
        voucherNumber = voucher.voucherNumber
        pinCode = voucher.pinCode ?? ""
        codeType = voucher.codeType
        
        if let amount = voucher.amount {
            self.amount = String(format: "%.2f", amount)
        }
        
        if let expDate = voucher.expirationDate {
            expirationDate = expDate
            hasExpirationDate = true
        }
        
        // Appliquer les couleurs
        if let hexColor = voucher.storeColor {
            selectedColor = Color(hex: hexColor)
        } else {
            selectedColor = Color(hex: StorePreset.getColor(for: storeName))
        }
        
        // Suggérer la couleur de texte (avec exceptions par enseigne)
        let suggestedTextColor = StorePreset.getTextColor(for: storeName, backgroundHex: selectedColor.toHex())
        selectedTextColor = Color(hex: suggestedTextColor)
        
        print("✅ Bon pré-rempli: \(storeName) - Confiance: \(Int(voucher.storeNameConfidence * 100))%")
    }
    
    private func populateFormWithSuggestions(_ result: PDFAnalyzer.AnalysisResult) {
        if let detectedStore = result.detectedStoreName {
            storeName = detectedStore
            selectedColor = Color(hex: StorePreset.getColor(for: detectedStore))
        }
        detectedStoreConfidence = result.storeNameConfidence > 0 ? result.storeNameConfidence : nil
        
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
        
        // Suggérer la couleur de texte (avec exceptions par enseigne)
        let suggestedTextColor = StorePreset.getTextColor(for: storeName, backgroundHex: selectedColor.toHex())
        selectedTextColor = Color(hex: suggestedTextColor)
    }
    
    private func updateVoucher(_ updatedVoucher: PDFAnalyzer.DetectedVoucher) {
        if let index = viewModel.detectedVouchers.firstIndex(where: { $0.id == updatedVoucher.id }) {
            viewModel.detectedVouchers[index] = updatedVoucher
        }
    }
    
    private func importSelectedVouchers() {
        do {
            try viewModel.importSelectedVouchers(to: modelContext, pdfData: pdfData)
            dismiss()
        } catch {
            viewModel.errorMessage = "Erreur lors de l'import : \(error.localizedDescription)"
            viewModel.showingError = true
        }
    }
    
    private func saveVoucher() {
        // Vérifier les doublons
        if VoucherDuplicateDetector.isDuplicate(voucherNumber: voucherNumber, in: existingVouchers) {
            viewModel.errorMessage = "Le bon avec le numéro \(voucherNumber) existe déjà dans votre wallet."
            viewModel.showingError = true
            return
        }
        
        do {
            try viewModel.importSingleVoucher(
                storeName: storeName,
                amount: Double(amount),
                voucherNumber: voucherNumber,
                pinCode: pinCode.isEmpty ? nil : pinCode,
                codeType: codeType,
                expirationDate: hasExpirationDate ? expirationDate : nil,
                cardColor: selectedColor,
                textColor: selectedTextColor,
                pdfData: pdfData,
                to: modelContext
            )
            dismiss()
        } catch {
            viewModel.errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            viewModel.showingError = true
        }
    }
}
