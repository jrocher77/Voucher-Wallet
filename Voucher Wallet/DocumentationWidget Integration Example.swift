//
//  Widget Integration Example.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//
//  Exemples d'intégration du rechargement de widgets
//  Ce fichier est un exemple - ne pas l'inclure dans le projet

/*

// EXEMPLE 1 : Dans VoucherDetailView, recharger les widgets quand on ajoute/retire des favoris

struct VoucherDetailView: View {
    @Bindable var voucher: Voucher
    
    var body: some View {
        VStack {
            // ... contenu de la vue
            
            Button {
                voucher.isFavorite.toggle()
                
                // Recharger les widgets après avoir modifié les favoris
                WidgetReloader.reloadFavoriteVouchersWidget()
            } label: {
                Label(
                    voucher.isFavorite ? "Retirer des favoris" : "Ajouter aux favoris",
                    systemImage: voucher.isFavorite ? "star.fill" : "star"
                )
            }
        }
        // Alternative : recharger automatiquement quand la vue disparaît
        .reloadWidgetsOnDisappear()
    }
}

// EXEMPLE 2 : Dans AddVoucherView, recharger après avoir ajouté un bon

struct AddVoucherView: View {
    @Environment(\.dismiss) var dismiss
    
    func saveVoucher() {
        // ... logique de sauvegarde
        
        // Recharger les widgets
        WidgetReloader.reloadAllWidgets()
        
        dismiss()
    }
}

// EXEMPLE 3 : Dans ContentView, surveiller les changements de favoris

struct ContentView: View {
    @Query private var vouchers: [Voucher]
    
    // Propriété calculée pour compter les favoris
    var favoriteCount: Int {
        vouchers.filter { $0.isFavorite }.count
    }
    
    var body: some View {
        NavigationStack {
            // ... contenu
        }
        // Recharger les widgets quand le nombre de favoris change
        .reloadWidgetsOnChange(of: favoriteCount)
    }
}

// EXEMPLE 4 : Dans AddExpenseView, recharger après avoir ajouté une dépense
// (car cela change le solde restant affiché dans le widget)

struct AddExpenseView: View {
    @Bindable var voucher: Voucher
    @Environment(\.dismiss) var dismiss
    
    func saveExpense() {
        // ... logique de sauvegarde de la dépense
        
        // Recharger les widgets car le solde a changé
        WidgetReloader.reloadFavoriteVouchersWidget()
        
        dismiss()
    }
}

*/
