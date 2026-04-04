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
    
    func handleURL(_ url: URL) {
        print("🟡 URLHandler - Handling URL: \(url)")
        
        guard url.pathExtension.lowercased() == "pdf" else {
            print("❌ Not a PDF")
            return
        }
        
        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                print("✅ PDF read successfully: \(data.count) bytes")
                
                DispatchQueue.main.async {
                    self.pdfData = data
                    self.shouldShowImport = true
                    print("✅ URLHandler - Sheet should show now")
                }
            } else {
                // Try without security scoped
                let data = try Data(contentsOf: url)
                print("✅ PDF read (no security scope): \(data.count) bytes")
                
                DispatchQueue.main.async {
                    self.pdfData = data
                    self.shouldShowImport = true
                    print("✅ URLHandler - Sheet should show now")
                }
            }
        } catch {
            print("❌ Error reading PDF: \(error)")
        }
    }
}
