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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // En-tête
                headerView
                
                // Liste des bons
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(detectedVouchers) { voucher in
                            VoucherSelectionRow(
                                voucher: voucher,
                                isSelected: selectedVouchers.contains(voucher.id),
                                isDuplicate: duplicateVoucherIds.contains(voucher.id)
                            ) {
                                toggleSelection(voucher.id)
                            }
                        }
                    }
                    .padding()
                }
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
            }
        }
    }
    
    private var headerView: some View {
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
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
                storeColor: StorePreset.getColor(for: detectedVoucher.storeName ?? "")
            )
            
            modelContext.insert(voucher)
            
            // 📚 Apprentissage : enregistrer chaque enseigne validée
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
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
