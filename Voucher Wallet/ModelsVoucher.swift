//
//  Voucher.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import SwiftData

@Model
final class Voucher {
    var id: UUID
    var storeName: String
    var amount: Double?
    var voucherNumber: String
    var pinCode: String?
    var codeType: CodeType
    var codeImageData: Data?
    var expirationDate: Date?
    var dateAdded: Date
    var pdfData: Data?
    var storeColor: String // Hex color code
    
    init(
        id: UUID = UUID(),
        storeName: String,
        amount: Double? = nil,
        voucherNumber: String,
        pinCode: String? = nil,
        codeType: CodeType,
        codeImageData: Data? = nil,
        expirationDate: Date? = nil,
        dateAdded: Date = Date(),
        pdfData: Data? = nil,
        storeColor: String = "#007AFF"
    ) {
        self.id = id
        self.storeName = storeName
        self.amount = amount
        self.voucherNumber = voucherNumber
        self.pinCode = pinCode
        self.codeType = codeType
        self.codeImageData = codeImageData
        self.expirationDate = expirationDate
        self.dateAdded = dateAdded
        self.pdfData = pdfData
        self.storeColor = storeColor
    }
}

enum CodeType: String, Codable {
    case barcode
    case qrCode
}
