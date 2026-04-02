//
//  PreviewData.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import SwiftData

@MainActor
class PreviewData {
    static let shared = PreviewData()
    
    let container: ModelContainer
    
    init() {
        do {
            let schema = Schema([Voucher.self])
            let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
            container = try ModelContainer(for: schema, configurations: [configuration])
            
            // Ajouter des données de test
            addSampleData()
        } catch {
            fatalError("Failed to create preview container: \(error)")
        }
    }
    
    private func addSampleData() {
        let context = container.mainContext
        
        // Carrefour
        let carrefourCode = BarcodeGenerator.generateBarcode(from: "1234567890123")
        let carrefour = Voucher(
            storeName: "Carrefour",
            amount: 50.0,
            voucherNumber: "1234567890123",
            pinCode: "5678",
            codeType: .barcode,
            codeImageData: carrefourCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: 45, to: Date()),
            storeColor: StorePreset.getColor(for: "Carrefour")
        )
        context.insert(carrefour)
        
        // Decathlon
        let decathlonCode = BarcodeGenerator.generateQRCode(from: "DEC2024987654")
        let decathlon = Voucher(
            storeName: "Decathlon",
            amount: 100.0,
            voucherNumber: "DEC2024987654",
            codeType: .qrCode,
            codeImageData: decathlonCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: 90, to: Date()),
            storeColor: StorePreset.getColor(for: "Decathlon")
        )
        context.insert(decathlon)
        
        // Fnac
        let fnacCode = BarcodeGenerator.generateBarcode(from: "FNAC202400123")
        let fnac = Voucher(
            storeName: "Fnac",
            amount: 25.0,
            voucherNumber: "FNAC202400123",
            pinCode: "1234",
            codeType: .barcode,
            codeImageData: fnacCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: 15, to: Date()),
            storeColor: StorePreset.getColor(for: "Fnac")
        )
        context.insert(fnac)
        
        // Amazon
        let amazonCode = BarcodeGenerator.generateBarcode(from: "AMZN123456789012")
        let amazon = Voucher(
            storeName: "Amazon",
            amount: 75.0,
            voucherNumber: "AMZN-1234-5678-9012",
            pinCode: "ABCD",
            codeType: .barcode,
            codeImageData: amazonCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: Date()),
            storeColor: StorePreset.getColor(for: "Amazon")
        )
        context.insert(amazon)
        
        // Ikea (expiré)
        let ikeaCode = BarcodeGenerator.generateQRCode(from: "IKEA9876543210")
        let ikea = Voucher(
            storeName: "Ikea",
            amount: 30.0,
            voucherNumber: "IKEA9876543210",
            codeType: .qrCode,
            codeImageData: ikeaCode.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: Calendar.current.date(byAdding: .day, value: -5, to: Date()),
            storeColor: StorePreset.getColor(for: "Ikea")
        )
        context.insert(ikea)
        
        try? context.save()
    }
}
