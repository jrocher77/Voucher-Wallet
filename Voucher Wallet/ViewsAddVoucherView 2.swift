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
    
    @State private var addMethod: AddMethod = .scan
    @State private var showingDocumentPicker = false
    @State private var isAnalyzing = false
    @State private var analysisResult: PDFAnalyzer.AnalysisResult?
    @State private var selectedPDFData: Data?
    @State private var showingError = false
    @State private var errorMessage = ""
    
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
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
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
                    isSelected: selectedVoucherIds.contains(voucher.id)
                ) {
                    toggleSelection(voucher.id)
                }
            }
        } header: {
            Text("Bons détectés")
        } footer: {
            Text("Sélectionnez les bons que vous souhaitez importer. Vous pourrez les modifier individuellement après l'import.")
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
            Section("Informations du bon") {
                TextField("Enseigne", text: $storeName)
                
                TextField("Montant (optionnel)", text: $amount)
                    .keyboardType(.decimalPad)
                
                TextField("Numéro du bon", text: $voucherNumber)
                    .textContentType(.none)
                    .autocorrectionDisabled()
                
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
                    
                    if let result = analysisResult, !result.possibleDates.isEmpty {
                        Menu("Dates suggérées") {
                            ForEach(result.possibleDates, id: \.self) { date in
                                Button(date.formatted(date: .long, time: .omitted)) {
                                    expirationDate = date
                                }
                            }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    // MARK: - Validation
    
    private var isFormValid: Bool {
        !storeName.isEmpty && !voucherNumber.isEmpty
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
                    
                    return
                }
                
                // Sinon, mode de détection global (ancien comportement)
                print("⚠️ Aucun bon complet détecté, utilisation des suggestions")
                
                // Pré-remplir le nom de l'enseigne si détecté
                if let detectedStore = result.detectedStoreName {
                    storeName = detectedStore
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
        
        for detectedVoucher in vouchersToImport {
            let voucher = Voucher(
                storeName: detectedVoucher.storeName ?? "Bon d'achat",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: detectedVoucher.codeImageData,
                expirationDate: detectedVoucher.expirationDate,
                pdfData: selectedPDFData,
                storeColor: StorePreset.getColor(for: detectedVoucher.storeName ?? "")
            )
            
            modelContext.insert(voucher)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
        }
    }
    
    private func saveVoucher() {
        // Générer l'image du code
        let codeImage: UIImage?
        if codeType == .qrCode {
            codeImage = BarcodeGenerator.generateQRCode(from: voucherNumber)
        } else {
            codeImage = BarcodeGenerator.generateBarcode(from: voucherNumber)
        }
        
        let voucher = Voucher(
            storeName: storeName,
            amount: Double(amount),
            voucherNumber: voucherNumber,
            pinCode: pinCode.isEmpty ? nil : pinCode,
            codeType: codeType,
            codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: hasExpirationDate ? expirationDate : nil,
            pdfData: selectedPDFData,
            storeColor: StorePreset.getColor(for: storeName)
        )
        
        modelContext.insert(voucher)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Voucher Selection Row Compact

struct VoucherSelectionRowCompact: View {
    let voucher: PDFAnalyzer.DetectedVoucher
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? .blue : .gray)
                
                // Info du bon
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(voucher.storeName ?? "Bon d'achat")
                            .font(.body)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if let amount = voucher.amount {
                            Text(amount, format: .currency(code: "EUR"))
                                .font(.subheadline)
                                .foregroundStyle(.blue)
                        }
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
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddVoucherView()
        .modelContainer(for: Voucher.self, inMemory: true)
}
