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
    @Query(sort: \Voucher.dateAdded, order: .reverse) private var vouchers: [Voucher]
    
    @State private var showingAddVoucher = false
    @State private var selectedStoreFilter: String?
    @State private var showExpiredVouchers = true
    @State private var navigationPath = NavigationPath()
    
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
        
        // Trier : favoris en premier, puis par date d'ajout
        return result.sorted { lhs, rhs in
            if lhs.isFavorite && !rhs.isFavorite {
                return true
            } else if !lhs.isFavorite && rhs.isFavorite {
                return false
            } else {
                return lhs.dateAdded > rhs.dateAdded
            }
        }
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
            .navigationTitle("Mes Bons")
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
                    PDFImportHandler(pdfData: pdfData)
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
            .controlSize(.large)
            .padding(.top)
        }
        .padding()
    }
    
    private var voucherListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredVouchers) { voucher in
                    Button {
                        navigationPath.append(voucher)
                    } label: {
                        VoucherCardView(voucher: voucher)
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: filteredVouchers.map { $0.id })
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
