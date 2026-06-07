//
//  URLHandler.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum VoucherImportSource: Equatable {
    case pdf(data: Data)
    case image(data: Data)

    var data: Data {
        switch self {
        case .pdf(let data):
            return data
        case .image(let data):
            return data
        }
    }

    var pdfData: Data? {
        if case .pdf(let data) = self { return data }
        return nil
    }

    var imageData: Data? {
        if case .image(let data) = self { return data }
        return nil
    }

    var isPDF: Bool {
        if case .pdf = self { return true }
        return false
    }

    var successTitle: String {
        isPDF ? "PDF analysé avec succès" : "Image analysée avec succès"
    }

    var retryTitle: String {
        isPDF ? "Analyser un autre PDF" : "Analyser un autre document"
    }
}

@Observable
class URLHandler {
    var incomingPDFURL: URL?
    var incomingImportSource: VoucherImportSource?
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
        
        // Sinon, vérifier si c'est un document importable
        guard let source = VoucherImportSecurity.importSource(for: url) else {
            debugLog("❌ Not an importable document or valid deep link")
            return
        }
        
        handleImportURL(url, source: source)
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
    
    private func handleImportURL(_ url: URL, source: VoucherImportSource.Kind) {
        do {
            let importSource = try VoucherImportSecurity.readImportSource(from: url, kind: source)
            debugLog("✅ Document read successfully: \(importSource.data.count) bytes")

            DispatchQueue.main.async {
                self.incomingImportSource = importSource
                self.shouldShowImport = true
                debugLog("✅ URLHandler - Sheet should show now")
            }
        } catch {
            debugLog("❌ Error reading import document: \(error)")
        }
    }
}

extension VoucherImportSource {
    enum Kind {
        case pdf
        case image
    }
}

enum VoucherImportSecurity {
    static let maxPDFByteCount = 25 * 1024 * 1024
    static let maxImageByteCount = 25 * 1024 * 1024

    static func importSource(for url: URL) -> VoucherImportSource.Kind? {
        switch url.pathExtension.lowercased() {
        case "pdf":
            return .pdf
        case "jpg", "jpeg", "png", "heic", "heif", "webp", "tiff", "tif":
            return .image
        default:
            let contentType = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType
            if contentType?.conforms(to: .pdf) == true {
                return .pdf
            }
            if contentType?.conforms(to: .image) == true {
                return .image
            }
            return nil
        }
    }

    static func readImportSource(from url: URL, kind: VoucherImportSource.Kind? = nil) throws -> VoucherImportSource {
        let resolvedKind = kind ?? importSource(for: url)
        guard let resolvedKind else {
            throw VoucherImportSecurityError.unsupportedFile
        }

        let maxBytes = maxByteCount(for: resolvedKind)
        let data = try readData(from: url, maxBytes: maxBytes)

        switch resolvedKind {
        case .pdf:
            return .pdf(data: data)
        case .image:
            guard UIImage(data: data) != nil else {
                throw VoucherImportSecurityError.invalidImage
            }
            return .image(data: data)
        }
    }

    static func readPDFData(from url: URL) throws -> Data {
        guard case .pdf(let data) = try readImportSource(from: url, kind: .pdf) else {
            throw VoucherImportSecurityError.unsupportedFile
        }
        return data
    }

    private static func readData(from url: URL, maxBytes: Int) throws -> Data {
        let didStartSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if didStartSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard didStartSecurityScope || FileManager.default.isReadableFile(atPath: url.path) else {
            throw CocoaError(.fileReadNoPermission)
        }

        try validateFileSize(at: url, maxBytes: maxBytes)
        let data = try Data(contentsOf: url)
        guard data.count <= maxBytes else {
            throw VoucherImportSecurityError.fileTooLarge(maxBytes: maxBytes)
        }
        return data
    }

    private static func maxByteCount(for kind: VoucherImportSource.Kind) -> Int {
        switch kind {
        case .pdf:
            return maxPDFByteCount
        case .image:
            return maxImageByteCount
        }
    }

    private static func validateFileSize(at url: URL, maxBytes: Int) throws {
        let values = try? url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values?.fileSize else { return }
        if fileSize > maxBytes {
            throw VoucherImportSecurityError.fileTooLarge(maxBytes: maxBytes)
        }
    }
}

typealias PDFImportSecurity = VoucherImportSecurity

enum VoucherImportSecurityError: LocalizedError {
    case fileTooLarge(maxBytes: Int)
    case invalidImage
    case unsupportedFile

    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let maxBytes):
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB]
            formatter.countStyle = .file
            return "Le document est trop volumineux. La taille maximale est de \(formatter.string(fromByteCount: Int64(maxBytes)))."
        case .invalidImage:
            return "L'image sélectionnée ne peut pas être lue."
        case .unsupportedFile:
            return "Ce type de document n'est pas pris en charge."
        }
    }
}
