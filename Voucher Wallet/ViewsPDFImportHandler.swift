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
    
    let pdfData: Data
    
    @State private var isAnalyzing = true
    @State private var analysisResult: PDFAnalyzer.AnalysisResult?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Champs du formulaire
    @State private var storeName = ""
    @State private var amount = ""
    @State private var voucherNumber = ""
    @State private var pinCode = ""
    @State private var codeType: CodeType = .barcode
    @State private var expirationDate: Date?
    @State private var hasExpirationDate = false
    
    var body: some View {
        NavigationStack {
            Form {
                if isAnalyzing {
                    Section {
                        HStack {
                            ProgressView()
                            Text("Analyse du PDF en cours...")
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                    }
                } else {
                    if let result = analysisResult {
                        Section {
                            Label("PDF analysé avec succès", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Formulaire
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
                    Button("Enregistrer") {
                        saveVoucher()
                    }
                    .disabled(isAnalyzing || !isFormValid)
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
        }
    }
    
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
        }
    }
    
    private var isFormValid: Bool {
        !storeName.isEmpty && !voucherNumber.isEmpty
    }
    
    private func analyzePDF() async {
        do {
            let result = try await PDFAnalyzer.analyzePDF(data: pdfData)
            
            await MainActor.run {
                analysisResult = result
                
                // Pré-remplir le nom de l'enseigne si détecté
                if let detectedStore = result.detectedStoreName {
                    storeName = detectedStore
                }
                
                // Pré-remplir les champs
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
                
                isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Erreur lors de l'analyse : \(error.localizedDescription)"
                showingError = true
                isAnalyzing = false
            }
        }
    }
    
    private func saveVoucher() {
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
            pdfData: pdfData,
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
