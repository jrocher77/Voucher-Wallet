//
//  MultiVoucherList.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI

/// Liste de sélection multiple pour l'import de plusieurs bons
struct MultiVoucherList: View {
    let vouchers: [PDFAnalyzer.DetectedVoucher]
    let selectedIds: Set<UUID>
    let duplicateIds: Set<UUID>
    let onToggle: (UUID) -> Void
    let onEdit: ((PDFAnalyzer.DetectedVoucher) -> Void)?
    
    init(
        vouchers: [PDFAnalyzer.DetectedVoucher],
        selectedIds: Set<UUID>,
        duplicateIds: Set<UUID>,
        onToggle: @escaping (UUID) -> Void,
        onEdit: ((PDFAnalyzer.DetectedVoucher) -> Void)? = nil
    ) {
        self.vouchers = vouchers
        self.selectedIds = selectedIds
        self.duplicateIds = duplicateIds
        self.onToggle = onToggle
        self.onEdit = onEdit
    }
    
    var body: some View {
        Section {
            // Message d'information sur les doublons
            if !duplicateIds.isEmpty {
                duplicateWarning
            }
            
            // Liste des bons
            ForEach(vouchers) { voucher in
                VoucherRow(
                    voucher: voucher,
                    isSelected: selectedIds.contains(voucher.id),
                    isDuplicate: duplicateIds.contains(voucher.id),
                    onToggle: { onToggle(voucher.id) },
                    onEdit: onEdit != nil ? { onEdit?(voucher) } : nil
                )
            }
            
            // Bouton tout sélectionner/désélectionner
            selectAllButton
        } header: {
            Text("Sélectionnez les bons à importer")
        }
    }
    
    // MARK: - Sous-vues
    
    private var duplicateWarning: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(duplicateIds.count) bon(s) déjà présent(s)")
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
    
    private var selectAllButton: some View {
        Button {
            toggleSelectAll()
        } label: {
            HStack {
                let nonDuplicateCount = vouchers.filter { !duplicateIds.contains($0.id) }.count
                let allNonDuplicatesSelected = selectedIds.count == nonDuplicateCount
                
                Image(systemName: allNonDuplicatesSelected ? "checkmark.circle.fill" : "circle")
                Text(allNonDuplicatesSelected ? "Tout désélectionner" : "Tout sélectionner")
            }
        }
    }
    
    // MARK: - Actions
    
    private func toggleSelectAll() {
        let nonDuplicateIds = Set(vouchers.filter { !duplicateIds.contains($0.id) }.map { $0.id })
        
        if selectedIds.count == nonDuplicateIds.count {
            // Tout désélectionner
            nonDuplicateIds.forEach { onToggle($0) }
        } else {
            // Tout sélectionner (seulement les non-dupliqués)
            nonDuplicateIds.subtracting(selectedIds).forEach { onToggle($0) }
        }
    }
}

// MARK: - VoucherRow

/// Ligne individuelle pour un bon dans la liste de sélection
struct VoucherRow: View {
    let voucher: PDFAnalyzer.DetectedVoucher
    let isSelected: Bool
    let isDuplicate: Bool
    let onToggle: () -> Void
    let onEdit: (() -> Void)?
    
    var body: some View {
        HStack {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: checkboxIcon)
                    .foregroundColor(checkboxColor)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .disabled(isDuplicate)
            
            // Informations du bon
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(voucher.storeName ?? "Enseigne inconnue")
                        .font(.headline)
                        .foregroundColor(isDuplicate ? .secondary : .primary)
                    
                    // Badge de statut
                    if isDuplicate {
                        duplicateBadge
                    } else if voucher.storeNameConfidence > 0 {
                        ConfidenceBadge(confidence: voucher.storeNameConfidence)
                    }
                }
                
                Text(voucher.voucherNumber)
                    .font(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .foregroundColor(.secondary)
                
                if let amount = voucher.amount {
                    Text(amount.formattedEuro)
                        .font(.subheadline)
                        .foregroundColor(isDuplicate ? .secondary : .blue)
                }
            }
            
            Spacer()
            
            // Bouton modifier
            if let onEdit = onEdit, !isDuplicate {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !isDuplicate {
                onToggle()
            }
        }
        .opacity(isDuplicate ? 0.6 : 1.0)
    }
    
    // MARK: - Computed Properties
    
    private var checkboxIcon: String {
        isDuplicate ? "xmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle")
    }
    
    private var checkboxColor: Color {
        isDuplicate ? .red : (isSelected ? .blue : .gray)
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
}

#Preview("Multiple Vouchers") {
    @Previewable @State var selectedIds: Set<UUID> = []
    
    let vouchers = [
        PDFAnalyzer.DetectedVoucher(
            pageNumber: 1,
            voucherNumber: "1234567890123",
            codeType: .barcode,
            storeName: "Carrefour",
            storeNameConfidence: 0.95,
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
            storeNameConfidence: 0.65,
            amount: 25.0,
            pinCode: nil,
            expirationDate: Date().addingTimeInterval(86400 * 60),
            codeImageData: nil
        )
    ]
    
    Form {
        MultiVoucherList(
            vouchers: vouchers,
            selectedIds: selectedIds,
            duplicateIds: [],
            onToggle: { id in
                if selectedIds.contains(id) {
                    selectedIds.remove(id)
                } else {
                    selectedIds.insert(id)
                }
            }
        )
    }
}
