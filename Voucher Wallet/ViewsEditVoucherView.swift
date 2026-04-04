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
    @State private var selectedColor: Color
    @State private var selectedTextColor: Color
    
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
        _selectedColor = State(initialValue: Color(hex: voucher.storeColor))
        _selectedTextColor = State(initialValue: Color(hex: voucher.textColor))
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
                        .environment(\.locale, Locale(identifier: "fr_FR"))
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
                                                    if preset.hex == selectedColor.toHex() {
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
                                                if preset.1 == selectedTextColor.toHex() {
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
                
                Section {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundStyle(.secondary)
                        Text("Ajouté le")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(voucher.dateAdded.frenchAbbreviatedFormat)
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
        // Vérifier que les champs essentiels sont remplis
        guard !storeName.isEmpty && !voucherNumber.isEmpty else {
            return false
        }
        
        // 🎨 INTERDICTION : empêcher l'enregistrement si les couleurs sont trop similaires
        guard !areColorsTooSimilar(selectedColor, selectedTextColor) else {
            return false
        }
        
        return true
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
    
    private func saveChanges() {
        // Mettre à jour les propriétés
        voucher.storeName = storeName
        voucher.amount = Double(amount)
        voucher.voucherNumber = voucherNumber
        voucher.pinCode = pinCode.isEmpty ? nil : pinCode
        voucher.codeType = codeType
        voucher.expirationDate = hasExpirationDate ? expirationDate : nil
        
        // Mettre à jour les couleurs
        let newColorHex = selectedColor.toHex()
        let newTextColorHex = selectedTextColor.toHex()
        voucher.storeColor = newColorHex
        voucher.textColor = newTextColorHex
        
        // 🎨 Apprentissage : enregistrer les préférences de couleur
        StoreNameLearning.shared.learnStoreColor(newColorHex, for: storeName)
        StoreNameLearning.shared.learnTextColor(newTextColorHex, for: storeName)
        
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
        storeColor: "#0055A5",
        textColor: "#FFFFFF"
    ))
    .modelContainer(for: Voucher.self, inMemory: true)
}
