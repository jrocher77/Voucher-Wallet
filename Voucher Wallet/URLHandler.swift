//
//  URLHandler.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import SwiftUI

@Observable
class URLHandler {
    var incomingPDFURL: URL?
    var pdfData: Data?
    var shouldShowImport = false
    var selectedVoucherID: UUID?
    
    func handleURL(_ url: URL) {
        print("🟡 URLHandler - Handling URL: \(url)")
        
        // Vérifier si c'est un deep link vers un voucher
        // Format: voucherwallet://voucher/{UUID}
        if url.scheme == "voucherwallet", url.host == "voucher" {
            handleVoucherDeepLink(url)
            return
        }
        
        // Sinon, vérifier si c'est un PDF
        guard url.pathExtension.lowercased() == "pdf" else {
            print("❌ Not a PDF or valid deep link")
            return
        }
        
        handlePDFURL(url)
    }
    
    private func handleVoucherDeepLink(_ url: URL) {
        let path = url.path
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard let uuidString = components.first,
              let voucherID = UUID(uuidString: uuidString) else {
            print("❌ Invalid voucher URL format")
            return
        }
        
        print("✅ Opening voucher with ID: \(voucherID)")
        
        DispatchQueue.main.async {
            self.selectedVoucherID = voucherID
        }
    }
    
    private func handlePDFURL(_ url: URL) {
        do {
            let data = try readPDFData(from: url)
            print("✅ PDF read successfully: \(data.count) bytes")

            DispatchQueue.main.async {
                self.pdfData = data
                self.shouldShowImport = true
                print("✅ URLHandler - Sheet should show now")
            }
        } catch {
            print("❌ Error reading PDF: \(error)")
        }
    }

    private func readPDFData(from url: URL) throws -> Data {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }
            return try Data(contentsOf: url)
        }

        guard FileManager.default.isReadableFile(atPath: url.path) else {
            throw CocoaError(.fileReadNoPermission)
        }

        return try Data(contentsOf: url)
    }
}
