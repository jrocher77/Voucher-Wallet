//
//  AddExpenseView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

struct AddExpenseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    let voucher: Voucher
    var existingExpense: Expense? // Pour l'édition - pas @State !
    
    @State private var amount: String
    @State private var note: String
    @State private var date: Date
    @State private var showingError = false
    @State private var errorMessage = ""
    
    private var isEditing: Bool {
        existingExpense != nil
    }
    
    init(voucher: Voucher, expense: Expense? = nil) {
        self.voucher = voucher
        self.existingExpense = expense
        
        // Debug
        if let expense = expense {
            print("📝 AddExpenseView init en mode ÉDITION")
            print("   • ID de la dépense: \(expense.id)")
            print("   • Montant actuel: \(expense.amount)")
            print("   • Date actuelle: \(expense.date)")
            print("   • Note actuelle: \(expense.note ?? "nil")")
        } else {
            print("➕ AddExpenseView init en mode CRÉATION")
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
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Solde restant")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(voucher.remainingBalance.formattedEuro)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(voucher.remainingBalance > 0 ? .primary : .red)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    
                    if let initial = voucher.amount {
                        HStack {
                            Text("Montant initial")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(initial.formattedEuro)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    Text("Solde")
                }
                
                Section {
                    HStack(spacing: 12) {
                        Text("€")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("0,00", text: $amount)
                            .font(.subheadline)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                        .environment(\.dynamicTypeSize, .small)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    
                    TextField("Note (optionnel)", text: $note, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(2...4)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                } header: {
                    Text("Dépense")
                }
                
                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            deleteExpense()
                        } label: {
                            HStack {
                                Spacer()
                                Label("Supprimer cette dépense", systemImage: "trash")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .environment(\.dynamicTypeSize, .medium)
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
        }
    }
    
    private var isFormValid: Bool {
        guard let expenseAmount = Double(amount.replacingOccurrences(of: ",", with: ".")),
              expenseAmount > 0 else {
            return false
        }
        return true
    }
    
    private func saveExpense() {
        guard let expenseAmount = Double(amount.replacingOccurrences(of: ",", with: ".")) else {
            errorMessage = "Montant invalide"
            showingError = true
            return
        }
        
        // Vérifier qu'on ne dépasse pas le solde (sauf si on édite et qu'on réduit le montant)
        let currentExpenseAmount = existingExpense?.amount ?? 0
        let adjustedBalance = voucher.remainingBalance + currentExpenseAmount
        
        if expenseAmount > adjustedBalance {
            errorMessage = "Le montant dépasse le solde restant (\(adjustedBalance.formattedEuro))"
            showingError = true
            return
        }
        
        if let existing = existingExpense {
            // Édition
            print("🔄 Modification de la dépense existante (ID: \(existing.id))")
            existing.amount = expenseAmount
            existing.date = date
            existing.note = note.isEmpty ? nil : note
            print("   ✓ Montant mis à jour: \(expenseAmount)")
            print("   ✓ Date mise à jour: \(date)")
            print("   ✓ Note mise à jour: \(note.isEmpty ? "nil" : note)")
        } else {
            // Création
            print("➕ Création d'une nouvelle dépense")
            let expense = Expense(
                amount: expenseAmount,
                date: date,
                note: note.isEmpty ? nil : note
            )
            expense.voucher = voucher
            modelContext.insert(expense)
            print("   ✓ Nouvelle dépense créée (ID: \(expense.id))")
        }
        
        do {
            try modelContext.save()
            print("💾 Dépense sauvegardée avec succès")
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
            print("❌ Erreur de sauvegarde: \(error)")
        }
    }
    
    private func deleteExpense() {
        guard let expense = existingExpense else { return }
        modelContext.delete(expense)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Erreur lors de la suppression : \(error.localizedDescription)"
            showingError = true
        }
    }
}

#Preview {
    AddExpenseView(voucher: Voucher(
        storeName: "Carrefour",
        amount: 50.0,
        voucherNumber: "1234567890123",
        codeType: .barcode,
        storeColor: "#0055A5"
    ))
    .modelContainer(for: Voucher.self, inMemory: true)
}
