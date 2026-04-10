//
//  VoucherDuplicateDetector.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import Foundation

/// Utilitaire pour détecter les bons en double dans le wallet
struct VoucherDuplicateDetector {
    
    /// Vérifie si un numéro de bon existe déjà dans la collection
    /// - Parameters:
    ///   - voucherNumber: Numéro du bon à vérifier
    ///   - existingVouchers: Collection de bons existants
    /// - Returns: `true` si le numéro existe déjà
    static func isDuplicate(voucherNumber: String, in existingVouchers: [Voucher]) -> Bool {
        existingVouchers.contains { $0.voucherNumber == voucherNumber }
    }
    
    /// Identifie tous les bons en double dans une liste de bons détectés
    /// - Parameters:
    ///   - detectedVouchers: Liste des bons détectés
    ///   - existingVouchers: Collection de bons existants dans le wallet
    /// - Returns: Ensemble des IDs des bons qui sont déjà présents
    static func identifyDuplicates(
        in detectedVouchers: [PDFAnalyzer.DetectedVoucher],
        comparing existingVouchers: [Voucher]
    ) -> Set<UUID> {
        var duplicateIds: Set<UUID> = []
        
        for voucher in detectedVouchers {
            if isDuplicate(voucherNumber: voucher.voucherNumber, in: existingVouchers) {
                duplicateIds.insert(voucher.id)
            }
        }
        
        if !duplicateIds.isEmpty {
            print("⚠️ \(duplicateIds.count) bon(s) en double détecté(s)")
        }
        
        return duplicateIds
    }
    
}
