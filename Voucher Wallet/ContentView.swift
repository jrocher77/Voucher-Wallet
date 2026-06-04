//
//  ContentView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import CoreData
import Combine
import Network
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(URLHandler.self) var urlHandler
    @Environment(VoucherSharingManager.self) private var sharingManager
    @Environment(\.managedObjectContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Voucher.dateAdded, ascending: false)],
        animation: .default
    ) private var fetchedVouchers: FetchedResults<Voucher>
    
    @State private var showingAddVoucher = false
    @State private var selectedStoreFilter: String?
    @State private var showExpiredVouchers = true
    @State private var navigationPath = NavigationPath()
    @State private var favoritesManager: FavoritesManager?
    @State private var showingFavoriteLimitAlert = false
    @State private var draggedVoucher: Voucher?
    @State private var voucherToEdit: Voucher?
    @State private var voucherToDelete: Voucher?
    @State private var showingDeleteAlert = false
    @State private var favoriteRevision = 0
    @State private var cloudRefreshStatus: CloudRefreshStatus?
    @State private var cloudRefreshStatusToken = UUID()
    @State private var lastCloudSyncBannerDate = Date.distantPast
    @State private var remoteTransactionRevision = 0
    @State private var sharingStatusToken = UUID()
    @State private var receivedSharedVouchers: [Voucher] = []
    @State private var receivedShareRevision = 0
    @State private var cloudNetworkMonitor = NWPathMonitor()
    @State private var cloudNetworkMonitorQueue = DispatchQueue(label: "VoucherWallet.CloudNetworkMonitor")
    @State private var isCloudNetworkAvailable = true
    @State private var didStartCloudNetworkMonitor = false

    private let favoriteChangeAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)

    private enum CloudRefreshStatus: Equatable {
        case syncing
        case completed
        case noRemoteData
        case offline
        case failed

        var text: String {
            switch self {
            case .syncing:
                return "Synchronisation iCloud en cours..."
            case .completed:
                return "Synchronisation iCloud terminée"
            case .noRemoteData:
                return "Aucune nouvelle donnée iCloud"
            case .offline:
                return "Synchronisation impossible"
            case .failed:
                return "Synchronisation impossible"
            }
        }

        var systemImage: String {
            switch self {
            case .syncing:
                return "arrow.triangle.2.circlepath.icloud"
            case .completed:
                return "checkmark.icloud"
            case .noRemoteData:
                return "icloud.slash"
            case .offline:
                return "wifi.slash"
            case .failed:
                return "exclamationmark.icloud"
            }
        }
    }

    private var vouchers: [Voucher] {
        _ = receivedShareRevision
        var seenObjectIDs = Set<NSManagedObjectID>()
        let uniqueObjects = (Array(fetchedVouchers) + receivedSharedVouchers).filter { voucher in
            guard voucher.managedObjectContext != nil, !voucher.isDeleted else { return false }
            guard !SharedModelContainer.isDeletedLegacyVoucher(voucher) else { return false }
            return seenObjectIDs.insert(voucher.objectID).inserted
        }.filter { voucher in
            voucher.managedObjectContext != nil &&
                !voucher.isDeleted &&
                !SharedModelContainer.isDeletedLegacyVoucher(voucher)
        }
        return uniqueObjects.reduce(into: [UUID: Voucher]()) { result, voucher in
            guard let existing = result[voucher.id] else {
                result[voucher.id] = voucher
                return
            }
            result[voucher.id] = Self.preferredVisibleVoucher(existing, voucher)
        }.map(\.value)
    }

    private static func preferredVisibleVoucher(_ lhs: Voucher, _ rhs: Voucher) -> Voucher {
        let lhsScore = visibleVoucherScore(lhs)
        let rhsScore = visibleVoucherScore(rhs)
        if lhsScore != rhsScore {
            return lhsScore > rhsScore ? lhs : rhs
        }
        return lhs.dateAdded <= rhs.dateAdded ? lhs : rhs
    }

    private static func visibleVoucherScore(_ voucher: Voucher) -> Int {
        var score = 0
        if voucher.isFavorite { score += 16 }
        if voucher.amount != nil { score += 8 }
        if voucher.codeType == .qrCode { score += 4 }
        if voucher.codeImageData != nil { score += 2 }
        if voucher.pdfData != nil { score += 1 }
        return score
    }

    private struct VoucherListItem: Identifiable {
        let id: UUID
        let voucher: Voucher
        let storeName: String
        let voucherNumber: String
        let amount: Double?
        let remainingBalance: Double
        let totalExpenses: Double
        let expirationDate: Date?
        let storeColor: String
        let textColor: String
        let isFavorite: Bool
        let sortOrder: Int
        let dateAdded: Date
        let isReceivedShare: Bool
        let isInActiveShare: Bool

        init(voucher: Voucher) {
            let activeExpenses = voucher.activeExpensesList
            let activeTotal = activeExpenses.reduce(0) { $0 + $1.amount }
            let amount = voucher.amount

            self.id = voucher.id
            self.voucher = voucher
            self.storeName = voucher.storeName
            self.voucherNumber = voucher.voucherNumber
            self.amount = amount
            let remainingBalance = voucher.remainingBalance
            self.remainingBalance = remainingBalance
            self.totalExpenses = amount.map { $0 - remainingBalance } ?? activeTotal
            self.expirationDate = voucher.expirationDate
            self.storeColor = voucher.storeColor
            self.textColor = voucher.textColor
            self.isFavorite = voucher.isFavorite
            self.sortOrder = voucher.sortOrder
            self.dateAdded = voucher.dateAdded
            self.isReceivedShare = voucher.isReceivedShare
            self.isInActiveShare = voucher.isInActiveShare
        }

        var cardItem: VoucherCardItem {
            VoucherCardItem(
                storeName: storeName,
                voucherNumber: voucherNumber,
                amount: amount,
                remainingBalance: remainingBalance,
                totalExpenses: totalExpenses,
                expirationDate: expirationDate,
                storeColor: storeColor,
                textColor: textColor,
                isFavorite: isFavorite,
                isReceivedShare: isReceivedShare,
                isInActiveShare: isInActiveShare
            )
        }
    }

    @MainActor
    private var voucherItems: [VoucherListItem] {
        _ = favoriteRevision
        return vouchers.map(VoucherListItem.init)
    }
    
    @MainActor
    private var filteredVoucherItems: [VoucherListItem] {
        var result = voucherItems
        
        // Filtre par enseigne
        if let store = selectedStoreFilter {
            result = result.filter { $0.storeName == store }
        }
        
        // Filtre pour masquer les bons expirés
        if !showExpiredVouchers {
            result = result.filter { voucher in
                guard let expiration = voucher.expirationDate else { return true }
                let calendar = Calendar.current
                let today = calendar.startOfDay(for: Date())
                let expirationDay = calendar.startOfDay(for: expiration)
                return expirationDay >= today
            }
        }
        
        // Trier par ordre personnalisé, puis fallback sur la date d'ajout
        return result.sorted {
            if $0.sortOrder != $1.sortOrder {
                return $0.sortOrder < $1.sortOrder
            }
            return $0.dateAdded > $1.dateAdded
        }
    }

    @MainActor
    private var walletSections: (favorites: [VoucherListItem], others: [VoucherListItem]) {
        let items = filteredVoucherItems
        return (
            favorites: items.filter(\.isFavorite),
            others: items.filter { !$0.isFavorite }
        )
    }

    @MainActor
    private var favoriteVoucherItems: [VoucherListItem] {
        walletSections.favorites
    }

    @MainActor
    private var otherVoucherItems: [VoucherListItem] {
        walletSections.others
    }

    @MainActor
    private var favoriteVouchers: [Voucher] {
        favoriteVoucherItems.map(\.voucher)
    }

    @MainActor
    private var otherVouchers: [Voucher] {
        otherVoucherItems.map(\.voucher)
    }
    
    var uniqueStores: [String] {
        Array(Set(vouchers.map { $0.storeName })).sorted()
    }

    private var canReorder: Bool {
        selectedStoreFilter == nil && showExpiredVouchers
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            Group {
                if vouchers.isEmpty {
                    emptyStateView
                } else {
                    voucherListView
                }
            }
            .navigationDestination(for: Voucher.self) { voucher in
                VoucherDetailView(voucher: voucher)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddVoucher = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        filterMenu
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showingAddVoucher) {
                AddVoucherView()
            }
            .sheet(item: $voucherToEdit) { voucher in
                EditVoucherView(voucher: voucher)
            }
            .onChange(of: showingAddVoucher) { oldValue, newValue in
                // Quand on ferme la vue d'ajout, recharger le widget
                if oldValue && !newValue {
                    // Petit délai pour laisser la sauvegarde s'achever
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        WidgetReloader.reloadAllWidgets()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { urlHandler.shouldShowImport },
                set: { if !$0 { 
                    urlHandler.shouldShowImport = false
                    urlHandler.pdfData = nil
                }}
            )) {
                if let pdfData = urlHandler.pdfData {
                    AddVoucherView(initialPDFData: pdfData, allowsManualEntry: false)
                }
            }
            .onChange(of: urlHandler.shouldShowImport) { oldValue, newValue in
                // Quand on ferme l'import PDF, recharger le widget
                if oldValue && !newValue {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        WidgetReloader.reloadAllWidgets()
                    }
                }
            }
            .onChange(of: urlHandler.selectedVoucherID) { oldValue, newValue in
                guard let voucherID = newValue else { return }
                
                // Trouver le voucher correspondant
                if let voucher = vouchers.first(where: { $0.id == voucherID }) {
                    // Naviguer vers le détail
                    navigationPath.append(voucher)
                    
                    // Réinitialiser l'ID sélectionné
                    urlHandler.selectedVoucherID = nil
                }
            }
            .alert("Limite atteinte", isPresented: $showingFavoriteLimitAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Vous ne pouvez avoir que 4 cartes en favoris. Veuillez d'abord retirer une carte des favoris.")
            }
            .alert("Supprimer ce bon ?", isPresented: $showingDeleteAlert) {
                Button("Annuler", role: .cancel) {
                    voucherToDelete = nil
                }
                Button("Supprimer", role: .destructive) {
                    deleteVoucherPendingDeletion()
                }
            } message: {
                Text("Cette action est irréversible.")
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
                startCloudNetworkMonitoringIfNeeded()
                if favoritesManager == nil {
                    favoritesManager = FavoritesManager(modelContext: modelContext)
                }
                reloadReceivedSharedVouchers(reason: "wallet-appear")
                refreshSharedExpenseMirrorsInBackground(reason: "wallet-appear")
                initializeSortOrderIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: FavoritesManager.favoritesDidChange)) { _ in
                favoriteRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherSharingDidChange)) { _ in
                favoriteRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherShareAccepted)) { _ in
                try? modelContext.setQueryGenerationFrom(.current)
                modelContext.processPendingChanges()
                reloadReceivedSharedVouchers(reason: "share-accepted")
                favoriteRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherRemoteStoreDidChange)) { notification in
                try? modelContext.setQueryGenerationFrom(.current)
                refreshVisibleVouchers(reason: "remote-store-change")
                let cleanedFavoritePreferences = FavoritesManager.deleteOrphanedPreferences(in: modelContext)
                if cleanedFavoritePreferences {
                    favoriteRevision += 1
                }
                WidgetReloader.reloadAllWidgets()
                refreshSharedExpenseMirrorsInBackground(reason: "remote-store-change")
                let transactionCount = notification.userInfo?["transactionCount"] as? Int ?? 0
                if transactionCount > 0 {
                    remoteTransactionRevision += transactionCount
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: SharedModelContainer.cloudSyncStatusNotificationName)) { notification in
                guard let status = notification.object as? String else { return }
                switch status {
                case "started":
                    showCloudSyncStartedStatusIfNeeded()
                case "failed":
                    showCloudRefreshStatus(isCloudNetworkAvailable ? .failed : .offline, autoHideAfter: 8)
                default:
                    break
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherDidChange)) { notification in
                if let voucherID = notification.object as? UUID,
                   let voucher = vouchers.first(where: { $0.id == voucherID }) {
                    modelContext.refresh(voucher, mergeChanges: false)
                } else {
                    refreshVisibleVouchers()
                    return
                }
                favoriteRevision += 1
            }
            .onReceive(NotificationCenter.default.publisher(for: .voucherExpensesDidChange)) { notification in
                if let voucherID = notification.object as? UUID,
                   let voucher = vouchers.first(where: { $0.id == voucherID }) {
                    modelContext.refresh(voucher, mergeChanges: false)
                } else {
                    refreshVisibleVouchers()
                    return
                }
                favoriteRevision += 1
            }
            .onChange(of: sharingManager.sharingStatusMessage) { _, newValue in
                if newValue != nil {
                    withAnimation(.easeOut(duration: 0.2)) {
                        cloudRefreshStatus = nil
                    }
                }
                scheduleSharingStatusAutoHide(for: newValue)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                startCloudNetworkMonitoringIfNeeded()
                sharingManager.persistence.scheduleCloudRefreshes(delays: [0.0, 1.0, 3.0])
                reloadReceivedSharedVouchers(reason: "scene-active")
                refreshSharedExpenseMirrorsInBackground(reason: "scene-active")
            }
        }
        .monitorSettingsChanges() // Surveille les demandes de réinitialisation depuis les Réglages iOS
        .overlay(alignment: .top) {
            compactCloudStatusBanner
                .padding(.top, 6)
                .padding(.horizontal, 54)
        }
    }

    private func refreshSharedExpenseMirrorsInBackground(reason: String) {
        let sharedVouchers = vouchers.filter(\.isInActiveShare)
        guard !sharedVouchers.isEmpty else { return }

        Task { @MainActor in
            let mirroredChanges = await sharingManager.refreshSharedExpenseMirrors(for: sharedVouchers)
            guard mirroredChanges else { return }
            debugLog("Miroir des dépenses partagées appliqué (\(reason))")
            refreshVisibleVouchers(reason: "shared-expense-mirror-\(reason)")
        }
    }

    private func refreshVisibleVouchers(reason: String = "wallet-refresh-event") {
        let purgedDeletedLegacyVouchers = SharedModelContainer.purgeDeletedLegacyVouchers(in: modelContext)
        let visibleVouchers = vouchers
        modelContext.processPendingChanges()
        for voucher in visibleVouchers where voucher.managedObjectContext != nil && !voucher.isDeleted {
            refreshVoucherGraph(voucher)
        }
        modelContext.processPendingChanges()
        sharingManager.reconcileSharingStates()
        reloadReceivedSharedVouchers(reason: reason)
        favoriteRevision += 1
        if purgedDeletedLegacyVouchers {
            WidgetReloader.reloadAllWidgets()
        }
    }

    private func refreshVoucherGraph(_ voucher: Voucher) {
        for expense in voucher.activeExpensesList where expense.managedObjectContext != nil && !expense.isDeleted {
            modelContext.refresh(expense, mergeChanges: false)
        }
        modelContext.refresh(voucher, mergeChanges: false)
    }

    @MainActor
    private func refreshSharedVouchersFromPull() async {
        let startingRevision = remoteTransactionRevision
        let sharedVouchers = vouchers.filter(\.isInActiveShare)

        showCloudRefreshStatus(.syncing)
        sharingManager.persistence.requestCloudRefresh(minimumInterval: 0)
        sharingManager.persistence.scheduleCloudRefreshes(delays: [1.0, 3.0])

        let mirroredChanges = await sharingManager.refreshSharedExpenseMirrors(for: sharedVouchers)
        refreshVisibleVouchers(reason: "manual-pull-refresh")

        if remoteTransactionRevision > startingRevision || mirroredChanges {
            showCloudRefreshStatus(.completed)
            WidgetReloader.reloadAllWidgets()
        } else {
            debugLog("Pull-to-refresh iCloud terminé sans transaction distante fusionnée ni miroir de dépense")
            showCloudRefreshStatus(.noRemoteData, autoHideAfter: 5)
        }
    }

    private func reloadReceivedSharedVouchers(reason: String) {
        guard let sharedStore = sharingManager.persistence.sharedStore else {
            receivedSharedVouchers = []
            receivedShareRevision += 1
            return
        }

        let request = Voucher.fetchRequest()
        request.affectedStores = [sharedStore]
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Voucher.dateAdded, ascending: false)]
        request.includesPendingChanges = true
        request.returnsObjectsAsFaults = false

        do {
            receivedSharedVouchers = try modelContext.fetch(request).filter { voucher in
                voucher.managedObjectContext != nil &&
                    !voucher.isDeleted &&
                    !SharedModelContainer.isDeletedLegacyVoucher(voucher)
            }
            receivedShareRevision += 1
            debugLog("Wallet partagé relu (\(reason)): \(receivedSharedVouchers.count) bon(s)")
        } catch {
            debugLog("Lecture du wallet partagé impossible (\(reason)): \(error.localizedDescription)")
        }
    }
    
    private var emptyStateView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "wallet.pass")
                    .font(.system(size: 80))
                    .foregroundStyle(.secondary)
                
                Text("Aucun bon d'achat")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Ajoutez votre premier bon en appuyant sur +")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button {
                    showingAddVoucher = true
                } label: {
                    Label("Ajouter un bon", systemImage: "plus")
                        .font(.headline)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.large)
                .padding(.top)
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .refreshable {
            await refreshSharedVouchersFromPull()
        }
    }
    
    @ViewBuilder
    private var voucherListView: some View {
        let sections = walletSections

        ScrollView {
            LazyVStack(spacing: 16) {
                if canReorder || !sections.favorites.isEmpty {
                    sectionHeader("Mes bons d'achat favoris", isFavoriteSection: true)

                    if sections.favorites.isEmpty {
                        sectionDropHint(
                            "Glissez un bon ici pour l'ajouter aux favoris",
                            isFavoriteSection: true
                        )
                    }

                    ForEach(sections.favorites) { item in
                        voucherRow(item, isFavoriteSection: true)
                    }
                }

                if canReorder || !sections.others.isEmpty {
                    sectionHeader("Mes autres bons d'achat", isFavoriteSection: false)

                    if sections.others.isEmpty {
                        sectionDropHint(
                            "Glissez un bon ici pour le retirer des favoris",
                            isFavoriteSection: false
                        )
                    }

                    ForEach(sections.others) { item in
                        voucherRow(item, isFavoriteSection: false)
                    }
                }
            }
            .padding()
            .animation(favoriteChangeAnimation, value: sections.favorites.map(\.id))
            .animation(favoriteChangeAnimation, value: sections.others.map(\.id))
        }
        .refreshable {
            await refreshSharedVouchersFromPull()
        }
    }

    @ViewBuilder
    private var compactCloudStatusBanner: some View {
        if let status = compactCloudStatus {
            HStack(spacing: 7) {
                if status.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: status.systemImage)
                        .font(.caption)
                        .foregroundStyle(status.tint)
                }

                Text(status.text)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: 280)
            .background(.thinMaterial, in: Capsule())
            .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private struct CompactCloudStatus {
        let text: String
        let systemImage: String
        let tint: Color
        let isLoading: Bool
    }

    private var compactCloudStatus: CompactCloudStatus? {
        if let message = sharingManager.sharingStatusMessage {
            let isLoading = message.contains("...")
                || message.contains("synchronisation")
                || message.contains("Acceptation")
                || message.contains("Initialisation")
                || message.contains("Configuration")
            return CompactCloudStatus(
                text: message,
                systemImage: "arrow.triangle.2.circlepath.icloud",
                tint: .blue,
                isLoading: isLoading
            )
        }

        guard let cloudRefreshStatus else { return nil }
        return CompactCloudStatus(
            text: cloudRefreshStatus.text,
            systemImage: cloudRefreshStatus.systemImage,
            tint: cloudRefreshStatus == .failed || cloudRefreshStatus == .noRemoteData || cloudRefreshStatus == .offline ? .orange : .green,
            isLoading: cloudRefreshStatus == .syncing
        )
    }

    private func startCloudNetworkMonitoringIfNeeded() {
        guard !didStartCloudNetworkMonitor else { return }
        didStartCloudNetworkMonitor = true
        cloudNetworkMonitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                let isAvailable = path.status == .satisfied
                isCloudNetworkAvailable = isAvailable
                if !isAvailable, cloudRefreshStatus == .syncing {
                    showCloudRefreshStatus(.offline, autoHideAfter: 6)
                }
            }
        }
        cloudNetworkMonitor.start(queue: cloudNetworkMonitorQueue)
    }

    private func showCloudSyncStartedStatusIfNeeded() {
        let now = Date()
        guard now.timeIntervalSince(lastCloudSyncBannerDate) >= 10 else {
            return
        }

        lastCloudSyncBannerDate = now
        if isCloudNetworkAvailable {
            guard cloudRefreshStatus != .syncing else { return }
            showCloudRefreshStatus(.syncing, autoHideAfter: 4)
        } else {
            showCloudRefreshStatus(.offline, autoHideAfter: 6)
        }
    }

    @discardableResult
    private func showCloudRefreshStatus(_ status: CloudRefreshStatus, autoHideAfter: TimeInterval? = nil) -> UUID {
        let token = UUID()
        cloudRefreshStatusToken = token

        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            cloudRefreshStatus = status
        }

        let delay = autoHideAfter ?? (status == .syncing ? nil : 3.5)
        guard let delay else { return token }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard cloudRefreshStatusToken == token else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                cloudRefreshStatus = nil
            }
        }
        return token
    }

    private func scheduleSharingStatusAutoHide(for message: String?) {
        let token = UUID()
        sharingStatusToken = token

        guard let message else { return }
        let delay: TimeInterval
        if message.contains("Acceptation") || message.contains("synchronisation") || message.contains("Initialisation") || message.contains("Configuration") || message.contains("...") {
            delay = 6
        } else if message.contains("échou") || message.contains("impossible") {
            delay = 8
        } else {
            delay = 4
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard sharingStatusToken == token,
                  sharingManager.sharingStatusMessage == message else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                sharingManager.sharingStatusMessage = nil
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, isFavoriteSection: Bool) -> some View {
        let header = HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.top, 4)

        if canReorder {
            header
                .onDrop(
                    of: [UTType.text],
                    delegate: VoucherDropDelegate(
                        targetVoucher: nil,
                        targetIsFavorite: isFavoriteSection,
                        draggedVoucher: $draggedVoucher,
                        onMoveToVoucher: moveVoucher,
                        onMoveToSection: moveVoucherToSectionEnd
                    )
                )
        } else {
            header
        }
    }

    @ViewBuilder
    private func sectionDropHint(_ text: String, isFavoriteSection: Bool) -> some View {
        let hint = Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [5]))
            )

        if canReorder {
            hint
                .onDrop(
                    of: [UTType.text],
                    delegate: VoucherDropDelegate(
                        targetVoucher: nil,
                        targetIsFavorite: isFavoriteSection,
                        draggedVoucher: $draggedVoucher,
                        onMoveToVoucher: moveVoucher,
                        onMoveToSection: moveVoucherToSectionEnd
                    )
                )
        } else {
            hint
        }
    }

    @ViewBuilder
    private func voucherRow(_ item: VoucherListItem, isFavoriteSection: Bool) -> some View {
        let row = ZStack(alignment: .topLeading) {
            Button {
                navigationPath.append(item.voucher)
            } label: {
                VoucherCardView(item: item.cardItem, showsFavoriteIcon: false)
                    .id("\(item.id)-\(favoriteRevision)")
            }
            .buttonStyle(.plain)

            Button {
                toggleFavorite(item.voucher)
            } label: {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .frame(width: 56, height: 56)

                    Image(systemName: item.isFavorite ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(item.isFavorite ? .yellow : Color(hex: item.textColor).opacity(0.9))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .symbolEffect(.bounce, value: item.isFavorite)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 12)
            .zIndex(1)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
        .contextMenu {
            voucherContextMenu(for: item.voucher)
        }

        if canReorder {
            row
                .onDrag {
                    draggedVoucher = item.voucher
                    return NSItemProvider(object: item.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: VoucherDropDelegate(
                        targetVoucher: item.voucher,
                        targetIsFavorite: isFavoriteSection,
                        draggedVoucher: $draggedVoucher,
                        onMoveToVoucher: moveVoucher,
                        onMoveToSection: moveVoucherToSectionEnd
                    )
                )
        } else {
            row
        }
    }

    @ViewBuilder
    private func voucherContextMenu(for voucher: Voucher) -> some View {
        Button {
            toggleFavoriteFromContextMenu(voucher)
        } label: {
            Label(
                voucher.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                systemImage: voucher.isFavorite ? "star.fill" : "star"
            )
        }

        Button {
            if voucher.isReceivedShare {
                sharingManager.removeReceivedVoucher(voucher, after: 0.15)
            } else {
                voucherToEdit = voucher
            }
        } label: {
            Label(
                voucher.isReceivedShare ? "Quitter le partage" : "Modifier",
                systemImage: voucher.isReceivedShare ? "rectangle.portrait.and.arrow.right" : "pencil"
            )
        }

        if !voucher.isReceivedShare {
            Divider()

            Button(role: .destructive) {
                voucherToDelete = voucher
                showingDeleteAlert = true
            } label: {
                Label("Supprimer", systemImage: "trash")
            }
        }
    }

    private func toggleFavoriteFromContextMenu(_ voucher: Voucher) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            toggleFavorite(voucher)
        }
    }

    private func toggleFavorite(_ voucher: Voucher) {
        let manager: FavoritesManager
        if let existingManager = favoritesManager {
            manager = existingManager
        } else {
            let newManager = FavoritesManager(modelContext: modelContext)
            favoritesManager = newManager
            manager = newManager
        }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()

        let result = withAnimation(favoriteChangeAnimation) {
            manager.toggleFavorite(voucher)
        }
        
        switch result {
        case .added, .removed:
            generator.impactOccurred()
            WidgetReloader.reloadFavoriteVouchersWidget()
        case .limitReached:
            showingFavoriteLimitAlert = true
            let notificationGenerator = UINotificationFeedbackGenerator()
            notificationGenerator.notificationOccurred(.warning)
        }
    }

    private func deleteVoucherPendingDeletion() {
        guard let voucher = voucherToDelete else { return }
        let objectID = voucher.objectID
        let voucherID = voucher.id
        let wasFavorite = voucher.isFavorite
        voucherToDelete = nil
        navigationPath.removeLast(navigationPath.count)

        guard let voucherToDelete = try? modelContext.existingObject(with: objectID) as? Voucher else { return }
        sharingManager.revokeIfNeeded(for: voucherToDelete)
        SharedModelContainer.rememberDeletedVoucherForLegacyMigration(voucherToDelete)
        voucherToDelete.deletePersonalPreference(in: modelContext)
        modelContext.delete(voucherToDelete)
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
            refreshVisibleVouchers()
            if wasFavorite {
                WidgetReloader.reloadFavoriteVouchersWidget()
            }
        } catch {
            debugLog("❌ Erreur lors de la suppression du bon: \(error)")
        }
    }

    private func initializeSortOrderIfNeeded() {
        guard vouchers.count > 1 else { return }
        guard vouchers.allSatisfy({ $0.sortOrder == 0 }) else { return }

        let orderedByDate = vouchers.sorted { $0.dateAdded > $1.dateAdded }
        for (index, voucher) in orderedByDate.enumerated() {
            voucher.sortOrder = index
        }

        do {
            try modelContext.save()
            FavoritesManager.notifyChange()
        } catch {
            debugLog("❌ Erreur lors de l'initialisation du tri: \(error)")
        }
    }

    private func moveVoucher(_ dragged: Voucher, _ target: Voucher, _ isFavoriteSection: Bool) {
        guard dragged.id != target.id else { return }
        guard target.isFavorite == isFavoriteSection else { return }

        if dragged.isFavorite == isFavoriteSection {
            var sectionVouchers = isFavoriteSection ? favoriteVouchers : otherVouchers
            guard
                let fromIndex = sectionVouchers.firstIndex(where: { $0.id == dragged.id }),
                let toIndex = sectionVouchers.firstIndex(where: { $0.id == target.id }),
                fromIndex != toIndex
            else {
                return
            }

            sectionVouchers.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
            )

            if isFavoriteSection {
                applySortOrder(favorites: sectionVouchers, others: otherVouchers, reloadFavoriteWidget: true)
            } else {
                applySortOrder(favorites: favoriteVouchers, others: sectionVouchers, reloadFavoriteWidget: false)
            }
            return
        }

        if isFavoriteSection && favoriteVouchers.count >= FavoritesManager.maxFavorites {
            showingFavoriteLimitAlert = true
            return
        }

        var sourceSection = isFavoriteSection ? otherVouchers : favoriteVouchers
        var destinationSection = isFavoriteSection ? favoriteVouchers : otherVouchers

        guard
            let sourceIndex = sourceSection.firstIndex(where: { $0.id == dragged.id }),
            let targetIndex = destinationSection.firstIndex(where: { $0.id == target.id })
        else {
            return
        }

        sourceSection.remove(at: sourceIndex)
        destinationSection.insert(dragged, at: targetIndex)
        dragged.isFavorite = isFavoriteSection

        if isFavoriteSection {
            applySortOrder(favorites: destinationSection, others: sourceSection, reloadFavoriteWidget: true)
        } else {
            applySortOrder(favorites: sourceSection, others: destinationSection, reloadFavoriteWidget: true)
        }
    }

    private func moveVoucherToSectionEnd(_ dragged: Voucher, _ targetIsFavorite: Bool) {
        guard dragged.isFavorite != targetIsFavorite else { return }

        if targetIsFavorite && favoriteVouchers.count >= FavoritesManager.maxFavorites {
            showingFavoriteLimitAlert = true
            return
        }

        var sourceSection = targetIsFavorite ? otherVouchers : favoriteVouchers
        var destinationSection = targetIsFavorite ? favoriteVouchers : otherVouchers

        guard let sourceIndex = sourceSection.firstIndex(where: { $0.id == dragged.id }) else { return }
        sourceSection.remove(at: sourceIndex)
        destinationSection.append(dragged)
        dragged.isFavorite = targetIsFavorite

        if targetIsFavorite {
            applySortOrder(favorites: destinationSection, others: sourceSection, reloadFavoriteWidget: true)
        } else {
            applySortOrder(favorites: sourceSection, others: destinationSection, reloadFavoriteWidget: true)
        }
    }

    private func applySortOrder(favorites: [Voucher], others: [Voucher], reloadFavoriteWidget: Bool) {
        var index = 0

        for voucher in favorites {
            voucher.sortOrder = index
            index += 1
        }

        for voucher in others {
            voucher.sortOrder = index
            index += 1
        }

        do {
            try modelContext.save()
            FavoritesManager.notifyChange()
            if reloadFavoriteWidget {
                WidgetReloader.reloadFavoriteVouchersWidget()
            }
        } catch {
            debugLog("❌ Erreur lors de la sauvegarde du tri: \(error)")
        }
    }
    
    private var filterMenu: some View {
        Group {
            // Filtre par enseigne
            Menu("Enseigne") {
                Button {
                    selectedStoreFilter = nil
                } label: {
                    if selectedStoreFilter == nil {
                        Label("Toutes", systemImage: "checkmark")
                    } else {
                        Text("Toutes")
                    }
                }
                
                Divider()
                
                ForEach(uniqueStores, id: \.self) { store in
                    Button {
                        selectedStoreFilter = store
                    } label: {
                        if selectedStoreFilter == store {
                            Label(store, systemImage: "checkmark")
                        } else {
                            Text(store)
                        }
                    }
                }
            }
            
            Divider()
            
            // Toggle pour bons expirés
            Toggle(isOn: $showExpiredVouchers) {
                Label("Afficher les expirés", systemImage: "clock.badge.xmark")
            }
        }
    }
}

private struct VoucherDropDelegate: DropDelegate {
    let targetVoucher: Voucher?
    let targetIsFavorite: Bool
    @Binding var draggedVoucher: Voucher?
    let onMoveToVoucher: (Voucher, Voucher, Bool) -> Void
    let onMoveToSection: (Voucher, Bool) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedVoucher else { return }
        if let targetVoucher {
            onMoveToVoucher(draggedVoucher, targetVoucher, targetIsFavorite)
        } else {
            onMoveToSection(draggedVoucher, targetIsFavorite)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedVoucher = nil
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PreviewData.shared.container.viewContext)
        .environment(URLHandler())
        .environment(VoucherSharingManager(persistence: PreviewData.shared.persistence))
}
