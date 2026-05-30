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
    var allowsSharing: Bool = true
    var masksWhenCaptured: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var isScreenCaptured = false
    
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
                    
                    if allowsSharing {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                showingShareSheet = true
                            } label: {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingShareSheet) {
                    ShareSheetView(items: [pdfData])
                }
                .overlay {
                    if masksWhenCaptured && isScreenCaptured {
                        ContentUnavailableView(
                            "Contenu masqué",
                            systemImage: "eye.slash.fill",
                            description: Text("Le PDF est masqué pendant la recopie ou l'enregistrement de l'écran.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(.background)
                    }
                }
                .onAppear {
                    isScreenCaptured = UIScreen.main.isCaptured
                }
                .onReceive(NotificationCenter.default.publisher(for: UIScreen.capturedDidChangeNotification)) { _ in
                    isScreenCaptured = UIScreen.main.isCaptured
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
