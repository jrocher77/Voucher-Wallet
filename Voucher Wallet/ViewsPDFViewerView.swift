//
//  PDFViewerView.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import SwiftUI
import PDFKit

/// Vue pour afficher un PDF en plein écran
struct PDFViewerView: View {
    let pdfData: Data
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            PDFKitView(data: pdfData)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("PDF Original")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                    
                    ToolbarItem(placement: .topBarLeading) {
                        ShareLink(item: PDFDocument(data: pdfData) ?? PDFDocument(), preview: SharePreview("Bon d'achat")) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
        }
    }
}

/// Wrapper UIViewRepresentable pour PDFView
struct PDFKitView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        
        if let document = PDFDocument(data: data) {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        // Pas de mise à jour nécessaire
    }
}

#Preview {
    // Preview avec un PDF vide
    PDFViewerView(pdfData: Data())
}
