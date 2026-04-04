//
//  EditVoucherView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

struct EditVoucherView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let voucher: Voucher
    
    @State private var storeName: String
    @State private var amount: String
    @State private var voucherNumber: String
    @State private var pinCode: String
    @State private var codeType: CodeType
    @State private var expirationDate: Date?
    @State private var hasExpirationDate: Bool
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(voucher: Voucher) {
        self.voucher = voucher
        
        _storeName = State(initialValue: voucher.storeName)
        _amount = State(initialValue: voucher.amount != nil ? String(format: "%.2f", voucher.amount!) : "")
        _voucherNumber = State(initialValue: voucher.voucherNumber)
        _pinCode = State(initialValue: voucher.pinCode ?? "")
        _codeType = State(initialValue: voucher.codeType)
        _expirationDate = State(initialValue: voucher.expirationDate)
        _hasExpirationDate = State(initialValue: voucher.expirationDate != nil)
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
                    
                    if codeType != voucher.codeType || voucherNumber != voucher.voucherNumber {
                        Text("Le code sera régénéré lors de l'enregistrement")
                            .font(.caption)
                            .foregroundStyle(.orange)
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
                    }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Ajouté le")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(voucher.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
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
                    .disabled(!isFormValid)
                }
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isFormValid: Bool {
        !storeName.isEmpty && !voucherNumber.isEmpty
    }
    
    private func saveChanges() {
        // Mettre à jour les propriétés
        voucher.storeName = storeName
        voucher.amount = Double(amount)
        voucher.voucherNumber = voucherNumber
        voucher.pinCode = pinCode.isEmpty ? nil : pinCode
        voucher.codeType = codeType
        voucher.expirationDate = hasExpirationDate ? expirationDate : nil
        
        // Mettre à jour la couleur si l'enseigne a changé
        voucher.storeColor = StorePreset.getColor(for: storeName)
        
        // Régénérer le code si nécessaire
        if codeType != voucher.codeType || voucherNumber != voucher.voucherNumber {
            let codeImage: UIImage?
            if codeType == .qrCode {
                codeImage = BarcodeGenerator.generateQRCode(from: voucherNumber)
            } else {
                codeImage = BarcodeGenerator.generateBarcode(from: voucherNumber)
            }
            voucher.codeImageData = codeImage.flatMap { BarcodeGenerator.imageToData($0) }
        }
        
        // Sauvegarder
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    EditVoucherView(voucher: Voucher(
        storeName: "Carrefour",
        amount: 50.0,
        voucherNumber: "1234567890123",
        pinCode: "5678",
        codeType: .barcode,
        expirationDate: Date().addingTimeInterval(86400 * 30),
        storeColor: "#0055A5"
    ))
    .modelContainer(for: Voucher.self, inMemory: true)
}
