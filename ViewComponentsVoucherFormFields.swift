//
//  VoucherFormFields.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI
import SwiftData

/// Composant réutilisable pour les champs de formulaire d'un bon
struct VoucherFormFields: View {
    @Binding var storeName: String
    @Binding var amount: String
    @Binding var voucherNumber: String
    @Binding var pinCode: String
    @Binding var codeType: CodeType
    @Binding var expirationDate: Date?
    @Binding var hasExpirationDate: Bool
    
    let analysisResult: PDFAnalyzer.AnalysisResult?
    let existingVouchers: [Voucher]
    let detectedStoreConfidence: Double?
    
    var body: some View {
        Group {
            // Score de confiance si disponible
            if let confidence = confidenceToDisplay,
               confidence > 0,
               let detectedName = detectedStoreNameToDisplay {
                confidenceSection(confidence: confidence, detectedName: detectedName)
            }
            
            // Informations du bon
            voucherInfoSection
            
            // Type de code
            codeTypeSection
            
            // Date d'expiration
            expirationSection
        }
    }
    
    // MARK: - Sections
    
    private func confidenceSection(confidence: Double, detectedName: String) -> some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enseigne détectée")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 8) {
                        Text(detectedName)
                            .font(.headline)
                        
                        ConfidenceBadge(confidence: confidence)
                    }
                }
                
                Spacer()
                
                if confidence < 0.7 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
            
            if confidence < 0.7 {
                Text("La détection automatique n'est pas très sûre. Vérifiez le nom de l'enseigne.")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
        }
    }
    
    private var voucherInfoSection: some View {
        Section("Informations du bon") {
            TextField("Enseigne", text: $storeName)
            
            TextField("Montant (optionnel)", text: $amount)
                .keyboardType(.decimalPad)
            
            TextField("Numéro du bon", text: $voucherNumber)
                .textContentType(.none)
                .autocorrectionDisabled()
            
            // Avertissement si le numéro existe déjà
            if !voucherNumber.isEmpty && isDuplicate {
                Label {
                    Text("Ce numéro de bon existe déjà dans votre wallet")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            
            // Suggestions de numéros si disponibles
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
    }
    
    private var codeTypeSection: some View {
        Section("Type de code") {
            Picker("Type", selection: $codeType) {
                Label("Code-barres", systemImage: "barcode")
                    .tag(CodeType.barcode)
                Label("QR Code", systemImage: "qrcode")
                    .tag(CodeType.qrCode)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var expirationSection: some View {
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
                .tint(.blue)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isDuplicate: Bool {
        VoucherDuplicateDetector.isDuplicate(voucherNumber: voucherNumber, in: existingVouchers)
    }
    
    private var confidenceToDisplay: Double? {
        if let detectedStoreConfidence {
            return detectedStoreConfidence
        }
        return analysisResult?.storeNameConfidence
    }
    
    private var detectedStoreNameToDisplay: String? {
        if let detectedName = analysisResult?.detectedStoreName, !detectedName.isEmpty {
            return detectedName
        }
        return storeName.isEmpty ? nil : storeName
    }
}

#Preview {
    @Previewable @State var storeName = "Carrefour"
    @Previewable @State var amount = "50.00"
    @Previewable @State var voucherNumber = "123456789"
    @Previewable @State var pinCode = ""
    @Previewable @State var codeType: CodeType = .barcode
    @Previewable @State var expirationDate: Date? = nil
    @Previewable @State var hasExpirationDate = false
    
    NavigationStack {
        Form {
            VoucherFormFields(
                storeName: $storeName,
                amount: $amount,
                voucherNumber: $voucherNumber,
                pinCode: $pinCode,
                codeType: $codeType,
                expirationDate: $expirationDate,
                hasExpirationDate: $hasExpirationDate,
                analysisResult: nil,
                existingVouchers: [],
                detectedStoreConfidence: nil
            )
        }
    }
}
