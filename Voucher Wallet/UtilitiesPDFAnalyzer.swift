//
//  PDFAnalyzer.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import Foundation
import PDFKit
import Vision
import UIKit

/// Analyseur de PDF pour extraire les informations des bons d'achat
class PDFAnalyzer {
    
    struct AnalysisResult {
        var detectedText: [String] = []
        var barcodes: [VNBarcodeObservation] = []
        var qrCodes: [VNBarcodeObservation] = []
        var possibleVoucherNumbers: [String] = []
        var possiblePinCodes: [String] = []
        var possibleAmounts: [Double] = []
        var possibleDates: [Date] = []
        var detectedStoreName: String? = nil
        var detectedVouchers: [DetectedVoucher] = []
        
        // Propriété pour debug
        var allExtractedText: String {
            detectedText.joined(separator: "\n")
        }
    }
    
    /// Structure représentant un bon détecté dans le PDF
    struct DetectedVoucher: Identifiable {
        let id = UUID()
        let pageNumber: Int
        let voucherNumber: String
        let codeType: CodeType
        let storeName: String?
        let amount: Double?
        let pinCode: String?
        let expirationDate: Date?
        let codeImageData: Data?
    }
    
    /// Analyse un document PDF et extrait toutes les informations possibles
    static func analyzePDF(data: Data) async throws -> AnalysisResult {
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFAnalyzerError.invalidPDF
        }
        
        var result = AnalysisResult()
        
        print("📄 Analyse d'un PDF avec \(pdfDocument.pageCount) page(s)")
        
        // Analyser chaque page séparément
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            print("\n📃 Page \(pageIndex + 1)/\(pdfDocument.pageCount)")
            
            // Analyser cette page
            let pageResult = try await analyzePage(page, pageNumber: pageIndex + 1)
            
            // Ajouter les résultats globaux
            result.detectedText.append(contentsOf: pageResult.texts)
            result.barcodes.append(contentsOf: pageResult.barcodes)
            result.qrCodes.append(contentsOf: pageResult.qrCodes)
            
            // Si on a détecté un bon complet sur cette page, l'ajouter
            if let voucher = pageResult.detectedVoucher {
                result.detectedVouchers.append(voucher)
                print("✅ Bon détecté sur la page \(pageIndex + 1): \(voucher.voucherNumber)")
            }
        }
        
        // Si aucun bon individuel n'a été détecté, créer un résultat global
        if result.detectedVouchers.isEmpty {
            print("⚠️ Aucun bon individuel détecté, création d'un résultat global")
            
            // Analyser le texte extrait pour trouver des patterns globaux
            let allText = result.detectedText.joined(separator: " ")
            
            print("📄 Texte extrait du PDF:")
            print(allText)
            print("---")
            
            // Extraire les informations des codes-barres détectés
            for barcode in result.barcodes {
                if let payload = barcode.payloadStringValue {
                    print("🔢 Code-barres détecté: \(payload)")
                    result.possibleVoucherNumbers.append(payload)
                }
            }
            
            for qrCode in result.qrCodes {
                if let payload = qrCode.payloadStringValue {
                    print("📱 QR Code détecté: \(payload)")
                    result.possibleVoucherNumbers.append(payload)
                }
            }
            
            result.possibleVoucherNumbers.append(contentsOf: extractVoucherNumbers(from: allText))
            result.possiblePinCodes = extractPinCodes(from: allText)
            result.possibleAmounts = extractAmounts(from: allText)
            result.possibleDates = extractDates(from: allText)
            result.detectedStoreName = detectStoreName(from: allText)
            
            print("✅ Numéros détectés: \(result.possibleVoucherNumbers)")
            print("🏪 Enseigne détectée: \(result.detectedStoreName ?? "Aucune")")
        } else {
            print("\n🎉 \(result.detectedVouchers.count) bon(s) détecté(s) au total")
        }
        
        return result
    }
    
    /// Analyse une page individuelle du PDF
    private static func analyzePage(_ page: PDFPage, pageNumber: Int) async throws -> PageAnalysisResult {
        var pageResult = PageAnalysisResult(pageNumber: pageNumber)
        
        // Extraire le texte
        if let text = page.string {
            pageResult.texts.append(text)
        }
        
        // Convertir la page en image pour l'analyse Vision
        guard let pageImage = renderPDFPage(page) else {
            return pageResult
        }
        
        // Détecter les codes-barres et QR codes
        let codes = try await detectBarcodes(in: pageImage)
        for code in codes {
            if code.symbology == .qr {
                pageResult.qrCodes.append(code)
            } else {
                pageResult.barcodes.append(code)
            }
        }
        
        // Effectuer l'OCR pour extraire le texte
        let ocrText = try await performOCR(on: pageImage)
        pageResult.texts.append(contentsOf: ocrText)
        
        // Tenter de construire un bon à partir des données de cette page
        let allPageText = pageResult.texts.joined(separator: " ")
        
        // Déterminer le numéro du bon (depuis le code ou le texte)
        var voucherNumber: String?
        var codeType: CodeType = .barcode
        var codeImageData: Data?
        
        if let firstBarcode = pageResult.barcodes.first,
           let payload = firstBarcode.payloadStringValue {
            voucherNumber = payload
            codeType = .barcode
            // Générer l'image du code
            if let image = BarcodeGenerator.generateBarcode(from: payload) {
                codeImageData = BarcodeGenerator.imageToData(image)
            }
        } else if let firstQR = pageResult.qrCodes.first,
                  let payload = firstQR.payloadStringValue {
            voucherNumber = payload
            codeType = .qrCode
            // Générer l'image du code
            if let image = BarcodeGenerator.generateQRCode(from: payload) {
                codeImageData = BarcodeGenerator.imageToData(image)
            }
        } else {
            // Pas de code détecté, essayer d'extraire du texte
            let numbers = extractVoucherNumbers(from: allPageText)
            voucherNumber = numbers.first
        }
        
        // Si on a un numéro, créer un DetectedVoucher
        if let number = voucherNumber {
            let voucher = DetectedVoucher(
                pageNumber: pageNumber,
                voucherNumber: number,
                codeType: codeType,
                storeName: detectStoreName(from: allPageText),
                amount: extractAmounts(from: allPageText).first,
                pinCode: extractPinCodes(from: allPageText).first,
                expirationDate: extractDates(from: allPageText).first,
                codeImageData: codeImageData
            )
            pageResult.detectedVoucher = voucher
        }
        
        return pageResult
    }
    
    /// Résultat de l'analyse d'une page
    private struct PageAnalysisResult {
        let pageNumber: Int
        var texts: [String] = []
        var barcodes: [VNBarcodeObservation] = []
        var qrCodes: [VNBarcodeObservation] = []
        var detectedVoucher: DetectedVoucher?
    }
    
    // MARK: - Vision Framework
    
    /// Détecte les codes-barres et QR codes dans une image
    private static func detectBarcodes(in image: UIImage) async throws -> [VNBarcodeObservation] {
        guard let cgImage = image.cgImage else { return [] }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNBarcodeObservation] ?? []
                continuation.resume(returning: observations)
            }
            
            request.symbologies = [.qr, .code128, .ean13, .ean8, .upce, .code39, .code93]
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Effectue l'OCR (reconnaissance de texte) sur une image
    private static func performOCR(on image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["fr-FR", "en-US"]
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Pattern Extraction
    
    /// Extrait les numéros de bons possibles (séquences de chiffres/lettres)
    private static func extractVoucherNumbers(from text: String) -> [String] {
        var numbers: [String] = []
        
        // Pattern 1: 10+ chiffres consécutifs
        let digitPattern = #/\d{10,}/#
        let digitMatches = text.matches(of: digitPattern)
        for match in digitMatches {
            numbers.append(String(match.0))
        }
        
        // Pattern 2: Format avec tirets (XXXX-XXXX-XXXX)
        let dashPattern = #/[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4,}/#
        let dashMatches = text.matches(of: dashPattern)
        for match in dashMatches {
            numbers.append(String(match.0))
        }
        
        // Pattern 3: Code alphanumérique (lettres + 6+ chiffres)
        let alphaPattern = #/[A-Z]{2,}[0-9]{6,}/#
        let alphaMatches = text.matches(of: alphaPattern)
        for match in alphaMatches {
            numbers.append(String(match.0))
        }
        
        // Pattern 4: Codes EAN-13 (13 chiffres)
        let ean13Pattern = #/\b\d{13}\b/#
        let ean13Matches = text.matches(of: ean13Pattern)
        for match in ean13Matches {
            numbers.append(String(match.0))
        }
        
        // Pattern 5: Séquences de 8-9 chiffres (codes courts)
        let shortPattern = #/\b\d{8,9}\b/#
        let shortMatches = text.matches(of: shortPattern)
        for match in shortMatches {
            numbers.append(String(match.0))
        }
        
        let uniqueNumbers = Array(Set(numbers))
        print("🔢 Numéros extraits du texte: \(uniqueNumbers)")
        return uniqueNumbers
    }
    
    /// Extrait les codes PIN possibles (4 chiffres généralement)
    private static func extractPinCodes(from text: String) -> [String] {
        var pins: [String] = []
        
        // Rechercher "PIN" ou "Code" suivi de 4 chiffres
        let pinPattern = #/(PIN|Code|pin|code)[\s:]*(\d{4})/#
        let matches = text.matches(of: pinPattern)
        
        for match in matches {
            pins.append(String(match.2))
        }
        
        return Array(Set(pins))
    }
    
    /// Extrait les montants en euros
    private static func extractAmounts(from text: String) -> [Double] {
        var amounts: [Double] = []
        
        // Pattern: montants avec € ou EUR
        let patterns = [
            #/(\d+[.,]\d{2})\s*€/#,
            #/(\d+)\s*€/#,
            #/€\s*(\d+[.,]\d{2})/#,
            #/(\d+[.,]\d{2})\s*EUR/#
        ]
        
        for pattern in patterns {
            let matches = text.matches(of: pattern)
            for match in matches {
                let amountStr = String(match.1).replacingOccurrences(of: ",", with: ".")
                if let amount = Double(amountStr) {
                    amounts.append(amount)
                }
            }
        }
        
        return Array(Set(amounts)).sorted(by: >)
    }
    
    /// Extrait les dates possibles
    private static func extractDates(from text: String) -> [Date] {
        var dates: [Date] = []
        
        // Patterns de dates français
        let datePatterns = [
            #/(\d{2})/(\d{2})/(\d{4})/#,  // JJ/MM/AAAA
            #/(\d{2})-(\d{2})-(\d{4})/#,  // JJ-MM-AAAA
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "dd/MM/yyyy"
        
        for pattern in datePatterns {
            let matches = text.matches(of: pattern)
            for match in matches {
                let dateStr = "\(match.1)/\(match.2)/\(match.3)"
                if let date = dateFormatter.date(from: dateStr) {
                    // Ne garder que les dates futures (probablement des dates d'expiration)
                    if date > Date() {
                        dates.append(date)
                    }
                }
            }
        }
        
        return dates.sorted()
    }
    
    /// Détecte le nom de l'enseigne dans le texte
    private static func detectStoreName(from text: String) -> String? {
        // Liste des enseignes à détecter (de StorePreset)
        let storeNames = [
            "Carrefour", "Decathlon", "Fnac", "Amazon", "Ikea",
            "Auchan", "Leclerc", "Boulanger", "Darty", "Intersport",
            "H&M", "Zara", "Sephora", "Galeries Lafayette", "Printemps"
        ]
        
        let uppercasedText = text.uppercased()
        
        // Recherche exacte (insensible à la casse)
        for storeName in storeNames {
            if uppercasedText.contains(storeName.uppercased()) {
                print("🏪 Enseigne trouvée: \(storeName)")
                return storeName
            }
        }
        
        // Recherche partielle avec variations
        let variations = [
            "CARREFOUR": "Carrefour",
            "DECATHLON": "Decathlon",
            "FNAC": "Fnac",
            "AMAZON": "Amazon",
            "IKEA": "Ikea",
            "AUCHAN": "Auchan",
            "E.LECLERC": "Leclerc",
            "LECLERC": "Leclerc",
            "BOULANGER": "Boulanger",
            "DARTY": "Darty",
            "INTERSPORT": "Intersport"
        ]
        
        for (variant, storeName) in variations {
            if uppercasedText.contains(variant) {
                print("🏪 Enseigne trouvée (variation): \(storeName)")
                return storeName
            }
        }
        
        print("❌ Aucune enseigne détectée")
        return nil
    }
    
    // MARK: - PDF Rendering
    
    /// Convertit une page PDF en UIImage
    private static func renderPDFPage(_ page: PDFPage) -> UIImage? {
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        
        let image = renderer.image { context in
            UIColor.white.set()
            context.fill(pageRect)
            
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        return image
    }
}

enum PDFAnalyzerError: LocalizedError {
    case invalidPDF
    case analysisError
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Le fichier PDF n'est pas valide"
        case .analysisError:
            return "Erreur lors de l'analyse du PDF"
        }
    }
}
