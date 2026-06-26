//
//  VoucherImportViewModel.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//

import SwiftUI
import CoreData

/// ViewModel centralisé pour gérer l'import de bons depuis PDF ou image
@Observable
class VoucherImportViewModel {
    
    // MARK: - State
    
    /// Résultat de l'analyse du document
    var analysisResult: PDFAnalyzer.AnalysisResult?
    
    /// Bons détectés dans le document
    var detectedVouchers: [PDFAnalyzer.DetectedVoucher] = []
    
    /// IDs des bons sélectionnés pour l'import
    var selectedVoucherIds: Set<UUID> = []
    
    /// IDs des bons déjà présents dans le wallet (doublons)
    var duplicateVoucherIds: Set<UUID> = []
    
    /// État de l'analyse
    var isAnalyzing = false
    
    /// Message de progression
    var progressMessage = "Chargement du document..."
    
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
    
    // MARK: - Document Analysis

    /// Analyse une source d'import et détecte les bons
    /// - Parameter source: Source PDF ou image à analyser
    func analyzeImportSource(_ source: VoucherImportSource) async {
        switch source {
        case .pdf(let data):
            await analyzePDF(data: data)
        case .image(let data):
            await analyzeImage(data: data)
        }
    }

    /// Analyse un PDF et détecte les bons
    /// - Parameter pdfData: Données du PDF à analyser
    func analyzePDF(data pdfData: Data) async {
        isAnalyzing = true
        
        do {
            debugLog("🔍 Début de l'analyse PDF...")
            
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
                
                debugLog("📊 Analyse terminée:")
                debugLog("  - Bons détectés: \(result.detectedVouchers.count)")
                debugLog("  - Enseigne: \(result.detectedStoreName ?? "non détectée")")
                
                self.isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                debugLog("❌ Erreur d'analyse: \(error.localizedDescription)")
                self.errorMessage = "Erreur lors de l'analyse : \(error.localizedDescription)"
                self.showingError = true
                self.isAnalyzing = false
            }
        }
    }

    /// Analyse une image et détecte les bons
    /// - Parameter imageData: Données de l'image à analyser
    func analyzeImage(data imageData: Data) async {
        isAnalyzing = true
        totalPages = 1

        do {
            debugLog("🔍 Début de l'analyse image...")

            let result = try await PDFAnalyzer.analyzeImage(data: imageData) { progress in
                Task { @MainActor in
                    self.progressMessage = progress.userMessage
                    self.progressValue = progress.progress(totalPages: 1)
                }
            }

            await MainActor.run {
                self.analysisResult = result
                self.detectedVouchers = result.detectedVouchers

                debugLog("📊 Analyse image terminée:")
                debugLog("  - Bons détectés: \(result.detectedVouchers.count)")
                debugLog("  - Enseigne: \(result.detectedStoreName ?? "non détectée")")

                self.isAnalyzing = false
            }
        } catch {
            await MainActor.run {
                debugLog("❌ Erreur d'analyse image: \(error.localizedDescription)")
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
        
        debugLog("🎨 Couleurs initialisées: fond=\(globalCardColor.toHex()), texte=\(globalTextColor.toHex())")
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
    
    /// Importe les bons sélectionnés dans le contexte Core Data
    /// - Parameters:
    ///   - modelContext: Contexte Core Data
    ///   - importSource: Source originale importée
    /// - Returns: Nombre de bons importés avec succès
    @discardableResult
    func importSelectedVouchers(
        to modelContext: NSManagedObjectContext,
        importSource: VoucherImportSource
    ) throws -> [UUID] {
        let selectedVouchers = detectedVouchers.filter { selectedVoucherIds.contains($0.id) }
        
        let colorHex = globalCardColor.toHex()
        let textColorHex = globalTextColor.toHex()
        var nextSortOrder = getNextSortOrder(in: modelContext)
        
        var importedCount = 0
        var importedVoucherIDs: [UUID] = []
        
        for detectedVoucher in selectedVouchers {
            // Générer le code-barres/QR code
            let codeImage: UIImage?
            if detectedVoucher.codeType == .qrCode {
                codeImage = BarcodeGenerator.generateQRCode(from: detectedVoucher.voucherNumber)
            } else {
                codeImage = BarcodeGenerator.generateBarcode(from: detectedVoucher.voucherNumber)
            }
            
            let voucher = Voucher(
                context: modelContext,
                storeName: detectedVoucher.storeName ?? "Enseigne inconnue",
                amount: detectedVoucher.amount,
                voucherNumber: detectedVoucher.voucherNumber,
                pinCode: detectedVoucher.pinCode,
                codeType: detectedVoucher.codeType,
                codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
                expirationDate: detectedVoucher.expirationDate,
                sortOrder: nextSortOrder,
                pdfData: importSource.pdfData,
                imageData: importSource.imageData,
                storeColor: colorHex,
                textColor: textColorHex
            )
            SharedModelContainer.forgetDeletedLegacyVoucherForUserImport(voucher)
            if let voucherID = voucher.safeID {
                importedVoucherIDs.append(voucherID)
            }
            
            // Apprentissage automatique
            if let storeName = detectedVoucher.storeName {
                StoreNameLearning.shared.learnStoreName(storeName)
                StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
                StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
            }
            
            importedCount += 1
            nextSortOrder += 1
        }
        
        try modelContext.save()
        debugLog("✅ \(importedCount) bon(s) importé(s)")
        
        return importedVoucherIDs
    }

    @discardableResult
    func importSelectedVouchers(
        to modelContext: NSManagedObjectContext,
        pdfData: Data
    ) throws -> [UUID] {
        try importSelectedVouchers(to: modelContext, importSource: .pdf(data: pdfData))
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
    ///   - importSource: Source originale importée
    ///   - modelContext: Contexte Core Data
    func importSingleVoucher(
        storeName: String,
        amount: Double?,
        voucherNumber: String,
        pinCode: String?,
        codeType: CodeType,
        expirationDate: Date?,
        cardColor: Color,
        textColor: Color,
        importSource: VoucherImportSource?,
        to modelContext: NSManagedObjectContext
    ) throws -> UUID {
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
            context: modelContext,
            storeName: storeName,
            amount: amount,
            voucherNumber: voucherNumber,
            pinCode: pinCode,
            codeType: codeType,
            codeImageData: codeImage.flatMap { BarcodeGenerator.imageToData($0) },
            expirationDate: expirationDate,
            sortOrder: getNextSortOrder(in: modelContext),
            pdfData: importSource?.pdfData,
            imageData: importSource?.imageData,
            storeColor: colorHex,
            textColor: textColorHex
        )
        SharedModelContainer.forgetDeletedLegacyVoucherForUserImport(voucher)
        
        // Apprentissage
        let detectedName = analysisResult?.detectedStoreName
        StoreNameLearning.shared.learnStoreName(storeName, detectedAs: detectedName)
        StoreNameLearning.shared.learnStoreColor(colorHex, for: storeName)
        StoreNameLearning.shared.learnTextColor(textColorHex, for: storeName)
        
        try modelContext.save()
        debugLog("✅ Bon importé: \(storeName)")
        return voucher.safeID ?? voucher.id
    }

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
        to modelContext: NSManagedObjectContext
    ) throws -> UUID {
        try importSingleVoucher(
            storeName: storeName,
            amount: amount,
            voucherNumber: voucherNumber,
            pinCode: pinCode,
            codeType: codeType,
            expirationDate: expirationDate,
            cardColor: cardColor,
            textColor: textColor,
            importSource: .pdf(data: pdfData),
            to: modelContext
        )
    }

    private func getNextSortOrder(in modelContext: NSManagedObjectContext) -> Int {
        do {
            let vouchers = try modelContext.fetch(Voucher.fetchRequest())
            return (vouchers.map(\.sortOrder).max() ?? -1) + 1
        } catch {
            debugLog("⚠️ Impossible de calculer le prochain sortOrder: \(error)")
            return 0
        }
    }
}
