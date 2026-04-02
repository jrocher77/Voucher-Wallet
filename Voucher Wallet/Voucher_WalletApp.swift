//
//  Voucher_WalletApp.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import SwiftData

@main
struct Voucher_WalletApp: App {
    @State private var importedPDFData: Data?
    @State private var showingPDFImport = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .sheet(isPresented: $showingPDFImport) {
                    if let pdfData = importedPDFData {
                        PDFImportHandler(pdfData: pdfData)
                            .onDisappear {
                                importedPDFData = nil
                            }
                    }
                }
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
        .modelContainer(for: Voucher.self)
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Vérifier que c'est un PDF
        guard url.pathExtension.lowercased() == "pdf" else { return }
        
        do {
            // Accéder au fichier
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                let data = try Data(contentsOf: url)
                importedPDFData = data
                showingPDFImport = true
            }
        } catch {
            print("Erreur lors de l'import du PDF : \(error)")
        }
    }
}
