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
    
    let detectedVouchers: [PDFAnalyzer.DetectedVoucher]
    let pdfData: Data
    
    @State private var selectedVouchers: Set<UUID> = []
    @State private var selectAll = true
    
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
                                isSelected: selectedVouchers.contains(voucher.id)
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
                // Sélectionner tous par défaut
                selectedVouchers = Set(detectedVouchers.map { $0.id })
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.badge.questionmark.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(detectedVouchers.count) bon(s) détecté(s)")
                        .font(.headline)
                    Text("Sélectionnez ceux à importer")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            // Bouton tout sélectionner/désélectionner
            Button {
                if selectAll {
                    selectedVouchers = Set(detectedVouchers.map { $0.id })
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
        if selectedVouchers.contains(id) {
            selectedVouchers.remove(id)
        } else {
            selectedVouchers.insert(id)
        }
    }
    
    private func importSelectedVouchers() {
        let vouchersToImport = detectedVouchers.filter { selectedVouchers.contains($0.id) }
        
        for detectedVoucher in vouchersToImport {
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
            print("✅ \(vouchersToImport.count) bon(s) importé(s) avec succès")
            dismiss()
        } catch {
            print("❌ Erreur lors de l'enregistrement: \(error)")
        }
    }
}

struct VoucherSelectionRow: View {
    let voucher: PDFAnalyzer.DetectedVoucher
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isSelected ? .blue : .gray)
                
                // Info du bon
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Text(voucher.storeName ?? "Bon d'achat")
                                .font(.headline)
                            
                            // Badge de confiance
                            if voucher.storeNameConfidence > 0 {
                                confidenceBadge(for: voucher.storeNameConfidence)
                            }
                        }
                        
                        Spacer()
                        
                        if let amount = voucher.amount {
                            Text(amount.formattedEuro)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    Text("Numéro: \(voucher.voucherNumber)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Label("Page \(voucher.pageNumber)", systemImage: "doc.text")
                            .font(.caption2)
                        
                        if voucher.codeType == .qrCode {
                            Label("QR", systemImage: "qrcode")
                                .font(.caption2)
                        } else {
                            Label("Code-barres", systemImage: "barcode")
                                .font(.caption2)
                        }
                        
                        if let expiration = voucher.expirationDate {
                            Label(expiration.frenchAbbreviatedFormat, 
                                  systemImage: "calendar")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
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
        .foregroundStyle(color)
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
