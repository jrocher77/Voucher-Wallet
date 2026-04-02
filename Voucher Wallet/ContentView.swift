//
//  ContentView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Voucher.dateAdded, order: .reverse) private var vouchers: [Voucher]
    
    @State private var showingAddVoucher = false
    @State private var selectedStoreFilter: String?
    @State private var showExpiredVouchers = true
    
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
                return expiration >= Date()
            }
        }
        
        return result
    }
    
    var uniqueStores: [String] {
        Array(Set(vouchers.map { $0.storeName })).sorted()
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if vouchers.isEmpty {
                    emptyStateView
                } else {
                    voucherListView
                }
            }
            .navigationTitle("Mes Bons")
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
        }
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
                    .foregroundStyle(.white)
                    .padding()
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top)
        }
        .padding()
    }
    
    private var voucherListView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(filteredVouchers) { voucher in
                    NavigationLink {
                        VoucherDetailView(voucher: voucher)
                    } label: {
                        VoucherCardView(voucher: voucher)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
    }
    
    private var filterMenu: some View {
        Group {
            // Filtre par enseigne
            Menu("Enseigne") {
                Button {
                    selectedStoreFilter = nil
                } label: {
                    Label("Toutes", systemImage: selectedStoreFilter == nil ? "checkmark" : "")
                }
                
                Divider()
                
                ForEach(uniqueStores, id: \.self) { store in
                    Button {
                        selectedStoreFilter = store
                    } label: {
                        Label(store, systemImage: selectedStoreFilter == store ? "checkmark" : "")
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
}
