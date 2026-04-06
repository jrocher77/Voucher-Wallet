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
    @Environment(\.scenePhase) private var scenePhase
    @State private var initialBrightness: Double = UIScreen.main.brightness
    @State private var isBrightnessMaximized = false
    @State private var showingDeleteAlert = false
    @State private var showingPDFViewer = false
    @State private var showingShareSheet = false
    @State private var showingEditView = false
    @State private var expenseToPresent: ExpensePresentation?
    @State private var isVoucherDeleted = false
    @State private var favoritesManager: FavoritesManager?
    @State private var showingFavoriteLimitAlert = false
    @State private var currentFavorites: [Voucher] = []
    
    enum ExpensePresentation: Identifiable {
        case new
        case edit(Expense)
        
        var id: String {
            switch self {
            case .new:
                return "new"
            case .edit(let expense):
                return expense.id.uuidString
            }
        }
    }
    
    var isExpired: Bool {
        guard let expiration = voucher.expirationDate else { return false }
        return expiration < Date()
    }
    
    var body: some View {
        if isVoucherDeleted {
            // Vue vide pendant la fermeture
            Color.clear
                .onAppear {
                    dismiss()
                }
        } else {
            contentView
        }
    }
    
    private var contentView: some View {
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
                
                // Bouton Ajouter une dépense (si montant existe)
                if voucher.amount != nil {
                    Button(action: {
                        expenseToPresent = .new
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Ajouter une dépense")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                
                // Section Solde et dépenses (si montant existe)
                if voucher.amount != nil {
                    balanceSection
                }
                
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
                    Button {
                        showingEditView = true
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    
                    Divider()
                    
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Supprimer", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            
            ToolbarItem(placement: .topBarLeading) {
                Button(action: toggleFavorite) {
                    Image(systemName: voucher.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(voucher.isFavorite ? .yellow : .primary)
                        .font(.title3)
                        .symbolEffect(.bounce, value: voucher.isFavorite)
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
        .alert("Limite atteinte", isPresented: $showingFavoriteLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Vous ne pouvez avoir que 4 cartes en favoris. Veuillez d'abord retirer une carte des favoris.")
        }
        .onAppear {
            // Enregistrer la luminosité initiale
            initialBrightness = UIScreen.main.brightness
            
            // Initialiser le manager des favoris
            if favoritesManager == nil {
                favoritesManager = FavoritesManager(modelContext: modelContext)
            }
        }
        .onDisappear {
            // Restaurer la luminosité d'origine
            restoreBrightness()
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Restaurer la luminosité quand l'app passe en arrière-plan
            if newPhase == .background || newPhase == .inactive {
                restoreBrightness()
            }
        }
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfData = voucher.pdfData {
                PDFViewerView(pdfData: pdfData)
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheetView(items: createShareItems())
        }
        .sheet(isPresented: $showingEditView) {
            EditVoucherView(voucher: voucher)
        }
        .sheet(item: $expenseToPresent) { presentation in
            switch presentation {
            case .new:
                AddExpenseView(voucher: voucher, onVoucherDeleted: {
                    isVoucherDeleted = true
                })
            case .edit(let expense):
                AddExpenseView(voucher: voucher, expense: expense, onVoucherDeleted: {
                    isVoucherDeleted = true
                })
            }
        }
    }
    
    private var expiredBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text("Ce bon est expiré")
                .fontWeight(.semibold)
        }
        .foregroundColor(.white)
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
            .onTapGesture {
                toggleBrightness()
            }
            
            // Numéro du bon en texte
            VStack(spacing: 8) {
                Text("Numéro du bon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(voucher.voucherNumber)
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
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
                        value: amount.formattedEuro
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
                        value: expiration.frenchLongFormat
                    )
                }
                
                Divider()
                    .padding(.leading, 50)
                DetailRow(
                    icon: "calendar.badge.plus",
                    title: "Ajouté le",
                    value: voucher.dateAdded.frenchLongFormat
                )
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
        }
    }
    
    private var actionsSection: some View {
        VStack(spacing: 12) {
            Button {
                showingEditView = true
            } label: {
                Label("Modifier le bon", systemImage: "pencil")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            
            if voucher.pdfData != nil {
                Button {
                    showingPDFViewer = true
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
                showingShareSheet = true
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
    
    // MARK: - Balance Section
    
    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Historique des dépenses
            if !voucher.expenses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Historique")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(voucher.expenses.sorted(by: { $0.date > $1.date })) { expense in
                        ExpenseRow(expense: expense, modelContext: modelContext) {
                            expenseToPresent = .edit(expense)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
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
        // Obsolète - remplacé par le ShareSheet
    }
    
    private func createShareItems() -> [Any] {
        var items: [Any] = []
        
        // Ajouter le texte avec les infos du bon
        var text = """
        Bon d'achat \(voucher.storeName)
        Numéro: \(voucher.voucherNumber)
        """
        
        if let amount = voucher.amount {
            text += "\nMontant: \(amount.formattedEuro)"
        }
        
        if let pin = voucher.pinCode {
            text += "\nCode PIN: \(pin)"
        }
        
        items.append(text)
        
        // Ajouter l'image du code-barres
        if let codeImageData = voucher.codeImageData,
           let codeImage = BarcodeGenerator.dataToImage(codeImageData) {
            items.append(codeImage)
        }
        
        // Ajouter le PDF si disponible
        if let pdfData = voucher.pdfData {
            items.append(pdfData)
        }
        
        return items
    }
    
    private func deleteVoucher() {
        modelContext.delete(voucher)
        try? modelContext.save()
        dismiss()
    }
    
    private func toggleFavorite() {
        guard let manager = favoritesManager else { return }
        
        let result = manager.toggleFavorite(voucher)
        
        switch result {
        case .added:
            // Feedback haptique pour confirmer l'ajout
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
        case .removed:
            // Feedback haptique léger pour le retrait
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            
        case .limitReached(let favorites):
            // Afficher l'alerte
            currentFavorites = favorites
            showingFavoriteLimitAlert = true
            
            // Feedback haptique d'erreur
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        }
    }
    
    private func restoreBrightness() {
        UIScreen.main.brightness = initialBrightness
        isBrightnessMaximized = false
    }
    
    private func toggleBrightness() {
        if isBrightnessMaximized {
            // Restaurer la luminosité initiale
            UIScreen.main.brightness = initialBrightness
            isBrightnessMaximized = false
        } else {
            // Passer au maximum
            UIScreen.main.brightness = 1.0
            isBrightnessMaximized = true
        }
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

// MARK: - Expense Row

struct ExpenseRow: View {
    let expense: Expense
    let modelContext: ModelContext
    let onEdit: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(expense.date.frenchLongFormat)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let note = expense.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("- \(expense.amount.formattedEuro)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            Menu {
                Button {
                    onEdit()
                } label: {
                    Label("Modifier", systemImage: "pencil")
                }
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .alert("Supprimer cette dépense ?", isPresented: $showingDeleteAlert) {
            Button("Annuler", role: .cancel) { }
            Button("Supprimer", role: .destructive) {
                deleteExpense()
            }
        } message: {
            Text("Cette action est irréversible.")
        }
    }
    
    private func deleteExpense() {
        modelContext.delete(expense)
        try? modelContext.save()
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // Pas de mise à jour nécessaire
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
