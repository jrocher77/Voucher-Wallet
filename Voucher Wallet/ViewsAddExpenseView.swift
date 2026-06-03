//
//  AddExpenseView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import CoreData

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(VoucherSharingManager.self) private var sharingManager
    @Environment(\.managedObjectContext) private var modelContext
    
    let voucher: Voucher
    var existingExpense: Expense? // Pour l'édition - pas @State !
    var onVoucherDeleted: (() -> Void)? // Callback pour informer la vue parente
    var onExpenseSaved: (() -> Void)?
    
    @State private var amount: String
    @State private var note: String
    @State private var date: Date
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingDeleteVoucherAlert = false
    @State private var showingIdentityPrompt = false
    @State private var pendingExpenseSave = false
    @State private var displayName = ""
    @State private var isDeletingVoucher = false
    
    private var isEditing: Bool {
        existingExpense != nil
    }
    
    init(
        voucher: Voucher,
        expense: Expense? = nil,
        onVoucherDeleted: (() -> Void)? = nil,
        onExpenseSaved: (() -> Void)? = nil
    ) {
        self.voucher = voucher
        self.existingExpense = expense
        self.onVoucherDeleted = onVoucherDeleted
        self.onExpenseSaved = onExpenseSaved
        
        // Debug
        if let expense = expense {
            debugLog("📝 AddExpenseView init en mode ÉDITION")
            debugLog("   • ID de la dépense: \(expense.id)")
            debugLog("   • Montant actuel: \(expense.amount)")
            debugLog("   • Date actuelle: \(expense.date)")
            debugLog("   • Note actuelle: \(expense.note ?? "nil")")
        } else {
            debugLog("➕ AddExpenseView init en mode CRÉATION")
        }
        
        // Formater avec une virgule pour le format français
        if let expense = expense {
            let formattedAmount = String(format: "%.2f", expense.amount).replacingOccurrences(of: ".", with: ",")
            _amount = State(initialValue: formattedAmount)
        } else {
            _amount = State(initialValue: "")
        }
        
        _note = State(initialValue: expense?.note ?? "")
        _date = State(initialValue: expense?.date ?? Date())
    }
    
    var body: some View {
        if isDeletingVoucher {
            Color.clear
        } else {
            NavigationStack {
            Form {
                Section {
                    LabeledContent("Solde restant") {
                        Text(voucher.remainingBalance.formattedEuro)
                            .fontWeight(.semibold)
                            .foregroundColor(voucher.remainingBalance > 0 ? .primary : .red)
                    }
                    
                    if let initial = voucher.amount {
                        LabeledContent("Montant initial") {
                            Text(initial.formattedEuro)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Solde")
                }
                
                Section {
                    LabeledContent("Montant") {
                        HStack(spacing: 6) {
                            Text("€")
                                .foregroundStyle(.secondary)
                            TextField("0,00", text: $amount)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .font(.title3.weight(.semibold))
                                .monospacedDigit()
                                .frame(minWidth: 90)
                        }
                    }
                    
                    if shouldShowAmountValidation && !amount.isEmpty && parsedAmount == nil {
                        Label("Saisissez un montant valide (ex: 12,50)", systemImage: "exclamationmark.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if shouldShowAmountValidation,
                              let parsedAmount,
                              parsedAmount.currencyCents > adjustedBalance.currencyCents {
                        Label("Le montant dépasse le solde disponible", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .tint(.blue)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                    
                    TextField("Note (optionnel)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .textInputAutocapitalization(.sentences)
                } header: {
                    Text("Dépense")
                } footer: {
                    Text(isEditing ? "Le montant est déduit immédiatement du solde du bon. Saisissez 0 € pour neutraliser une dépense entrée par erreur." : "Le montant est déduit immédiatement du solde du bon.")
                }
            }
            .navigationTitle(isEditing ? "Modifier la dépense" : "Nouvelle dépense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Enregistrer" : "Ajouter") {
                        saveExpense()
                    }
                    .disabled(!isFormValid)
                }
            }
            .alert("Erreur", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("Solde épuisé", isPresented: $showingDeleteVoucherAlert) {
                Button("Annuler", role: .cancel) {
                    dismiss()
                }
                Button("Supprimer le bon", role: .destructive) {
                    deleteVoucher()
                }
            } message: {
                Text("Le solde de ce bon est maintenant à 0 €. Voulez-vous supprimer le bon ?")
            }
            .alert("Votre nom d'affichage", isPresented: $showingIdentityPrompt) {
                TextField("Prénom Nom", text: $displayName)
                Button("Annuler", role: .cancel) {
                    pendingExpenseSave = false
                }
                Button("Continuer") {
                    sharingManager.saveDisplayName(displayName)
                    if pendingExpenseSave {
                        pendingExpenseSave = false
                        saveExpense()
                    }
                }
                .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("Votre nom sera affiché avec les dépenses de ce bon partagé.")
            }
        }
        }
    }
    
    private var parsedAmount: Double? {
        Double(amount.replacingOccurrences(of: ",", with: "."))
    }
    
    private var adjustedBalance: Double {
        (voucher.remainingBalance + (existingExpense?.amount ?? 0)).roundedToCurrencyCents
    }

    private var shouldShowAmountValidation: Bool {
        !showingDeleteVoucherAlert
    }
    
    private var isFormValid: Bool {
        guard let expenseAmount = parsedAmount else {
            return false
        }
        guard isEditing ? expenseAmount >= 0 : expenseAmount > 0 else { return false }
        
        return expenseAmount.currencyCents <= adjustedBalance.currencyCents
    }
    
    private func saveExpense() {
        if voucher.isInActiveShare && sharingManager.storedDisplayName.isEmpty {
            displayName = ""
            pendingExpenseSave = true
            showingIdentityPrompt = true
            return
        }
        guard let expenseAmount = parsedAmount else {
            errorMessage = "Montant invalide"
            showingError = true
            return
        }
        guard isEditing ? expenseAmount >= 0 : expenseAmount > 0 else {
            errorMessage = isEditing ? "Le montant doit être positif ou égal à 0" : "Le montant doit être supérieur à 0"
            showingError = true
            return
        }
        
        // Vérifier qu'on ne dépasse pas le solde (sauf si on édite et qu'on réduit le montant)
        if expenseAmount.currencyCents > adjustedBalance.currencyCents {
            errorMessage = "Le montant dépasse le solde restant (\(adjustedBalance.formattedEuro))"
            showingError = true
            return
        }
        
        let savedExpense: Expense
        if let existing = existingExpense {
            // Édition
            debugLog("🔄 Modification de la dépense existante (ID: \(existing.id))")
            existing.amount = expenseAmount
            existing.date = date
            existing.note = note.isEmpty ? nil : note
            savedExpense = existing
            debugLog("   ✓ Montant mis à jour: \(expenseAmount)")
            debugLog("   ✓ Date mise à jour: \(date)")
            debugLog("   ✓ Note mise à jour: \(note.isEmpty ? "nil" : note)")
        } else {
            // Création
            debugLog("➕ Création d'une nouvelle dépense")
            let expense = Expense(
                context: modelContext,
                amount: expenseAmount,
                date: date,
                note: note.isEmpty ? nil : note
            )
            if voucher.isInActiveShare {
                expense.authorDisplayName = sharingManager.storedDisplayName
                expense.authorRecordName = sharingManager.authorIdentifier
                expense.sharingPeriodID = voucher.activeSharingPeriodID
            }
            SharedModelContainer.assign(expense, toStoreOf: voucher)
            expense.voucher = voucher
            savedExpense = expense
            debugLog("   ✓ Nouvelle dépense créée (ID: \(expense.id))")
        }
        
        do {
            try modelContext.save()
            debugLog("💾 Dépense sauvegardée avec succès")
            modelContext.refresh(voucher, mergeChanges: true)
            if voucher.isInActiveShare {
                sharingManager.mirrorSharedExpense(savedExpense, for: voucher)
            }
            NotificationCenter.default.post(name: .voucherDidChange, object: voucher.id)
            NotificationCenter.default.post(name: .voucherExpensesDidChange, object: voucher.id)
            onExpenseSaved?()
            reloadFavoriteWidgetIfNeeded()
            
            // Vérifier si le solde est maintenant à 0
            if voucher.remainingBalance == 0 && !voucher.isReceivedShare {
                debugLog("⚠️ Le solde du bon est maintenant à 0")
                showingDeleteVoucherAlert = true
            } else {
                dismiss()
            }
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
            debugLog("❌ Erreur de sauvegarde: \(error)")
        }
    }
    
    private func deleteVoucher() {
        let objectID = voucher.objectID
        let voucherID = voucher.id
        let wasFavorite = voucher.isFavorite
        isDeletingVoucher = true
        showingDeleteVoucherAlert = false

        // Marquer que le bon va être supprimé AVANT de le supprimer.
        onVoucherDeleted?()
        dismiss()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard let voucherToDelete = try? modelContext.existingObject(with: objectID) as? Voucher else { return }
            sharingManager.revokeIfNeeded(for: voucherToDelete)
            voucherToDelete.deletePersonalPreference(in: modelContext)
            modelContext.delete(voucherToDelete)

            do {
                try modelContext.save()
                debugLog("🗑️ Bon supprimé avec succès")
                NotificationCenter.default.post(name: .voucherDidChange, object: voucherID)
                if wasFavorite {
                    WidgetReloader.reloadFavoriteVouchersWidget()
                }
            } catch {
                errorMessage = "Erreur lors de la suppression du bon : \(error.localizedDescription)"
                showingError = true
                isDeletingVoucher = false
                debugLog("❌ Erreur de suppression du bon: \(error)")
            }
        }
    }
    
    private func reloadFavoriteWidgetIfNeeded() {
        guard voucher.isFavorite else { return }
        WidgetReloader.reloadFavoriteVouchersWidget()
    }
}

#Preview {
    AddExpenseView(voucher: Voucher(
        context: PreviewData.shared.container.viewContext,
        storeName: "Carrefour",
        amount: 50.0,
        voucherNumber: "1234567890123",
        codeType: .barcode,
        storeColor: "#0055A5"
    ))
    .environment(\.managedObjectContext, PreviewData.shared.container.viewContext)
    .environment(VoucherSharingManager(persistence: PreviewData.shared.persistence))
}
