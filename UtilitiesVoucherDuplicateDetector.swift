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
    
    /// Filtre une liste de bons pour ne garder que ceux qui ne sont pas en double
    /// - Parameters:
    ///   - detectedVouchers: Liste des bons détectés
    ///   - existingVouchers: Collection de bons existants dans le wallet
    /// - Returns: Liste des bons non-dupliqués
    static func filterDuplicates(
        from detectedVouchers: [PDFAnalyzer.DetectedVoucher],
        comparing existingVouchers: [Voucher]
    ) -> [PDFAnalyzer.DetectedVoucher] {
        detectedVouchers.filter { voucher in
            !isDuplicate(voucherNumber: voucher.voucherNumber, in: existingVouchers)
        }
    }
}
