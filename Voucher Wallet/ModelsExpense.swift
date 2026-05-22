//
//  Expense.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import SwiftData

@Model
final class Expense {
    var id: UUID = UUID()
    var amount: Double = 0
    var date: Date = Date()
    var note: String?
    var voucher: Voucher?
    
    init(id: UUID = UUID(), amount: Double, date: Date = Date(), note: String? = nil) {
        self.id = id
        self.amount = amount
        self.date = date
        self.note = note
    }
}
