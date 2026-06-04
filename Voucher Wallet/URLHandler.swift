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
        debugLog("🟡 URLHandler - Handling URL scheme: \(url.scheme ?? "scheme inconnu")")
        
        // Vérifier si c'est un deep link vers un voucher
        // Format: voucherwallet://voucher/{UUID}
        if url.scheme == "voucherwallet", url.host == "voucher" {
            handleVoucherDeepLink(url)
            return
        }
        
        // Sinon, vérifier si c'est un PDF
        guard url.pathExtension.lowercased() == "pdf" else {
            debugLog("❌ Not a PDF or valid deep link")
            return
        }
        
        handlePDFURL(url)
    }
    
    private func handleVoucherDeepLink(_ url: URL) {
        let path = url.path
        let components = path.components(separatedBy: "/").filter { !$0.isEmpty }
        
        guard let uuidString = components.first,
              let voucherID = UUID(uuidString: uuidString) else {
            debugLog("❌ Invalid voucher URL format")
            return
        }
        
        debugLog("✅ Deep link bon valide")
        
        DispatchQueue.main.async {
            self.selectedVoucherID = voucherID
        }
    }
    
    private func handlePDFURL(_ url: URL) {
        do {
            let data = try PDFImportSecurity.readPDFData(from: url)
            debugLog("✅ PDF read successfully: \(data.count) bytes")

            DispatchQueue.main.async {
                self.pdfData = data
                self.shouldShowImport = true
                debugLog("✅ URLHandler - Sheet should show now")
            }
        } catch {
            debugLog("❌ Error reading PDF: \(error)")
        }
    }
}

enum PDFImportSecurity {
    static let maxPDFByteCount = 25 * 1024 * 1024

    static func readPDFData(from url: URL) throws -> Data {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard didStartSecurityScope || FileManager.default.isReadableFile(atPath: url.path) else {
            throw CocoaError(.fileReadNoPermission)
        }

        try validateFileSize(at: url)
        let data = try Data(contentsOf: url)
        guard data.count <= maxPDFByteCount else {
            throw PDFImportSecurityError.fileTooLarge(maxBytes: maxPDFByteCount)
        }
        return data
    }

    private static func validateFileSize(at url: URL) throws {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values?.fileSize else { return }
        if fileSize > maxPDFByteCount {
            throw PDFImportSecurityError.fileTooLarge(maxBytes: maxPDFByteCount)
        }
    }
}

enum PDFImportSecurityError: LocalizedError {
    case fileTooLarge(maxBytes: Int)

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maxBytes):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB]
            formatter.countStyle = .file
            return "Le PDF est trop volumineux. La taille maximale est de \(formatter.string(fromByteCount: Int64(maxBytes)))."
        }
    }
}
