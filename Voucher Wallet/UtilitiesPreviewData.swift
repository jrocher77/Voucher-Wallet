//
//  PreviewData.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import CoreData

@MainActor
class PreviewData {
    static let shared = PreviewData()
    
    let persistence: SharedModelContainer
    var container: NSPersistentCloudKitContainer { persistence.container }
    
    init() {
        do {
            persistence = try SharedModelContainer(inMemory: true, enablesCloudSync: false)
            // Ajouter des données de test
            addSampleData()
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
    
    private func addSampleData() {
        let context = container.viewContext
        
        // Carrefour
        let carrefourCode = BarcodeGenerator.generateBarcode(from: "1234567890123")
        _ = Voucher(
            context: context,
            storeName: "Carrefour",
            amount: 50.0,
            voucherNumber: "1234567890123",
            pinCode: "5678",
            codeType: .barcode,
            codeImageData: carrefourCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
            storeColor: StorePreset.getColor(for: "Carrefour")
        )
        
        // Decathlon
        let decathlonCode = BarcodeGenerator.generateQRCode(from: "DEC2024987654")
        _ = Voucher(
            context: context,
            storeName: "Decathlon",
            amount: 100.0,
            voucherNumber: "DEC2024987654",
            codeType: .qrCode,
            codeImageData: decathlonCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: 90, to: Date()),
            storeColor: StorePreset.getColor(for: "Decathlon")
        )
        
        // Fnac
        let fnacCode = BarcodeGenerator.generateBarcode(from: "FNAC202400123")
        _ = Voucher(
            context: context,
            storeName: "Fnac",
            amount: 25.0,
            voucherNumber: "FNAC202400123",
            pinCode: "1234",
            codeType: .barcode,
            codeImageData: fnacCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()),
            storeColor: StorePreset.getColor(for: "Fnac")
        )
        
        // Amazon
        let amazonCode = BarcodeGenerator.generateBarcode(from: "AMZN123456789012")
        _ = Voucher(
            context: context,
            storeName: "Amazon",
            amount: 75.0,
            voucherNumber: "AMZN-1234-5678-9012",
            pinCode: "ABCD",
            codeType: .barcode,
            codeImageData: amazonCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            storeColor: StorePreset.getColor(for: "Amazon")
        )
        
        // Ikea (expiré)
        let ikeaCode = BarcodeGenerator.generateQRCode(from: "IKEA9876543210")
        _ = Voucher(
            context: context,
            storeName: "Ikea",
            amount: 30.0,
            voucherNumber: "IKEA9876543210",
            codeType: .qrCode,
            codeImageData: ikeaCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            storeColor: StorePreset.getColor(for: "Ikea")
        )
        
        try? context.save()
    }
}
