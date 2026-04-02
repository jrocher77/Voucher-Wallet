//
//  VoucherDetailView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

struct VoucherDetailView: View {
    let voucher: Voucher
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var brightness: Double = UIScreen.main.brightness
    @State private var showingDeleteAlert = false
    
    var isExpired: Bool {
        guard let expiration = voucher.expirationDate else { return false }
        return expiration < Date()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Carte miniature en haut
                VoucherCardView(voucher: voucher)
                    .frame(height: 180)
                    .padding(.horizontal)
                
                if isExpired {
                    expiredBanner
                }
                
                // Section code-barres/QR code
                codeSection
                
                // Informations détaillées
                detailsSection
                
                // Actions
                actionsSection
                
                Spacer(minLength: 40)
            }
            .padding(.vertical)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Supprimer ce bon ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                deleteVoucher()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
        .onAppear {
            // Augmenter la luminosité pour faciliter le scan
            brightness = UIScreen.main.brightness
            UIScreen.main.brightness = 1.0
        }
        .onDisappear {
            // Restaurer la luminosité d'origine
            UIScreen.main.brightness = brightness
        }
    }
    
    private var expiredBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Ce bon est expiré")
                .fontWeight(.semibold)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.red)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
    
    private var codeSection: some View {
        VStack(spacing: 16) {
            Text(voucher.codeType == .qrCode ? "QR Code" : "Code-barres")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            // Affichage du code
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.white)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                if let codeImage = generateCodeImage() {
                    if voucher.codeType == .qrCode {
                        // QR Code : carré centré
                        Image(uiImage: codeImage)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(40)
                    } else {
                        // Code-barres : étire horizontalement
                        Image(uiImage: codeImage)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 150)
                            .clipped()
                            .padding(.horizontal, 20)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("Code non disponible")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: voucher.codeType == .qrCode ? 350 : 220)
            .padding(.horizontal)
            
            // Numéro du bon en texte
            VStack(spacing: 8) {
                Text("Numéro du bon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(voucher.voucherNumber)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)
                    .textSelection(.enabled)
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Informations")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                DetailRow(
                    icon: "building.2",
                    title: "Enseigne",
                    value: voucher.storeName
                )
                
                if let amount = voucher.amount {
                    Divider()
                        .padding(.leading, 50)
                    DetailRow(
                        icon: "eurosign.circle",
                        title: "Montant",
                        value: amount.formatted(.currency(code: "EUR"))
                    )
                }
                
                if let pin = voucher.pinCode {
                    Divider()
                        .padding(.leading, 50)
                    DetailRow(
                        icon: "lock.shield",
                        title: "Code PIN",
                        value: pin,
                        isSecret: true
                    )
                }
                
                if let expiration = voucher.expirationDate {
                    Divider()
                        .padding(.leading, 50)
                    DetailRow(
                        icon: "calendar",
                        title: "Date d'expiration",
                        value: expiration.formatted(date: .long, time: .omitted)
                    )
                }
                
                Divider()
                    .padding(.leading, 50)
                DetailRow(
                    icon: "calendar.badge.plus",
                    title: "Ajouté le",
                    value: voucher.dateAdded.formatted(date: .long, time: .omitted)
                )
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            if voucher.pdfData != nil {
                Button {
                    // TODO: Ouvrir le PDF
                } label: {
                    Label("Voir le PDF original", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
            
            Button {
                shareVoucher()
            } label: {
                Label("Partager", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
    }
    
    private func generateCodeImage() -> UIImage? {
        // Si une image est déjà stockée, l'utiliser
        if let imageData = voucher.codeImageData,
           let image = BarcodeGenerator.dataToImage(imageData) {
            return image
        }
        
        // Sinon, générer l'image à la volée
        return BarcodeGenerator.generateCode(for: voucher)
    }
    
    private func shareVoucher() {
        // TODO: Implémenter le partage
    }
    
    private func deleteVoucher() {
        modelContext.delete(voucher)
        try? modelContext.save()
        dismiss()
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    var isSecret: Bool = false
    
    @State private var isRevealed = false
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if isSecret && !isRevealed {
                    HStack {
                        Text("••••")
                            .font(.body)
                            .fontWeight(.medium)
                        Button {
                            isRevealed = true
                        } label: {
                            Image(systemName: "eye")
                                .font(.caption)
                        }
                    }
                } else {
                    Text(value)
                        .font(.body)
                        .fontWeight(.medium)
                        .textSelection(.enabled)
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    NavigationStack {
        VoucherDetailView(voucher: Voucher(
            storeName: "Carrefour",
            amount: 50.0,
            voucherNumber: "1234567890123",
            pinCode: "5678",
            codeType: .barcode,
            expirationDate: Date().addingTimeInterval(86400 * 30),
            storeColor: "#0055A5"
        ))
    }
}
