//
//  VoucherDetailView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import CoreData
import Combine

struct VoucherDetailView: View {
    let voucher: Voucher
    @Environment(\.dismiss) private var dismiss
    @Environment(VoucherSharingManager.self) private var sharingManager
    @Environment(\.managedObjectContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var initialBrightness: Double = 0.5
    @State private var isBrightnessMaximized = false
    @State private var showingDeleteAlert = false
    @State private var showingPDFViewer = false
    @State private var showingSharingDisclaimer = false
    @State private var showingCloudSharing = false
    @State private var isPreparingCloudSharing = false
    @State private var showingEditView = false
    @State private var expenseToPresent: ExpensePresentation?
    @State private var isVoucherDeleted = false
    @State private var favoritesManager: FavoritesManager?
    @State private var showingFavoriteLimitAlert = false
    @State private var currentFavorites: [Voucher] = []
    @State private var isScreenCaptured = false
    @State private var favoriteRevision = 0
    @State private var expenseRevision = 0
    @State private var voucherRevision = 0
    
    enum ExpensePresentation: Identifiable {
        case new
        case edit(Expense)
        
        var id: String {
            switch self {
            case .new:
                return "new"
            case .edit(let expense):
                return expense.safeID?.uuidString ?? expense.objectID.uriRepresentation().absoluteString
            }
        }
    }

    var isExpired: Bool {
        guard let expiration = voucher.expirationDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDay = calendar.startOfDay(for: expiration)
        return expirationDay < today
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
                .overlay {
                    if isScreenCaptured && voucher.isInActiveShare {
                        ContentUnavailableView(
                            "Contenu masqué",
                            systemImage: "eye.slash.fill",
                            description: Text("Le bon est masqué pendant la recopie ou l'enregistrement de l'écran.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                    }
                }
        }
    }
    
    private var contentView: some View {
        VStack(spacing: 0) {
            headerCardSection
            
            ScrollView {
                VStack(spacing: 24) {
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
                    .id(voucherRevision)
                
                // Actions
                actionsSection
                
                Spacer(minLength: 40)
            }
            .padding(.bottom)
            }
            .refreshable {
                await refreshSharedVoucherFromPull()
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: toggleFavorite) {
                        Label(isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                              systemImage: isFavorite ? "star.fill" : "star")
                    }

                    if !voucher.isReceivedShare {
                        Button(action: { showingEditView = true }) {
                            Label("Modifier", systemImage: "pencil")
                        }
                    }
                    
                    Divider()
                    
                    if voucher.isReceivedShare {
                        Button(role: .destructive, action: {
                            isVoucherDeleted = true
                            dismiss()
                            sharingManager.removeReceivedVoucher(voucher, after: 0.35)
                        }) {
                            Label("Quitter le partage", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } else {
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Supprimer", systemImage: "trash")
                        }
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
        .alert("Limite atteinte", isPresented: $showingFavoriteLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Vous ne pouvez avoir que 4 cartes en favoris. Veuillez d'abord retirer une carte des favoris.")
        }
        .alert("Partage iCloud", isPresented: Binding(
            get: { sharingManager.lastErrorMessage != nil },
            set: { if !$0 { sharingManager.lastErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                sharingManager.lastErrorMessage = nil
            }
        } message: {
            Text(sharingManager.lastErrorMessage ?? "")
        }
        .onAppear {
            // Enregistrer la luminosité initiale de manière asynchrone
            Task { @MainActor in
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                    let screen = windowScene.screen
                    initialBrightness = screen.brightness
                }
                
                // Initialiser le manager des favoris
                if favoritesManager == nil {
                    favoritesManager = FavoritesManager(modelContext: modelContext)
                }
                refreshSharedExpenseMirrorsInBackground(reason: "detail-appear")
                isScreenCaptured = UIScreen.main.isCaptured
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
                } else if newPhase == .active && voucher.isInActiveShare {
                    sharingManager.persistence.scheduleCloudRefreshes(delays: [0.0, 1.0, 3.0])
                    refreshSharedExpenseMirrorsInBackground(reason: "detail-scene-active")
                }
            }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
            isScreenCaptured = UIScreen.main.isCaptured
        }
        .modifier(VoucherDetailRefreshEvents(
            voucher: voucher,
            sharingManager: sharingManager,
            modelContext: modelContext,
            favoriteRevision: $favoriteRevision,
            expenseRevision: $expenseRevision,
            voucherRevision: $voucherRevision,
            isVoucherDeleted: $isVoucherDeleted
        ))
        .sheet(isPresented: $showingPDFViewer) {
            if let pdfData = voucher.pdfData {
                PDFViewerView(
                    pdfData: pdfData,
                    allowsSharing: !voucher.isReceivedShare,
                    masksWhenCaptured: voucher.isInActiveShare
                )
            }
        }
        .background {
            CloudVoucherSharingPresenter(
                isPresented: $showingCloudSharing,
                isPreparing: $isPreparingCloudSharing,
                voucher: voucher,
                manager: sharingManager
            )
            .frame(width: 0, height: 0)
        }
        .sheet(isPresented: $showingEditView) {
            EditVoucherView(voucher: voucher)
        }
        .sheet(item: $expenseToPresent) { presentation in
            switch presentation {
            case .new:
                AddExpenseView(voucher: voucher, onVoucherDeleted: {
                    isVoucherDeleted = true
                }, onExpenseSaved: {
                    modelContext.refresh(voucher, mergeChanges: true)
                    expenseRevision += 1
                })
            case .edit(let expense):
                AddExpenseView(voucher: voucher, expense: expense, onVoucherDeleted: {
                    isVoucherDeleted = true
                }, onExpenseSaved: {
                    modelContext.refresh(voucher, mergeChanges: true)
                    expenseRevision += 1
                })
            }
        }
        .alert("Partager ce bon ?", isPresented: $showingSharingDisclaimer) {
            Button("Annuler", role: .cancel) {
                sharingManager.sharingStatusMessage = nil
                sharingManager.markSharingOperationEnded()
            }
            Button("Continuer le partage") {
                sharingManager.beginSharingInitialization()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    showingCloudSharing = true
                }
            }
        } message: {
            Text("Ce bon peut être utilisé comme moyen de paiement. Les personnes invitées pourront consulter et utiliser son numéro, son code, son QR Code ou code-barres ainsi que son PDF éventuel.\n\nDans la fenêtre suivante, conservez le mode Collaborer. Pour une meilleure expérience, privilégiez l'envoi de l'invitation via Messages ou Mail.")
        }
    }
    
    private var headerCardSection: some View {
        ZStack(alignment: .topLeading) {
            VoucherCardView(voucher: voucher, showsFavoriteIcon: false)
                .id("\(expenseRevision)-\(favoriteRevision)-\(voucherRevision)")
                .frame(height: 200)
            
            Button(action: toggleFavorite) {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: isFavorite ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(isFavorite ? .yellow : Color(hex: voucher.textColor).opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .symbolEffect(.bounce, value: voucher.isFavorite)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 12)
            .zIndex(1)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, 16)
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
                        Button(action: {
                            toggleBrightness()
                        }) {
                            VStack {
                                Spacer(minLength: 0)
                                Image(uiImage: codeImage)
                                    .resizable()
                                    .interpolation(.none)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 180, height: 180)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    } else {
                        // Code-barres : même zone d'affichage que le QR pour garder un layout identique
                        Button(action: {
                            toggleBrightness()
                        }) {
                            Image(uiImage: codeImage)
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 150)
                                .clipped()
                                .padding(.horizontal, 20)
                        }
                        .buttonStyle(.plain)
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
            .frame(height: 220)
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
            if !voucher.isReceivedShare {
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
            }
            
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
            
            if !voucher.isReceivedShare {
                Button {
                    guard !isPreparingCloudSharing else { return }
                    sharingManager.beginSharingInitialization()
                    if voucher.isInActiveShare {
                        if showingCloudSharing {
                            showingCloudSharing = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                showingCloudSharing = true
                            }
                        } else {
                            showingCloudSharing = true
                        }
                    } else {
                        showingSharingDisclaimer = true
                    }
                } label: {
                    HStack {
                        if isPreparingCloudSharing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "person.2")
                        }
                        Text(isPreparingCloudSharing ? "Préparation du partage..." : (voucher.isInActiveShare ? "Gérer le partage" : "Partager"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
                .disabled(isPreparingCloudSharing)
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Balance Section
    
    private var balanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Historique des dépenses
            let expenses = currentExpenses
            if !expenses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Historique")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(expenses) { expense in
                        ExpenseRow(
                            date: expense.date,
                            note: expense.note,
                            authorDisplayName: expense.authorDisplayName,
                            amount: expense.amount,
                            canModify: true
                        ) {
                            expenseToPresent = .edit(expense)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
    
    @MainActor
    private func refreshSharedVoucherFromPull() async {
        guard voucher.isInActiveShare else { return }
        sharingManager.persistence.requestCloudRefresh(minimumInterval: 0)
        sharingManager.persistence.scheduleCloudRefreshes(delays: [1.0, 3.0])
        _ = await sharingManager.refreshSharedExpenseMirrors(
            for: [voucher],
            retryDelays: [1.0, 3.0, 6.0, 12.0]
        )
        refreshCurrentVoucher(reloadExpenses: true, reloadVoucher: true)
    }

    private func refreshSharedExpenseMirrorsInBackground(reason: String) {
        guard voucher.isInActiveShare else { return }

        Task { @MainActor in
            let mirroredChanges = await sharingManager.refreshSharedExpenseMirrors(
                for: [voucher],
                retryDelays: [1.0, 3.0, 6.0]
            )
            guard mirroredChanges else { return }
            debugLog("Miroir des dépenses du détail appliqué (\(reason))")
            refreshCurrentVoucher(reloadExpenses: true, reloadVoucher: true)
        }
    }

    private func refreshCurrentVoucher(reloadExpenses: Bool = false, reloadVoucher: Bool = false) {
        modelContext.processPendingChanges()
        guard voucher.managedObjectContext != nil, !voucher.isDeleted else {
            isVoucherDeleted = true
            return
        }
        for expense in voucher.activeExpensesList where expense.managedObjectContext != nil && !expense.isDeleted {
            modelContext.refresh(expense, mergeChanges: false)
        }
        modelContext.refresh(voucher, mergeChanges: false)
        sharingManager.reconcileSharingStates()
        if reloadExpenses {
            expenseRevision += 1
        }
        if reloadVoucher {
            voucherRevision += 1
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

    private var isFavorite: Bool {
        _ = favoriteRevision
        return voucher.isFavorite
    }

    private var currentExpenses: [Expense] {
        _ = expenseRevision
        return voucher.expensesList.sorted(by: { $0.date > $1.date })
    }
    
    private func deleteVoucher() {
        let objectID = voucher.objectID
        let voucherID = voucher.id
        let wasFavorite = voucher.isFavorite
        isVoucherDeleted = true
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard let voucherToDelete = try? modelContext.existingObject(with: objectID) as? Voucher else { return }
            sharingManager.revokeIfNeeded(for: voucherToDelete)
            SharedModelContainer.rememberDeletedVoucherForLegacyMigration(voucherToDelete)
            voucherToDelete.deletePersonalPreference(in: modelContext)
            modelContext.delete(voucherToDelete)

            do {
                try modelContext.save()
                NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
                if wasFavorite {
                    WidgetReloader.reloadFavoriteVouchersWidget()
                }
            } catch {
                debugLog("❌ Erreur lors de la suppression du bon: \(error)")
            }
        }
    }

    private func toggleFavorite() {
        let manager: FavoritesManager
        if let existingManager = favoritesManager {
            manager = existingManager
        } else {
            let newManager = FavoritesManager(modelContext: modelContext)
            favoritesManager = newManager
            manager = newManager
        }
        
        // Feedback haptique immédiat
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        
        let result = manager.toggleFavorite(voucher)
        
        switch result {
        case .added:
            generator.impactOccurred()
            // Recharger le widget quand on ajoute un favori
            WidgetReloader.reloadFavoriteVouchersWidget()
            
        case .removed:
            generator.impactOccurred()
            // Recharger le widget quand on retire un favori
            WidgetReloader.reloadFavoriteVouchersWidget()
            
        case .limitReached(let favorites):
            currentFavorites = favorites
            showingFavoriteLimitAlert = true
            
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.warning)
        }
    }
    
    private func restoreBrightness() {
        // Compatible iOS 26+
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let screen = windowScene.screen
            screen.brightness = initialBrightness
        }
        isBrightnessMaximized = false
    }
    
    private func toggleBrightness() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        let screen = windowScene.screen
        
        if isBrightnessMaximized {
            // Restaurer la luminosité initiale
            screen.brightness = initialBrightness
            isBrightnessMaximized = false
        } else {
            // Passer au maximum
            screen.brightness = 1.0
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
                
                if isSecret {
                    HStack(spacing: 8) {
                        Text(isRevealed ? value : "••••")
                            .font(.body)
                            .fontWeight(.medium)
                            .textSelection(.enabled)
                        Spacer(minLength: 0)
                        Button {
                            var transaction = Transaction()
                            transaction.animation = nil
                            withTransaction(transaction) {
                                isRevealed.toggle()
                            }
                        } label: {
                            Image(systemName: isRevealed ? "eye.slash" : "eye")
                                .font(.caption)
                                .frame(width: 18)
                        }
                        .buttonStyle(.plain)
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
    let date: Date
    let note: String?
    let authorDisplayName: String?
    let amount: Double
    let canModify: Bool
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(date.frenchLongFormat)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let author = authorDisplayName, !author.isEmpty {
                    Text(author)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                }

                Text(date.formatted(date: .omitted, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text("- \(amount.formattedEuro)")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.red)
            
            if canModify {
                Button(action: onEdit) {
                    Image(systemName: "pencil.circle")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct VoucherDetailRefreshEvents: ViewModifier {
    let voucher: Voucher
    let sharingManager: VoucherSharingManager
    let modelContext: NSManagedObjectContext
    @Binding var favoriteRevision: Int
    @Binding var expenseRevision: Int
    @Binding var voucherRevision: Int
    @Binding var isVoucherDeleted: Bool

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: FavoritesManager.favoritesDidChange)) { _ in
                favoriteRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherExpensesDidChange)) { notification in
                guard notification.object as? UUID == voucher.id else { return }
                refresh(reloadExpenses: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherDidChange)) { notification in
                if let voucherID = notification.object as? UUID, voucherID != voucher.id {
                    return
                }
                refresh(reloadVoucher: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherSharingDidChange)) { notification in
                if let voucherID = notification.object as? UUID, voucherID != voucher.id {
                    return
                }
                favoriteRevision += 1
                refresh(reloadVoucher: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherRemoteStoreDidChange)) { _ in
                guard voucher.isInActiveShare else { return }
                Task { @MainActor in
                    _ = await sharingManager.refreshSharedExpenseMirrors(
                        for: [voucher],
                        retryDelays: [1.0, 3.0, 6.0]
                    )
                    refresh(reloadExpenses: true, reloadVoucher: true)
                }
            }
    }

    private func refresh(reloadExpenses: Bool = false, reloadVoucher: Bool = false) {
        modelContext.processPendingChanges()
        if voucher.isDeleted || voucher.managedObjectContext == nil {
            isVoucherDeleted = true
            return
        }
        modelContext.refresh(voucher, mergeChanges: true)
        sharingManager.reconcileSharingStates()
        if voucher.isDeleted || voucher.managedObjectContext == nil {
            isVoucherDeleted = true
            return
        }
        if reloadExpenses {
            expenseRevision += 1
        }
        if reloadVoucher {
            voucherRevision += 1
        }
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
            context: PreviewData.shared.container.viewContext,
            storeName: "Carrefour",
            amount: 50.0,
            voucherNumber: "1234567890123",
            pinCode: "5678",
            codeType: .barcode,
            expirationDate: Date().addingTimeInterval(86400 * 30),
            storeColor: "#0055A5"
        ))
    }
    .environment(\.managedObjectContext, PreviewData.shared.container.viewContext)
    .environment(VoucherSharingManager(persistence: PreviewData.shared.persistence))
}
