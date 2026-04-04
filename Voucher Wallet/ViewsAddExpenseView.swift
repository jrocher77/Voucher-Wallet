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
    let existingExpense: Expense? // Pour l'édition
    
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
        
        _amount = State(initialValue: expense != nil ? String(format: "%.2f", expense!.amount) : "")
        _note = State(initialValue: expense?.note ?? "")
        _date = State(initialValue: expense?.date ?? Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text("Solde restant")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(voucher.remainingBalance, format: .currency(code: "EUR"))
                            .fontWeight(.semibold)
                            .foregroundStyle(voucher.remainingBalance > 0 ? .primary : .red)
                    }
                    
                    if let initial = voucher.amount {
                        HStack {
                            Text("Montant initial")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(initial, format: .currency(code: "EUR"))
                                .foregroundStyle(.secondary)
                        }
                        .font(.caption)
                    }
                } header: {
                    Text("Solde")
                }
                
                Section {
                    HStack {
                        Text("€")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        TextField("Montant", text: $amount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    DatePicker("Date", selection: $date, displayedComponents: [.date])
                    
                    TextField("Note (optionnel)", text: $note, axis: .vertical)
                        .lineLimit(2...4)
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
            errorMessage = "Le montant dépasse le solde restant (\(adjustedBalance.formatted(.currency(code: "EUR"))))"
            showingError = true
            return
        }
        
        if let existing = existingExpense {
            // Édition
            existing.amount = expenseAmount
            existing.date = date
            existing.note = note.isEmpty ? nil : note
        } else {
            // Création
            let expense = Expense(
                amount: expenseAmount,
                date: date,
                note: note.isEmpty ? nil : note,
                voucher: voucher
            )
            modelContext.insert(expense)
            voucher.expenses.append(expense)
        }
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = "Erreur lors de l'enregistrement : \(error.localizedDescription)"
            showingError = true
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
