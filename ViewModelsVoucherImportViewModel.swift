//
//  VoucherImportViewModel.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI
import SwiftData

/// ViewModel centralisé pour gérer l'import de bons depuis PDF
@Observable
class VoucherImportViewModel {
    
    // MARK: - State
    
    /// Résultat de l'analyse PDF
    var analysisResult: PDFAnalyzer.AnalysisResult?
    
    /// Bons détectés dans le PDF
    var detectedVouchers: [PDFAnalyzer.DetectedVoucher] = []
    
    /// IDs des bons sélectionnés pour l'import
    var selectedVoucherIds: Set<UUID> = []
    
    /// IDs des bons déjà présents dans le wallet (doublons)
    var duplicateVoucherIds: Set<UUID> = []
    
    /// État de l'analyse
    var isAnalyzing = false
    
    /// Message de progression
    var progressMessage = "Chargement du PDF..."
    
    /// Valeur de progression (0.0 à 1.0)
    var progressValue: Double = 0.0
    
    /// Nombre total de pages
    var totalPages: Int = 1
    
    /// Couleur globale pour les cartes (import multiple)
    var globalCardColor = Color(hex: "#007AFF")
    
    /// Couleur globale pour le texte (import multiple)
    var globalTextColor = Color(hex: "#FFFFFF")
    
    /// Message d'erreur
    var errorMessage = ""
    
    /// Indique si une erreur doit être affichée
    var showingError = false
    
    // MARK: - Computed Properties
    
    /// Indique s'il y a plusieurs bons détectés
    var hasMultipleVouchers: Bool {
        detectedVouchers.count > 1
    }
    
    /// Nombre de bons sélectionnés
    var selectedCount: Int {
        selectedVoucherIds.count
    }
    
    /// Nombre de bons non-dupliqués disponibles
    var availableVouchersCount: Int {
        detectedVouchers.filter { !duplicateVoucherIds.contains($0.id) }.count
    }
    
    // MARK: - PDF Analysis
    
    /// Analyse un PDF et détecte les bons
    /// - Parameter pdfData: Données du PDF à analyser
    func analyzePDF(data pdfData: Data) async {
        isAnalyzing = true
        
        do {
            print("🔍 Début de l'analyse PDF...")
            
            let result = try await PDFAnalyzer.analyzePDF(data: pdfData) { progress in
                Task { @MainActor in
                    self.progressMessage = progress.userMessage
                    self.progressValue = progress.progress(totalPages: self.totalPages)
                    
                    if case .analyzingPage(_, let total) = progress {
                        self.totalPages = total
                    }
                }
            }
            
            await MainActor.run {
                self.analysisResult = result
                self.detectedVouchers = result.detectedVouchers
                
                print("📊 Analyse terminée:")
                print("  - Bons détectés: \(result.detectedVouchers.count)")
                print("  - Enseigne: \(result.detectedStoreName ?? "non détectée")")
                
                self.isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                print("❌ Erreur d'analyse: \(error.localizedDescription)")
                self.errorMessage = "Erreur lors de l'analyse : \(error.localizedDescription)"
                self.showingError = true
                self.isAnalyzing = false
            }
        }
    }
    
    // MARK: - Duplicate Detection
    
    /// Identifie les doublons parmi les bons détectés
    /// - Parameter existingVouchers: Bons déjà présents dans le wallet
    func identifyDuplicates(comparing existingVouchers: [Voucher]) {
        duplicateVoucherIds = VoucherDuplicateDetector.identifyDuplicates(
            in: detectedVouchers,
            comparing: existingVouchers
        )
    }
    
    // MARK: - Selection Management
    
    /// Bascule la sélection d'un bon
    /// - Parameter id: ID du bon
    func toggleSelection(_ id: UUID) {
        // Ne pas permettre la sélection des doublons
        guard !duplicateVoucherIds.contains(id) else { return }
        
        if selectedVoucherIds.contains(id) {
            selectedVoucherIds.remove(id)
        } else {
            selectedVoucherIds.insert(id)
        }
    }
    
    /// Sélectionne tous les bons non-dupliqués
    func selectAll() {
        selectedVoucherIds = Set(
            detectedVouchers
                .filter { !duplicateVoucherIds.contains($0.id) }
                .map { $0.id }
        )
    }
    
    /// Désélectionne tous les bons
    func deselectAll() {
        selectedVoucherIds.removeAll()
    }
    
    /// Vérifie si tous les bons disponibles sont sélectionnés
    var allSelected: Bool {
        selectedVoucherIds.count == availableVouchersCount
    }
    
    // MARK: - Color Management
    
    /// Initialise les couleurs globales en fonction du premier bon détecté
    func initializeGlobalColors() {
        guard let firstVoucher = detectedVouchers.first else { return }
        
        // Utiliser la couleur du bon détecté ou celle du preset
        if let hexColor = firstVoucher.storeColor {
            globalCardColor = Color(hex: hexColor)
        } else if let storeName = firstVoucher.storeName {
            globalCardColor = Color(hex: StorePreset.getColor(for: storeName))
        }
        
        // Suggérer automatiquement la couleur de texte (avec exceptions par enseigne)
        let suggestedTextColor: String
        if let storeName = firstVoucher.storeName {
            suggestedTextColor = StorePreset.getTextColor(for: storeName, backgroundHex: globalCardColor.toHex())
        } else {
            suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: globalCardColor.toHex())
        }
        globalTextColor = Color(hex: suggestedTextColor)
        
        print("🎨 Couleurs initialisées: fond=\(globalCardColor.toHex()), texte=\(globalTextColor.toHex())")
    }
    
    /// Ajuste automatiquement la couleur de texte si nécessaire
    /// - Parameter backgroundColor: Couleur de fond
    func autoAdjustTextColor(for backgroundColor: Color) {
        if ColorContrastHelper.areColorsTooSimilar(backgroundColor, globalTextColor) {
            let suggestedTextColor = StoreNameLearning.shared.suggestTextColor(for: backgroundColor.toHex())
            globalTextColor = Color(hex: suggestedTextColor)
        }
    }
    
    // MARK: - Import
    
    /// Importe les bons sélectionnés dans le contexte SwiftData
    /// - Parameters:
    ///   - modelContext: Contexte SwiftData
    ///   - pdfData: Données PDF originales
    /// - Returns: Nombre de bons importés avec succès
    @discardableResult
    func importSelectedVouchers(
        to modelContext: ModelContext,
        pdfData: Data
    ) throws -> Int {
        let selectedVouchers = detectedVouchers.filter { selectedVoucherIds.contains($0.id) }
        
        let colorHex = globalCardColor.toHex()
        let textColorHex = globalTextColor.toHex()
        
        var importedCount = 0
        
        for detectedVoucher in selectedVouchers {
            // Générer le code-barres/QR code
            let codeImage: UIImage?
            if detectedVoucher.codeType == .qrCode {
                codeImage = BarcodeGenerator.generateQRCode(from: detectedVoucher.voucherNumber)
            } else {
                codeImage = BarcodeGenerator.generateBarcode(from: detectedVoucher.voucherNumber)
            }
            
            let voucher = Voucher(
                storeName: detectedVoucher.storeName ?? "Enseigne inconnue",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
                expirationDate: detectedVoucher.expirationDate,
                pdfData: pdfData,
                storeColor: colorHex,
                textColor: textColorHex
            )
            
            modelContext.insert(voucher)
            
            // Apprentissage automatique
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
                StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
                StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
            }
            
            importedCount += 1
        }
        
        try modelContext.save()
        print("✅ \(importedCount) bon(s) importé(s)")
        
        return importedCount
    }
    
    /// Importe un seul bon avec des paramètres personnalisés
    /// - Parameters:
    ///   - storeName: Nom de l'enseigne
    ///   - amount: Montant (optionnel)
    ///   - voucherNumber: Numéro du bon
    ///   - pinCode: Code PIN (optionnel)
    ///   - codeType: Type de code (barcode/QR)
    ///   - expirationDate: Date d'expiration (optionnel)
    ///   - cardColor: Couleur de la carte
    ///   - textColor: Couleur du texte
    ///   - pdfData: Données PDF
    ///   - modelContext: Contexte SwiftData
    func importSingleVoucher(
        storeName: String,
        amount: Double?,
        voucherNumber: String,
        pinCode: String?,
        codeType: CodeType,
        expirationDate: Date?,
        cardColor: Color,
        textColor: Color,
        pdfData: Data,
        to modelContext: ModelContext
    ) throws {
        // Générer le code
        let codeImage: UIImage?
        if codeType == .qrCode {
            codeImage = BarcodeGenerator.generateQRCode(from: voucherNumber)
        } else {
            codeImage = BarcodeGenerator.generateBarcode(from: voucherNumber)
        }
        
        let colorHex = cardColor.toHex()
        let textColorHex = textColor.toHex()
        
        let voucher = Voucher(
            storeName: storeName,
            amount: amount,
            voucherNumber: voucherNumber,
            pinCode: pinCode,
            codeType: codeType,
            codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: expirationDate,
            pdfData: pdfData,
            storeColor: colorHex,
            textColor: textColorHex
        )
        
        modelContext.insert(voucher)
        
        // Apprentissage
        let detectedName = analysisResult?.detectedStoreName
        StoreNameLearning.shared.learnStoreName(storeName, detectedAs: detectedName)
        StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
        StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
        
        try modelContext.save()
        print("✅ Bon importé: \(storeName)")
    }
}
