//
//  PDFAnalyzerExtensions.swift
//  Voucher Wallet
//
//  Created by JEREMY on 03/04/2026.
//

import Foundation

// MARK: - DetectedVoucher Extension pour la couleur

extension PDFAnalyzer.DetectedVoucher {
    /// Initialiser un DetectedVoucher avec une couleur personnalisée
    init(
        id: UUID = UUID(),
        pageNumber: Int,
        voucherNumber: String,
        codeType: CodeType,
        storeName: String? = nil,
        amount: Double? = nil,
        pinCode: String? = nil,
        expirationDate: Date? = nil,
        codeImageData: Data? = nil,
        storeNameConfidence: Double = 0.0,
        storeColor: String? = nil
    ) {
        self.init(
            id: id,
            pageNumber: pageNumber,
            voucherNumber: voucherNumber,
            codeType: codeType,
            storeName: storeName,
            amount: amount,
            pinCode: pinCode,
            expirationDate: expirationDate,
            codeImageData: codeImageData,
            storeNameConfidence: storeNameConfidence
        )
        
        // Si le type supporte déjà storeColor nativement, cette extension n'est pas nécessaire
        // Sinon, il faudra modifier directement le struct PDFAnalyzer.DetectedVoucher
    }
    
    /// Propriété calculée pour obtenir la couleur (si non définie dans le struct original)
    var storeColor: String? {
        get {
            // Cette propriété devrait être ajoutée directement au struct DetectedVoucher
            // dans le fichier PDFAnalyzer.swift
            return nil
        }
    }
}
