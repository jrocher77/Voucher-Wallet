//
//  AddVoucherView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//  Refactored on 09/04/2026
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
    
    // ViewModel centralisé pour la gestion de l'import
    @State private var viewModel = VoucherImportViewModel()
    
    // États de la vue
    @State private var addMethod: AddMethod = .scan
    @State private var showingDocumentPicker = false
    @State private var selectedPDFData: Data?
    @State private var editingVoucher: PDFAnalyzer.DetectedVoucher?
    @State private var showingVoucherEditor = false
    
    // Champs du formulaire (pour un seul bon ou saisie manuelle)
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
    
    var body: some View {
        NavigationStack {
            Form {
                // Choix de la méthode
                methodPicker
                
                if addMethod == .scan {
                    scanSection
                    
                    // Afficher la liste des bons si plusieurs détectés
                    if viewModel.hasMultipleVouchers {
                        multipleVouchersSection
                    } else if viewModel.analysisResult != nil {
                        // Sinon, afficher le formulaire avec les données détectées
                        formSection
                    }
                } else {
                    // Saisie manuelle
                    formSection
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
            .alert("Erreur", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage)
            }
        }
    }
    
    // MARK: - Sections
    
    private var methodPicker: some View {
        Section {
            Picker("Méthode d'ajout", selection: $addMethod) {
                Label("Scanner un PDF", systemImage: "doc.text.viewfinder")
                    .tag(AddMethod.scan)
                Label("Saisie manuelle", systemImage: "keyboard")
                    .tag(AddMethod.manual)
            }
            .pickerStyle(.segmented)
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
            .disabled(!isFormValid)
        }
    }
    
    private var scanSection: some View {
        Section {
            if viewModel.isAnalyzing {
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
            } else if viewModel.analysisResult != nil {
                VStack(alignment: .leading, spacing: 12) {
                    Label("PDF analysé avec succès", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .fontWeight(.semibold)
                    
                    if viewModel.hasMultipleVouchers {
                        Text("• \(viewModel.detectedVouchers.count) bon(s) détecté(s)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if let result = viewModel.analysisResult {
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
        }
    }
    
    private var formSection: some View {
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
                existingVouchers: existingVouchers
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
    
    private func resetAndShowPicker() {
        viewModel = VoucherImportViewModel()
        selectedPDFData = nil
        storeName = ""
        amount = ""
        voucherNumber = ""
        pinCode = ""
        showingDocumentPicker = true
    }
    
    private func updateVoucher(_ updatedVoucher: PDFAnalyzer.DetectedVoucher) {
        if let index = viewModel.detectedVouchers.firstIndex(where: { $0.id == updatedVoucher.id }) {
            viewModel.detectedVouchers[index] = updatedVoucher
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
            
            // Analyser le PDF via le ViewModel
            Task {
                await viewModel.analyzePDF(data: data)
                setupAfterAnalysis()
            }
        } catch {
            viewModel.errorMessage = error.localizedDescription
            viewModel.showingError = true
        }
    }
    
    private func setupAfterAnalysis() {
        guard let result = viewModel.analysisResult else { return }
        
        // Identifier les doublons
        viewModel.identifyDuplicates(comparing: existingVouchers)
        
        // Initialiser les couleurs pour l'import multiple
        if viewModel.hasMultipleVouchers {
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
        
        // Suggérer la couleur de texte
        let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: selectedColor.toHex())
        selectedTextColor = Color(hex: suggestedTextColor)
        
        print("✅ Bon pré-rempli: \(storeName) - Confiance: \(Int(voucher.storeNameConfidence * 100))%")
    }
    
    private func populateFormWithSuggestions(_ result: PDFAnalyzer.AnalysisResult) {
        if let detectedStore = result.detectedStoreName {
            storeName = detectedStore
            selectedColor = Color(hex: StorePreset.getColor(for: detectedStore))
        }
        
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
        
        // Suggérer la couleur de texte
        let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: selectedColor.toHex())
        selectedTextColor = Color(hex: suggestedTextColor)
    }
    
    private func importSelectedVouchers() {
        guard let pdfData = selectedPDFData else {
            viewModel.errorMessage = "Données PDF manquantes"
            viewModel.showingError = true
            return
        }
        
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
                pdfData: selectedPDFData ?? Data(),
                to: modelContext
            )
            dismiss()
        } catch {
            viewModel.errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            viewModel.showingError = true
        }
    }
}

#Preview {
    AddVoucherView()
        .modelContainer(for: Voucher.self, inMemory: true)
}
