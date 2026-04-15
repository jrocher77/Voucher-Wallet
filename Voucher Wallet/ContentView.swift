//
//  ContentView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

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
        
        // Trier par date d'ajout (plus récent en premier)
        return result.sorted { $0.dateAdded > $1.dateAdded }
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
                if !favoriteVouchers.isEmpty {
                    sectionHeader("Mes bons d'achat favoris")
                    ForEach(favoriteVouchers) { voucher in
                        voucherRow(voucher)
                    }
                }

                if !otherVouchers.isEmpty {
                    sectionHeader("Mes autres bons d'achat")
                    ForEach(otherVouchers) { voucher in
                        voucherRow(voucher)
                    }
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredVouchers.map(\.id))
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.top, 4)
    }

    private func voucherRow(_ voucher: Voucher) -> some View {
        ZStack(alignment: .topLeading) {
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

#Preview {
    ContentView()
        .modelContainer(PreviewData.shared.container)
        .environment(URLHandler())
}
