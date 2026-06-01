//
//  Formatters.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//

import Foundation

extension Date {
    /// Formate la date en français avec le format complet (ex: "3 avril 2026")
    var frenchLongFormat: String {
        self.formatted(
            .dateTime
                .day()
                .month(.wide)
                .year()
                .locale(Locale(identifier: "fr_FR"))
        )
    }
    
    /// Formate la date en français avec le format abrégé (ex: "3 avr. 2026")
    var frenchAbbreviatedFormat: String {
        self.formatted(
            .dateTime
                .day()
                .month(.abbreviated)
                .year()
                .locale(Locale(identifier: "fr_FR"))
        )
    }
    
    /// Formate la date en français avec le format court (ex: "03/04/2026")
    var frenchShortFormat: String {
        self.formatted(
            .dateTime
                .day()
                .month(.twoDigits)
                .year()
                .locale(Locale(identifier: "fr_FR"))
        )
    }
}

extension Double {
    var roundedToCurrencyCents: Double {
        let cents = currencyCents
        return cents == 0 ? 0 : Double(cents) / 100
    }

    var currencyCents: Int {
        Int((self * 100).rounded())
    }

    /// Formate le montant en euros avec le symbole après (ex: "50,00 €")
    var formattedEuro: String {
        let normalizedAmount = roundedToCurrencyCents
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = ","
        formatter.groupingSeparator = " "
        
        if let formatted = formatter.string(from: NSNumber(value: normalizedAmount)) {
            return "\(formatted) €"
        }
        return String(format: "%.2f €", normalizedAmount)
    }
}
