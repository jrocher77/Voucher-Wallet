//
//  VoucherEditorView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI

/// Vue pour éditer un bon détecté avant l'import
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
            storeNameConfidence: voucher.storeNameConfidence,
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
    VoucherEditorView(
        voucher: PDFAnalyzer.DetectedVoucher(
            pageNumber: 1,
            voucherNumber: "1234567890",
            codeType: .barcode,
            storeName: "Carrefour",
            storeNameConfidence: 0.85,
            amount: 50.0,
            pinCode: "1234",
            expirationDate: Date().addingTimeInterval(86400 * 30),
            codeImageData: nil
        ),
        onSave: { _ in }
    )
}
