//
//  ContentView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(URLHandler.self) var urlHandler
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Voucher.dateAdded, order: .reverse) private var vouchers: [Voucher]
    
    @State private var showingAddVoucher = false
    @State private var selectedStoreFilter: String?
    @State private var showExpiredVouchers = true
    @State private var navigationPath = NavigationPath()
    @State private var favoritesManager: FavoritesManager?
    @State private var showingFavoriteLimitAlert = false
    @State private var draggedVoucher: Voucher?
    
    var filteredVouchers: [Voucher] {
        var result = vouchers
        
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

    var favoriteVouchers: [Voucher] {
        filteredVouchers.filter { $0.isFavorite }
    }

    var otherVouchers: [Voucher] {
        filteredVouchers.filter { !$0.isFavorite }
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
            .onChange(of: showingAddVoucher) { oldValue, newValue in
                // Quand on ferme la vue d'ajout, recharger le widget
                if oldValue && !newValue {
                    // Petit délai pour laisser SwiftData sauvegarder
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
            .onAppear {
                if favoritesManager == nil {
                    favoritesManager = FavoritesManager(modelContext: modelContext)
                }
                initializeSortOrderIfNeeded()
            }
        }
        .monitorSettingsChanges() // Surveille les demandes de réinitialisation depuis les Réglages iOS
    }
    
    private var emptyStateView: some View {
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
        .padding()
    }
    
    private var voucherListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if canReorder || !favoriteVouchers.isEmpty {
                    sectionHeader("Mes bons d'achat favoris", isFavoriteSection: true)

                    if favoriteVouchers.isEmpty {
                        sectionDropHint(
                            "Glissez un bon ici pour l'ajouter aux favoris",
                            isFavoriteSection: true
                        )
                    }

                    ForEach(favoriteVouchers) { voucher in
                        voucherRow(voucher, isFavoriteSection: true)
                    }
                }

                if canReorder || !otherVouchers.isEmpty {
                    sectionHeader("Mes autres bons d'achat", isFavoriteSection: false)

                    if otherVouchers.isEmpty {
                        sectionDropHint(
                            "Glissez un bon ici pour le retirer des favoris",
                            isFavoriteSection: false
                        )
                    }

                    ForEach(otherVouchers) { voucher in
                        voucherRow(voucher, isFavoriteSection: false)
                    }
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredVouchers.map(\.id))
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
    private func voucherRow(_ voucher: Voucher, isFavoriteSection: Bool) -> some View {
        let row = ZStack(alignment: .topLeading) {
            Button {
                navigationPath.append(voucher)
            } label: {
                VoucherCardView(voucher: voucher, showsFavoriteIcon: false)
            }
            .buttonStyle(.plain)

            Button {
                toggleFavorite(voucher)
            } label: {
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.001)
                        .frame(width: 56, height: 56)

                    Image(systemName: voucher.isFavorite ? "star.fill" : "star")
                        .font(.title2)
                        .foregroundStyle(voucher.isFavorite ? .yellow : Color(hex: voucher.textColor).opacity(0.9))
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
        .transition(.scale.combined(with: .opacity))

        if canReorder {
            row
                .onDrag {
                    draggedVoucher = voucher
                    return NSItemProvider(object: voucher.id.uuidString as NSString)
                }
                .onDrop(
                    of: [UTType.text],
                    delegate: VoucherDropDelegate(
                        targetVoucher: voucher,
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
        
        let result = manager.toggleFavorite(voucher)
        
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

    private func initializeSortOrderIfNeeded() {
        guard vouchers.count > 1 else { return }
        guard vouchers.allSatisfy({ $0.sortOrder == 0 }) else { return }

        let orderedByDate = vouchers.sorted { $0.dateAdded > $1.dateAdded }
        for (index, voucher) in orderedByDate.enumerated() {
            voucher.sortOrder = index
        }

        do {
            try modelContext.save()
        } catch {
            print("❌ Erreur lors de l'initialisation du tri: \(error)")
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
            if reloadFavoriteWidget {
                WidgetReloader.reloadFavoriteVouchersWidget()
            }
        } catch {
            print("❌ Erreur lors de la sauvegarde du tri: \(error)")
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
        .modelContainer(PreviewData.shared.container)
        .environment(URLHandler())
}
