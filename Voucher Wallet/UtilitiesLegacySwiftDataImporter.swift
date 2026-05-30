//
//  UtilitiesLegacySwiftDataImporter.swift
//  Voucher Wallet
//

import Foundation
import SwiftData

/// Lecture ponctuelle de la version SwiftData utilisée avant le partage CloudKit.
enum LegacySwiftDataImporter {
    @Model
    final class Voucher {
        var id: UUID = UUID()
        var storeName: String = ""
        var amount: Double?
        var voucherNumber: String = ""
        var pinCode: String?
        var codeType: CodeType = CodeType.barcode
        @Attribute(.externalStorage) var codeImageData: Data?
        var expirationDate: Date?
        var dateAdded: Date = Date()
        var sortOrder: Int = 0
        @Attribute(.externalStorage) var pdfData: Data?
        var storeColor: String = "#007AFF"
        var textColor: String = "#FFFFFF"
        @Relationship(deleteRule: .cascade, inverse: \Expense.voucher)
        var expenses: [Expense]?
        var isFavorite: Bool = false

        init() {}
    }

    @Model
    final class Expense {
        var id: UUID = UUID()
        var amount: Double = 0
        var date: Date = Date()
        var note: String?
        var voucher: Voucher?

        init() {}
    }

    static func read(from url: URL) throws -> [LegacyVoucherSnapshot] {
        let schema = Schema([Voucher.self, Expense.self])
        let configuration = ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
        return try read(schema: schema, configuration: configuration)
    }

    static func readFromAppGroup(identifier: String) throws -> [LegacyVoucherSnapshot] {
        let schema = Schema([Voucher.self, Expense.self])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            groupContainer: .identifier(identifier),
            cloudKitDatabase: .none
        )
        return try read(schema: schema, configuration: configuration)
    }

    private static func read(schema: Schema, configuration: ModelConfiguration) throws -> [LegacyVoucherSnapshot] {
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)
        return try context.fetch(FetchDescriptor<Voucher>()).map { voucher in
            LegacyVoucherSnapshot(
                id: voucher.id,
                storeName: voucher.storeName,
                amount: voucher.amount,
                voucherNumber: voucher.voucherNumber,
                pinCode: voucher.pinCode,
                codeType: voucher.codeType.rawValue,
                codeImageData: voucher.codeImageData,
                expirationDate: voucher.expirationDate,
                dateAdded: voucher.dateAdded,
                sortOrder: voucher.sortOrder,
                pdfData: voucher.pdfData,
                storeColor: voucher.storeColor,
                textColor: voucher.textColor,
                isFavorite: voucher.isFavorite,
                expenses: (voucher.expenses ?? []).map {
                    LegacyExpenseSnapshot(id: $0.id, amount: $0.amount, date: $0.date, note: $0.note)
                }
            )
        }
    }
}

struct LegacyExpenseSnapshot {
    let id: UUID
    let amount: Double
    let date: Date
    let note: String?
}

struct LegacyVoucherSnapshot {
    let id: UUID
    let storeName: String
    let amount: Double?
    let voucherNumber: String
    let pinCode: String?
    let codeType: String
    let codeImageData: Data?
    let expirationDate: Date?
    let dateAdded: Date
    let sortOrder: Int
    let pdfData: Data?
    let storeColor: String
    let textColor: String
    let isFavorite: Bool
    let expenses: [LegacyExpenseSnapshot]
}
