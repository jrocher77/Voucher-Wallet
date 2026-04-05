//
//  MultiVoucherSelectionView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

struct MultiVoucherSelectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // Requête pour récupérer tous les bons existants
    @Query private var existingVouchers: [Voucher]
    
    let detectedVouchers: [PDFAnalyzer.DetectedVoucher]
    let pdfData: Data
    
    @State private var selectedVouchers: Set<UUID> = []
    @State private var selectAll = true
    @State private var duplicateVoucherIds: Set<UUID> = [] // IDs des bons déjà présents
    
    // Couleurs globales pour l'import multi-bons
    @State private var globalCardColor = Color(hex: "#007AFF")
    @State private var globalTextColor = Color(hex: "#FFFFFF")
    
    var body: some View {
        NavigationStack {
            Form {
                // En-tête
                headerSection
                
                // Liste des bons
                vouchersListSection
                
                // Section de personnalisation globale des couleurs (EN BAS)
                globalColorCustomizationSection
            }
            .navigationTitle("Bons détectés")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Importer (\(selectedVouchers.count))") {
                        importSelectedVouchers()
                    }
                    .disabled(selectedVouchers.isEmpty)
                }
            }
            .onAppear {
                // Identifier les doublons
                identifyDuplicates()
                
                // Sélectionner tous les bons non-dupliqués par défaut
                selectedVouchers = Set(
                    detectedVouchers
                        .filter { !duplicateVoucherIds.contains($0.id) }
                        .map { $0.id }
                )
                
                // 🎨 Initialiser les couleurs globales avec la couleur de la première enseigne détectée
                if let firstVoucher = detectedVouchers.first {
                    if let hexColor = firstVoucher.storeColor {
                        globalCardColor = Color(hex: hexColor)
                    } else if let storeName = firstVoucher.storeName {
                        globalCardColor = Color(hex: StorePreset.getColor(for: storeName))
                    }
                    
                    // Suggérer automatiquement la couleur de texte
                    let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: globalCardColor.toHex())
                    globalTextColor = Color(hex: suggestedTextColor)
                    
                    print("🎨 Couleurs globales initialisées : fond=\(globalCardColor.toHex()), texte=\(globalTextColor.toHex())")
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private var globalColorCustomizationSection: some View {
        Section {
            ColorPicker("Couleur de fond", selection: $globalCardColor, supportsOpacity: false)
                .onChange(of: globalCardColor) { oldValue, newValue in
                    if areColorsTooSimilar(newValue, globalTextColor) {
                        let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: newValue.toHex())
                        globalTextColor = Color(hex: suggestedTextColor)
                    }
                }
            
            ColorPicker("Couleur du texte", selection: $globalTextColor, supportsOpacity: false)
            
            if areColorsTooSimilar(globalCardColor, globalTextColor) {
                Label {
                    Text("⚠️ Les couleurs sont identiques ou trop similaires.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            
            if !areColorsTooSimilar(globalCardColor, globalTextColor) {
                Label {
                    Text("Bon contraste pour la lisibilité")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.caption)
                .foregroundStyle(.green)
            }
            
            // Prévisualisation
            VStack(alignment: .leading, spacing: 8) {
                Text("Aperçu")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enseigne exemple")
                            .font(.headline)
                            .foregroundStyle(globalTextColor)
                        
                        Text("1234567890")
                            .font(.caption)
                            .foregroundStyle(globalTextColor.opacity(0.8))
                    }
                    Spacer()
                    Text("50,00 €")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(globalTextColor)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(globalCardColor)
                )
            }
            
            // Préréglages
            VStack(alignment: .leading, spacing: 8) {
                Text("Couleurs populaires")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ColorPresets.allPresets, id: \.hex) { preset in
                            Button {
                                globalCardColor = Color(hex: preset.hex)
                                let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: preset.hex)
                                globalTextColor = Color(hex: suggestedTextColor)
                            } label: {
                                VStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: preset.hex))
                                        .frame(width: 44, height: 44)
                                        .overlay {
                                            if globalCardColor.isSimilar(to: Color(hex: preset.hex)) {
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
        } header: {
            Text("Personnalisation des couleurs (tous les bons)")
        } footer: {
            Text("Ces couleurs seront appliquées à tous les bons sélectionnés.")
        }
    }
    
    private var headerSection: some View {
        Section {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "checkmark.circle.badge.questionmark.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(detectedVouchers.count) bon(s) détecté(s)")
                            .font(.headline)
                        Text("Sélectionnez ceux à importer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Afficher un message si des doublons sont détectés
                if !duplicateVoucherIds.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(duplicateVoucherIds.count) bon(s) déjà présent(s)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Ces bons ne peuvent pas être importés à nouveau")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                
                // Bouton tout sélectionner/désélectionner
                Button {
                    if selectAll {
                        // Sélectionner tous les bons NON dupliqués
                        selectedVouchers = Set(
                            detectedVouchers
                                .filter { !duplicateVoucherIds.contains($0.id) }
                                .map { $0.id }
                        )
                    } else {
                        selectedVouchers.removeAll()
                    }
                    selectAll.toggle()
                } label: {
                    Label(selectAll ? "Tout sélectionner" : "Tout désélectionner", 
                          systemImage: selectAll ? "checkmark.square" : "square")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var vouchersListSection: some View {
        Section {
            ForEach(detectedVouchers) { voucher in
                VoucherSelectionRow(
                    voucher: voucher,
                    isSelected: selectedVouchers.contains(voucher.id),
                    isDuplicate: duplicateVoucherIds.contains(voucher.id)
                ) {
                    toggleSelection(voucher.id)
                }
            }
        } header: {
            Text("Bons détectés")
        }
    }
    
    private func toggleSelection(_ id: UUID) {
        // Ne pas permettre la sélection des doublons
        if duplicateVoucherIds.contains(id) {
            return
        }
        
        if selectedVouchers.contains(id) {
            selectedVouchers.remove(id)
        } else {
            selectedVouchers.insert(id)
        }
    }
    
    /// Identifie les bons qui sont déjà présents dans le wallet
    private func identifyDuplicates() {
        var duplicateIds: Set<UUID> = []
        
        for voucher in detectedVouchers {
            if isVoucherNumberDuplicate(voucher.voucherNumber) {
                duplicateIds.insert(voucher.id)
            }
        }
        
        duplicateVoucherIds = duplicateIds
        
        // Afficher un message informatif si des doublons sont détectés
        if !duplicateIds.isEmpty {
            print("⚠️ \(duplicateIds.count) bon(s) déjà présent(s) dans le wallet")
        }
    }
    
    /// Vérifie si un numéro de bon existe déjà dans le wallet
    private func isVoucherNumberDuplicate(_ number: String) -> Bool {
        existingVouchers.contains { $0.voucherNumber == number }
    }
    
    private func importSelectedVouchers() {
        let vouchersToImport = detectedVouchers.filter { selectedVouchers.contains($0.id) }
        
        // ⚠️ Normalement, tous les doublons sont déjà filtrés, mais vérification supplémentaire
        var validVouchers: [PDFAnalyzer.DetectedVoucher] = []
        
        for voucher in vouchersToImport {
            if !isVoucherNumberDuplicate(voucher.voucherNumber) {
                validVouchers.append(voucher)
            }
        }
        
        // Utiliser les couleurs globales pour tous les bons
        let colorHex = globalCardColor.toHex()
        let textColorHex = globalTextColor.toHex()
        
        // Importer les bons valides
        for detectedVoucher in validVouchers {
            let voucher = Voucher(
                storeName: detectedVoucher.storeName ?? "Bon d'achat",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: detectedVoucher.codeImageData,
                expirationDate: detectedVoucher.expirationDate,
                pdfData: pdfData,
                storeColor: colorHex,
                textColor: textColorHex
            )
            
            modelContext.insert(voucher)
            
            // 📚 Apprentissage : enregistrer chaque enseigne validée
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
                StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
                StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
            }
        }
        
        do {
            try modelContext.save()
            print("✅ \(validVouchers.count) bon(s) importé(s) avec succès")
            dismiss()
        } catch {
            print("❌ Erreur lors de l'enregistrement: \(error)")
        }
    }
    
    /// Vérifie si deux couleurs sont trop similaires pour une bonne lisibilité
    private func areColorsTooSimilar(_ color1: Color, _ color2: Color) -> Bool {
        let hex1 = color1.toHex()
        let hex2 = color2.toHex()
        
        if hex1 == hex2 { return true }
        
        let luminance1 = calculateLuminance(hex: hex1)
        let luminance2 = calculateLuminance(hex: hex2)
        let contrastRatio = max(luminance1, luminance2) / min(luminance1, luminance2)
        
        return contrastRatio < 3.0
    }
    
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
    
    private func hexToRGB(_ hex: String) -> (r: Double, g: Double, b: Double) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF)
        let g = Double((int >> 8) & 0xFF)
        let b = Double(int & 0xFF)
        return (r, g, b)
    }
}

struct VoucherSelectionRow: View {
    let voucher: PDFAnalyzer.DetectedVoucher
    let isSelected: Bool
    let isDuplicate: Bool
    let onTap: () -> Void
    
    // Computed properties pour simplifier le type-checking
    private var checkboxIcon: String {
        isDuplicate ? "xmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle")
    }
    
    private var checkboxColor: Color {
        isDuplicate ? .red : (isSelected ? .blue : .gray)
    }
    
    private var backgroundColor: Color {
        isDuplicate ? Color(.systemGray5) : (isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
    }
    
    private var borderColor: Color {
        isDuplicate ? Color.red.opacity(0.3) : (isSelected ? Color.blue : Color.clear)
    }
    
    var body: some View {
        Button(action: onTap) {
            rowContent
        }
        .buttonStyle(.plain)
        .disabled(isDuplicate)
    }
    
    private var rowContent: some View {
        HStack(spacing: 16) {
            checkboxView
            voucherInfoView
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: 2)
        )
        .opacity(isDuplicate ? 0.6 : 1.0)
    }
    
    private var checkboxView: some View {
        Image(systemName: checkboxIcon)
            .font(.title2)
            .foregroundColor(checkboxColor)
    }
    
    private var voucherInfoView: some View {
        VStack(alignment: .leading, spacing: 6) {
            topRow
            voucherNumberView
            metadataRow
        }
    }
    
    private var topRow: some View {
        HStack {
            badgesRow
            Spacer()
            amountView
        }
    }
    
    private var badgesRow: some View {
        HStack(spacing: 6) {
            Text(voucher.storeName ?? "Bon d'achat")
                .font(.headline)
                .foregroundColor(isDuplicate ? .secondary : .primary)
            
            if isDuplicate {
                duplicateBadge
            } else if voucher.storeNameConfidence > 0 {
                confidenceBadge(for: voucher.storeNameConfidence)
            }
        }
    }
    
    private var duplicateBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10))
            Text("Déjà importé")
                .font(.system(size: 11, weight: .medium))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Color.red.opacity(0.15))
        .foregroundColor(.red)
        .clipShape(Capsule())
    }
    
    @ViewBuilder
    private var amountView: some View {
        if let amount = voucher.amount {
            Text(amount.formattedEuro)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(isDuplicate ? .secondary : .blue)
        }
    }
    
    private var voucherNumberView: some View {
        Text("Numéro: \(voucher.voucherNumber)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
    
    private var metadataRow: some View {
        HStack {
            Label("Page \(voucher.pageNumber)", systemImage: "doc.text")
                .font(.caption2)
            
            codeTypeLabel
            
            if let expiration = voucher.expirationDate {
                Label(expiration.frenchAbbreviatedFormat, systemImage: "calendar")
                    .font(.caption2)
            }
        }
        .foregroundColor(.secondary)
    }
    
    private var codeTypeLabel: some View {
        Group {
            if voucher.codeType == .qrCode {
                Label("QR", systemImage: "qrcode")
                    .font(.caption2)
            } else {
                Label("Code-barres", systemImage: "barcode")
                    .font(.caption2)
            }
        }
    }
    
    /// Badge de confiance pour la détection de l'enseigne
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
        .foregroundColor(color)
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

#Preview {
    MultiVoucherSelectionView(
        detectedVouchers: [
            PDFAnalyzer.DetectedVoucher(
                pageNumber: 1,
                voucherNumber: "1234567890123",
                codeType: .barcode,
                storeName: "Carrefour",
                amount: 50.0,
                pinCode: "5678",
                expirationDate: Date().addingTimeInterval(86400 * 30),
                codeImageData: nil
            ),
            PDFAnalyzer.DetectedVoucher(
                pageNumber: 2,
                voucherNumber: "9876543210987",
                codeType: .qrCode,
                storeName: "Fnac",
                amount: 25.0,
                pinCode: nil,
                expirationDate: Date().addingTimeInterval(86400 * 60),
                codeImageData: nil
            )
        ],
        pdfData: Data()
    )
    .modelContainer(for: Voucher.self, inMemory: true)
}
