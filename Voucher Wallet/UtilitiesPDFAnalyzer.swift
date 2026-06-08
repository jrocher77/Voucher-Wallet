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
    
    /// Événements de progression de l'analyse
    enum AnalysisProgress: Sendable {
        case loading(message: String)
        case analyzingPage(current: Int, total: Int)
        case detectingBarcodes(pageNumber: Int)
        case performingOCR(pageNumber: Int)
        case extractingData(message: String)
        case completed
        
        /// Message lisible pour l'utilisateur
        var userMessage: String {
            switch self {
            case .loading(let message):
                return message
            case .analyzingPage(let current, let total):
                return "Analyse de la page \(current) sur \(total)..."
            case .detectingBarcodes(let pageNumber):
                return "Détection des codes-barres (page \(pageNumber))..."
            case .performingOCR(let pageNumber):
                return "Lecture du texte (page \(pageNumber))..."
            case .extractingData(let message):
                return message
            case .completed:
                return "Analyse terminée !"
            }
        }
        
        /// Progression estimée de 0.0 à 1.0
        func progress(totalPages: Int) -> Double {
            switch self {
            case .loading:
                return 0.1
            case .analyzingPage(let current, let total):
                let baseProgress = 0.1
                let pageProgress = 0.8 * (Double(current) / Double(total))
                return baseProgress + pageProgress
            case .detectingBarcodes:
                return 0.3
            case .performingOCR:
                return 0.5
            case .extractingData:
                return 0.9
            case .completed:
                return 1.0
            }
        }
    }
    
    struct AnalysisResult {
        var detectedText: [String] = []
        var barcodes: [VNBarcodeObservation] = []
        var qrCodes: [VNBarcodeObservation] = []
        var possibleVoucherNumbers: [String] = []
        var possiblePinCodes: [String] = []
        var possibleAmounts: [Double] = []
        var possibleDates: [Date] = []
        var detectedStoreName: String? = nil
        var storeNameConfidence: Double = 0.0  // Score de confiance pour le nom détecté
        var detectionMethod: StoreNameLearning.DetectionMethod? = nil
        var detectedVouchers: [DetectedVoucher] = []
        
        // Propriété pour debug
        var allExtractedText: String {
            detectedText.joined(separator: "\n")
        }
    }
    
    /// Structure représentant un bon détecté dans le PDF
    struct DetectedVoucher: Identifiable {
        var id: UUID
        let pageNumber: Int
        var voucherNumber: String
        var codeType: CodeType
        var storeName: String?
        var storeNameConfidence: Double = 0.0  // Score de confiance pour le nom de l'enseigne
        var amount: Double?
        var pinCode: String?
        var expirationDate: Date?
        var codeImageData: Data?
        var storeColor: String?  // Couleur de l'enseigne en hex
        
        init(id: UUID = UUID(), pageNumber: Int, voucherNumber: String, codeType: CodeType, storeName: String? = nil, storeNameConfidence: Double = 0.0, amount: Double? = nil, pinCode: String? = nil, expirationDate: Date? = nil, codeImageData: Data? = nil, storeColor: String? = nil) {
            self.id = id
            self.pageNumber = pageNumber
            self.voucherNumber = voucherNumber
            self.codeType = codeType
            self.storeName = storeName
            self.storeNameConfidence = storeNameConfidence
            self.amount = amount
            self.pinCode = pinCode
            self.expirationDate = expirationDate
            self.codeImageData = codeImageData
            self.storeColor = storeColor
        }
    }
    
    /// Analyse un document PDF et extrait toutes les informations possibles
    /// - Parameters:
    ///   - data: Données du fichier PDF
    ///   - progressHandler: Closure appelée à chaque étape de l'analyse (optionnel)
    /// - Returns: Résultat de l'analyse contenant toutes les informations extraites
    static func analyzePDF(
        data: Data,
        progressHandler: (@MainActor @Sendable (AnalysisProgress) -> Void)? = nil
    ) async throws -> AnalysisResult {
        
        if let handler = progressHandler {
            await MainActor.run { handler(.loading(message: "Chargement du PDF...")) }
        }
        
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFAnalyzerError.invalidPDF
        }
        
        var result = AnalysisResult()
        
        debugLog("📄 Analyse d'un PDF avec \(pdfDocument.pageCount) page(s)")
        
        let totalPages = pdfDocument.pageCount
        if let handler = progressHandler {
            await MainActor.run { handler(.loading(message: "PDF chargé (\(totalPages) page\(totalPages > 1 ? "s" : ""))")) }
        }
        
        // Analyser chaque page séparément
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            let currentPage = pageIndex + 1
            if let handler = progressHandler {
                await MainActor.run { handler(.analyzingPage(current: currentPage, total: totalPages)) }
            }
            
            debugLog("\n📃 Page \(currentPage)/\(totalPages)")
            
            // Analyser cette page avec les callbacks de progression
            let pageResult = try await analyzePage(
                page,
                pageNumber: currentPage,
                progressHandler: progressHandler
            )
            
            // Ajouter les résultats globaux
            result.detectedText.append(contentsOf: pageResult.texts)
            result.barcodes.append(contentsOf: pageResult.barcodes)
            result.qrCodes.append(contentsOf: pageResult.qrCodes)
            
            // Si on a détecté un bon complet sur cette page, l'ajouter
            if let voucher = pageResult.detectedVoucher {
                result.detectedVouchers.append(voucher)
                debugLog("✅ Bon détecté sur la page \(currentPage)")
            }
        }
        
        // Si aucun bon individuel n'a été détecté, créer un résultat global
        if result.detectedVouchers.isEmpty {
            if let handler = progressHandler {
                await MainActor.run { handler(.extractingData(message: "Extraction des informations...")) }
            }
            
            debugLog("⚠️ Aucun bon individuel détecté, création d'un résultat global")
            
            // Analyser le texte extrait pour trouver des patterns globaux
            let allText = result.detectedText.joined(separator: " ")
            
            debugLog("📄 Texte OCR extrait du PDF (\(allText.count) caractère(s))")
            
            // Extraire les informations des codes-barres détectés
            for barcode in result.barcodes {
                if let payload = barcode.payloadStringValue {
                    debugLog("🔢 Code-barres détecté")
                    result.possibleVoucherNumbers.append(payload)
                }
            }
            
            for qrCode in result.qrCodes {
                if let payload = qrCode.payloadStringValue {
                    debugLog("📱 QR Code détecté")
                    result.possibleVoucherNumbers.append(payload)
                }
            }
            
            result.possibleVoucherNumbers.append(contentsOf: extractVoucherNumbers(from: allText))
            result.possibleVoucherNumbers = uniqueVoucherNumbers(result.possibleVoucherNumbers)
            result.possiblePinCodes = extractPinCodes(from: allText)
            result.possibleAmounts = extractAmounts(from: allText)
            result.possibleDates = extractDates(from: allText)
            
            // Détecter le nom de l'enseigne avec score de confiance
            let storeDetection = detectStoreName(from: allText)
            result.detectedStoreName = storeDetection.name
            result.storeNameConfidence = storeDetection.confidence
            result.detectionMethod = storeDetection.method
            
            debugLog("✅ \(result.possibleVoucherNumbers.count) numéro(s) candidat(s) détecté(s)")
            debugLog("🏪 Enseigne détectée: \(result.detectedStoreName ?? "Aucune") (confiance: \(String(format: "%.0f%%", result.storeNameConfidence * 100)))")
        } else {
            debugLog("\n🎉 \(result.detectedVouchers.count) bon(s) détecté(s) au total")
        }
        
        if let handler = progressHandler {
            await MainActor.run { handler(.completed) }
        }
        
        return result
    }

    /// Analyse une image et extrait toutes les informations possibles.
    /// L'image est traitée comme un document d'une seule page.
    static func analyzeImage(
        data: Data,
        progressHandler: (@MainActor @Sendable (AnalysisProgress) -> Void)? = nil
    ) async throws -> AnalysisResult {
        if let handler = progressHandler {
            await MainActor.run { handler(.loading(message: "Chargement de l'image...")) }
        }

        guard let image = UIImage(data: data) else {
            throw PDFAnalyzerError.invalidImage
        }

        var result = AnalysisResult()

        if let handler = progressHandler {
            await MainActor.run { handler(.analyzingPage(current: 1, total: 1)) }
            await MainActor.run { handler(.detectingBarcodes(pageNumber: 1)) }
        }

        let codes = try await detectBarcodes(in: image)
        for code in codes {
            if code.symbology == .qr {
                result.qrCodes.append(code)
            } else {
                result.barcodes.append(code)
            }
        }

        if let handler = progressHandler {
            await MainActor.run { handler(.performingOCR(pageNumber: 1)) }
        }

        let ocrText = try await performOCR(on: image)
        result.detectedText.append(contentsOf: ocrText)

        if let handler = progressHandler {
            await MainActor.run { handler(.extractingData(message: "Extraction des informations...")) }
        }

        let allText = result.detectedText.joined(separator: " ")
        var voucherNumber: String?
        var codeType: CodeType = .barcode
        var codeImageData: Data?

        if let firstBarcode = result.barcodes.first,
           let payload = firstBarcode.payloadStringValue {
            voucherNumber = payload
            codeType = .barcode
            if let image = BarcodeGenerator.generateBarcode(from: payload) {
                codeImageData = BarcodeGenerator.imageToData(image)
            }
        } else if let firstQR = result.qrCodes.first,
                  let payload = firstQR.payloadStringValue {
            voucherNumber = payload
            codeType = .qrCode
            if let image = BarcodeGenerator.generateQRCode(from: payload) {
                codeImageData = BarcodeGenerator.imageToData(image)
            }
        } else {
            voucherNumber = extractVoucherNumbers(from: allText).first
        }

        result.possibleVoucherNumbers.append(contentsOf: result.barcodes.compactMap { $0.payloadStringValue })
        result.possibleVoucherNumbers.append(contentsOf: result.qrCodes.compactMap { $0.payloadStringValue })
        result.possibleVoucherNumbers.append(contentsOf: extractVoucherNumbers(from: allText))
        result.possibleVoucherNumbers = uniqueVoucherNumbers(result.possibleVoucherNumbers)
        result.possiblePinCodes = extractPinCodes(from: allText)
        result.possibleAmounts = extractAmounts(from: allText)
        result.possibleDates = extractDates(from: allText)

        let storeDetection = detectStoreName(from: allText)
        result.detectedStoreName = storeDetection.name
        result.storeNameConfidence = storeDetection.confidence
        result.detectionMethod = storeDetection.method

        if let voucherNumber {
            result.detectedVouchers.append(DetectedVoucher(
                pageNumber: 1,
                voucherNumber: voucherNumber,
                codeType: codeType,
                storeName: storeDetection.name,
                storeNameConfidence: storeDetection.confidence,
                amount: result.possibleAmounts.first,
                pinCode: result.possiblePinCodes.first,
                expirationDate: result.possibleDates.first,
                codeImageData: codeImageData,
                storeColor: storeDetection.name.flatMap { storeColorHex(for: $0) }
            ))
        }

        if let handler = progressHandler {
            await MainActor.run { handler(.completed) }
        }

        debugLog("🖼️ Analyse image terminée: \(result.detectedVouchers.count) bon(s) détecté(s)")
        return result
    }
    
    /// Analyse une page individuelle du PDF
    /// - Parameters:
    ///   - page: La page PDF à analyser
    ///   - pageNumber: Le numéro de la page (1-indexed)
    ///   - progressHandler: Closure pour les updates de progression
    /// - Returns: Résultat de l'analyse de la page
    private static func analyzePage(
        _ page: PDFPage,
        pageNumber: Int,
        progressHandler: (@MainActor @Sendable (AnalysisProgress) -> Void)?
    ) async throws -> PageAnalysisResult {
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
        if let handler = progressHandler {
            await MainActor.run { handler(.detectingBarcodes(pageNumber: pageNumber)) }
        }
        let codes = try await detectBarcodes(in: pageImage)
        for code in codes {
            if code.symbology == .qr {
                pageResult.qrCodes.append(code)
            } else {
                pageResult.barcodes.append(code)
            }
        }
        
        // Effectuer l'OCR pour extraire le texte
        if let handler = progressHandler {
            await MainActor.run { handler(.performingOCR(pageNumber: pageNumber)) }
        }
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
            let storeDetection = detectStoreName(from: allPageText)
            
            // Déterminer la couleur de l'enseigne si connue
            var storeColorHex: String? = nil
            if let storeName = storeDetection.name {
                // Essayer d'obtenir la couleur apprise
                storeColorHex = StoreNameLearning.shared.getLearnedColor(for: storeName)
                
                // Si pas de couleur apprise, vérifier les presets
                if storeColorHex == nil {
                    // Recherche exacte dans les presets
                    if let presetColor = StorePreset.presets[storeName] {
                        storeColorHex = presetColor
                    } else {
                        // Recherche partielle
                        for (preset, color) in StorePreset.presets {
                            if storeName.localizedCaseInsensitiveContains(preset) {
                                storeColorHex = color
                                break
                            }
                        }
                    }
                }
            }
            
            let voucher = DetectedVoucher(
                pageNumber: pageNumber,
                voucherNumber: number,
                codeType: codeType,
                storeName: storeDetection.name,
                storeNameConfidence: storeDetection.confidence,
                amount: extractAmounts(from: allPageText).first,
                pinCode: extractPinCodes(from: allPageText).first,
                expirationDate: extractDates(from: allPageText).first,
                codeImageData: codeImageData,
                storeColor: storeColorHex
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

        func addCandidate(_ rawValue: String, label: String) {
            let value = rawValue
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: " ", with: "")

            guard value.count >= 6 else { return }
            guard value.range(of: #"^[A-Z0-9-]+$"#, options: .regularExpression) != nil else { return }
            guard !numbers.contains(value) else { return }

            numbers.append(value)
            debugLog("🔢 Numéro détecté (pattern '\(label)')")
        }

        func addMatches(pattern: String, groupIndex: Int, label: String) {
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return
            }

            for match in regex.matches(in: text, range: fullRange) {
                let range = match.range(at: groupIndex)
                guard range.location != NSNotFound else { continue }
                addCandidate(nsText.substring(with: range).uppercased(), label: label)
            }
        }

        // Pattern 1: libellés explicites. Couvre les codes mixtes comme Zalando
        // (ex: "Votre code: P3JCW3NVDLUJVR3F").
        addMatches(
            pattern: #"\b(?:Votre\s+code|Code\s+bon|Code\s+carte|Num[eé]ro\s+(?:du\s+)?(?:bon|carte))\s*[:：]\s*([A-Z0-9][A-Z0-9-]{5,39})\b"#,
            groupIndex: 1,
            label: "code libellé"
        )

        // Pattern 2: 10+ chiffres consécutifs
        let digitPattern = #/\d{10,}/#
        let digitMatches = text.matches(of: digitPattern)
        for match in digitMatches {
            addCandidate(String(match.0), label: "chiffres longs")
        }
        
        // Pattern 3: Format avec tirets (XXXX-XXXX-XXXX)
        let dashPattern = #/[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4,}/#
        let dashMatches = text.matches(of: dashPattern)
        for match in dashMatches {
            addCandidate(String(match.0), label: "format tirets")
        }
        
        // Pattern 4: Code alphanumérique (lettres + 6+ chiffres)
        let alphaPattern = #/[A-Z]{2,}[0-9]{6,}/#
        let alphaMatches = text.matches(of: alphaPattern)
        for match in alphaMatches {
            addCandidate(String(match.0), label: "alphanumérique")
        }
        
        // Pattern 5: Codes EAN-13 (13 chiffres)
        let ean13Pattern = #/\b\d{13}\b/#
        let ean13Matches = text.matches(of: ean13Pattern)
        for match in ean13Matches {
            addCandidate(String(match.0), label: "EAN-13")
        }
        
        // Pattern 6: Séquences de 8-9 chiffres (codes courts)
        let shortPattern = #/\b\d{8,9}\b/#
        let shortMatches = text.matches(of: shortPattern)
        for match in shortMatches {
            addCandidate(String(match.0), label: "code court")
        }

        debugLog("🔢 \(numbers.count) numéro(s) extrait(s) du texte")
        return numbers
    }

    private static func uniqueVoucherNumbers(_ numbers: [String]) -> [String] {
        var seen = Set<String>()
        var uniqueNumbers: [String] = []

        for number in numbers {
            let displayValue = number.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayValue.isEmpty else { continue }

            let key = displayValue
                .filter { !$0.isWhitespace && $0 != "-" }
                .uppercased()

            guard !key.isEmpty, seen.insert(key).inserted else { continue }
            uniqueNumbers.append(displayValue)
        }

        return uniqueNumbers
    }
    
    /// Extrait les codes PIN possibles (chiffres ou lettres quand le libellé est explicite)
    private static func extractPinCodes(from text: String) -> [String] {
        var pins: [String] = []

        func addMatches(pattern: String, groupIndex: Int, label: String) {
            let nsText = text as NSString
            let fullRange = NSRange(location: 0, length: nsText.length)
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return
            }

            for match in regex.matches(in: text, range: fullRange) {
                let range = match.range(at: groupIndex)
                guard range.location != NSNotFound else { continue }

                let pinCode = nsText.substring(with: range)
                pins.append(pinCode)
                debugLog("📍 Code PIN détecté (pattern '\(label)')")
            }
        }

        // 1. Rechercher "Code PIN" ou "Code pin" (le plus spécifique)
        addMatches(
            pattern: #"\bCode\s+PIN\s*[:：]\s*([A-Z0-9]{1,10})\b"#,
            groupIndex: 1,
            label: "Code PIN"
        )

        addMatches(
            pattern: #"\bCode\s+PIN\s+(\d{1,10})\b"#,
            groupIndex: 1,
            label: "Code PIN numérique"
        )

        // 2. Rechercher "PIN" ou "pin" suivi de chiffres (moins spécifique)
        // Seulement si on n'a pas déjà trouvé de PIN avec le pattern précédent
        if pins.isEmpty {
            addMatches(
                pattern: #"\bPIN\s*[:：]\s*([A-Z0-9]{1,10})\b"#,
                groupIndex: 1,
                label: "PIN"
            )

            addMatches(
                pattern: #"\bPIN\s+(\d{1,10})\b"#,
                groupIndex: 1,
                label: "PIN numérique"
            )
        }

        // 3. Rechercher "code secret" (utilisé par certaines enseignes)
        addMatches(
            pattern: #"\b(?:code\s+secret|secret)\s*[:：]\s*([A-Z0-9]{1,10})\b"#,
            groupIndex: 1,
            label: "code secret"
        )

        addMatches(
            pattern: #"\b(?:code\s+secret|secret)\s+(\d{1,10})\b"#,
            groupIndex: 1,
            label: "code secret numérique"
        )

        let uniquePins = Array(Set(pins))
        if !uniquePins.isEmpty {
            debugLog("🔐 \(uniquePins.count) code(s) PIN extrait(s)")
        }
        
        return uniquePins
    }
    
    /// Extrait les montants en euros
    private static func extractAmounts(from text: String) -> [Double] {
        struct AmountCandidate {
            let amount: Double
            let score: Int
            let order: Int
        }

        var candidates: [AmountCandidate] = []
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let pattern = #"(?i)(?:€\s*(\d+(?:[.,]\d{2})?)|(\d+(?:[.,]\d{2})?)\s*(?:€|EUR))"#

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        for (index, match) in regex.matches(in: text, range: fullRange).enumerated() {
            let amountRange = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            let amountString = nsText.substring(with: amountRange).replacingOccurrences(of: ",", with: ".")

            guard let amount = Double(amountString) else { continue }

            let contextStart = max(0, match.range.location - 60)
            let contextEnd = min(nsText.length, match.range.location + match.range.length + 60)
            let contextRange = NSRange(location: contextStart, length: contextEnd - contextStart)
            let context = nsText.substring(with: contextRange).folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)

            var score = 0
            let positiveKeywords = ["montant", "valeur", "solde", "credit", "chargee", "carte cadeau", "e-carte cadeau"]
            let negativeKeywords = ["maximum", "maxi", "plafond", "limite", "jusqu", "conditions", "cgv", "reglement", "minimum", "entre", "librement", "determine"]

            for keyword in positiveKeywords where context.contains(keyword) {
                score += 3
            }

            for keyword in negativeKeywords where context.contains(keyword) {
                score -= 5
            }

            if amount >= 500 {
                score -= 2
            }

            candidates.append(AmountCandidate(amount: amount, score: score, order: index))
        }

        var bestByAmount: [Double: AmountCandidate] = [:]
        for candidate in candidates {
            if let existing = bestByAmount[candidate.amount] {
                if candidate.score > existing.score || (candidate.score == existing.score && candidate.order < existing.order) {
                    bestByAmount[candidate.amount] = candidate
                }
            } else {
                bestByAmount[candidate.amount] = candidate
            }
        }

        return bestByAmount.values.sorted { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.order < rhs.order
        }.map(\.amount)
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
    
    /// Détecte le nom de l'enseigne dans le texte avec score de confiance
    /// - Returns: Tuple contenant le nom, le score de confiance et la méthode de détection
    private static func detectStoreName(from text: String) -> (name: String?, confidence: Double, method: StoreNameLearning.DetectionMethod?) {
        let learning = StoreNameLearning.shared
        
        // Liste des enseignes connues (source unique: StorePreset)
        let knownStores = Array(StorePreset.presets.keys)
        
        let uppercasedText = text.uppercased()
        let lines = text.components(separatedBy: .newlines)
        
        // Cas spécial: co-branding Fnac / Darty sur le même document
        if containsStoreName("Fnac", in: text) && containsStoreName("Darty", in: text) {
            var cobrandContext = StoreNameLearning.DetectionContext()
            cobrandContext.hasMatchingURL = uppercasedText.contains("FNACDARTY")
                || uppercasedText.contains("FNAC-DARTY")
                || uppercasedText.contains("FNAC/DARTY")
            cobrandContext.isInFirstLines = lines.prefix(8).contains { line in
                let upperLine = line.uppercased()
                return upperLine.contains("FNAC") && upperLine.contains("DARTY")
            }
            cobrandContext.isAllUppercase = uppercasedText.contains("FNAC") && uppercasedText.contains("DARTY")
            
            let cobrandName = "Fnac / Darty"
            let confidence = learning.calculateConfidenceScore(
                for: cobrandName,
                detectionMethod: .knownStore,
                context: cobrandContext
            )
            
            debugLog("🏪 Enseigne co-brand détectée: \(cobrandName)")
            debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
            return (cobrandName, confidence, .knownStore)
        }
        
        // 1. Recherche dans les enseignes connues (prioritaire)
        var knownStoreCandidates: [(name: String, confidence: Double)] = []
        for storeName in knownStores {
            if containsStoreName(storeName, in: text) {
                debugLog("🏪 Enseigne connue trouvée: \(storeName)")
                if let matchedLine = firstMatchingLine(for: storeName, in: text) {
                    debugLog("  🔎 Ligne OCR matchée: \(matchedLine)")
                }
                
                // Enrichir le contexte
                var context = StoreNameLearning.DetectionContext()
                context.hasMatchingURL = uppercasedText.contains(storeName.uppercased().replacingOccurrences(of: " ", with: ""))
                context.isInFirstLines = lines.prefix(5).contains { $0.uppercased().contains(storeName.uppercased()) }
                context.isAllUppercase = uppercasedText.contains(storeName.uppercased())
                
                var confidence = learning.calculateConfidenceScore(
                    for: storeName,
                    detectionMethod: .knownStore,
                    context: context
                )
                
                // Bonus si l'enseigne est répétée plusieurs fois (cas documents multi-occurrences)
                let occurrences = countStoreOccurrences(storeName, in: text)
                if occurrences > 1 {
                    confidence += min(Double(occurrences - 1) * 0.03, 0.12)
                }
                confidence = min(confidence, 1.0)
                
                debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                knownStoreCandidates.append((storeName, confidence))
            }
        }
        
        if let bestKnownStore = knownStoreCandidates
            .sorted(by: { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.confidence > rhs.confidence
            })
            .first {
            return (bestKnownStore.name, bestKnownStore.confidence, .knownStore)
        }

        // 2. Recherche dans les libellés propres aux bons ("VOTRE E-BILLET ...",
        // "VOTRE E-CARTE CADEAU ..."). Ces lignes désignent généralement le marchand,
        // contrairement à l'en-tête qui peut contenir l'émetteur du PDF.
        if let titleCandidate = detectStoreNameFromVoucherTitle(in: lines) {
            debugLog("🏪 Enseigne trouvée dans le titre du bon: \(titleCandidate)")

            var context = StoreNameLearning.DetectionContext()
            context.isInFirstLines = lines.prefix(8).contains { $0.localizedCaseInsensitiveContains(titleCandidate) }
            context.isAllUppercase = titleCandidate == titleCandidate.uppercased()
            context.hasMatchingURL = hasMatchingURL(for: titleCandidate, in: uppercasedText)

            if let validatedName = learning.findValidatedName(for: titleCandidate) {
                let confidence = learning.calculateConfidenceScore(
                    for: validatedName,
                    detectionMethod: .learnedStore,
                    context: context
                )

                debugLog("  🔗 Nom validé trouvé: \(validatedName)")
                debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (validatedName, confidence, .learnedStore)
            }

            let confidence = learning.calculateConfidenceScore(
                for: titleCandidate,
                detectionMethod: .labeledStore,
                context: context
            )

            debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
            return (titleCandidate, confidence, .labeledStore)
        }
        
        // 3. Recherche dans les enseignes apprises
        var learnedStoreCandidates: [(name: String, confidence: Double)] = []
        let learnedStores = learning.getLearnedStoreNames()
        for storeName in learnedStores {
            guard !isIgnoredIssuerName(storeName) else {
                debugLog("⏭️ Enseigne apprise ignorée car identifiée comme émetteur: \(storeName)")
                continue
            }

            if containsStoreName(storeName, in: text) {
                debugLog("🏪 Enseigne apprise trouvée: \(storeName)")
                if let matchedLine = firstMatchingLine(for: storeName, in: text) {
                    debugLog("  🔎 Ligne OCR matchée: \(matchedLine)")
                }
                
                var context = StoreNameLearning.DetectionContext()
                context.hasMatchingURL = uppercasedText.contains(storeName.uppercased().replacingOccurrences(of: " ", with: ""))
                context.isInFirstLines = lines.prefix(5).contains { $0.uppercased().contains(storeName.uppercased()) }
                context.isAllUppercase = uppercasedText.contains(storeName.uppercased())
                
                var confidence = learning.calculateConfidenceScore(
                    for: storeName,
                    detectionMethod: .learnedStore,
                    context: context
                )
                
                let occurrences = countStoreOccurrences(storeName, in: text)
                if occurrences > 1 {
                    confidence += min(Double(occurrences - 1) * 0.03, 0.12)
                }
                confidence = min(confidence, 1.0)
                
                debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                learnedStoreCandidates.append((storeName, confidence))
            }
        }
        
        if let bestLearnedStore = learnedStoreCandidates
            .sorted(by: { lhs, rhs in
                if lhs.confidence == rhs.confidence {
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                return lhs.confidence > rhs.confidence
            })
            .first {
            return (bestLearnedStore.name, bestLearnedStore.confidence, .learnedStore)
        }
        
        // 4. Recherche de variations courantes
        let variations = [
            "E.LECLERC": "Leclerc",
            "E LECLERC": "Leclerc",
            "KING-JOUET": "King Jouet",
            "KING JOUET": "King Jouet",
            "LA GRANDE RECRE": "La Grande Recre",
            "LA GRANDE RÉCRÉ": "La Grande Recre",
            "NATURE & DECOUVERTES": "Nature et Decouvertes",
            "NATURE & DÉCOUVERTES": "Nature et Decouvertes"
        ]
        
        for (variant, storeName) in variations {
            if uppercasedText.contains(variant) {
                debugLog("🏪 Enseigne trouvée (variation): \(storeName)")
                
                var context = StoreNameLearning.DetectionContext()
                context.hasMatchingURL = false
                context.isInFirstLines = true
                context.isAllUppercase = true
                
                let confidence = learning.calculateConfidenceScore(
                    for: storeName,
                    detectionMethod: .knownStore,
                    context: context
                )
                
                debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (storeName, confidence, .knownStore)
            }
        }
        
        // 5. Détection intelligente par heuristiques
        if let (detectedName, method, detectionContext) = detectStoreNameByHeuristics(from: text) {
            debugLog("🏪 Enseigne détectée par heuristique: \(detectedName)")
            
            // Vérifier si ce nom a un mapping vers un nom validé
            if let validatedName = learning.findValidatedName(for: detectedName) {
                debugLog("  🔗 Nom validé trouvé: \(validatedName)")
                
                let confidence = learning.calculateConfidenceScore(
                    for: validatedName,
                    detectionMethod: .learnedStore,
                    context: detectionContext
                )
                
                debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (validatedName, confidence, .learnedStore)
            }
            
            let confidence = learning.calculateConfidenceScore(
                for: detectedName,
                detectionMethod: method,
                context: detectionContext
            )
            
            debugLog("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
            return (detectedName, confidence, method)
        }
        
        debugLog("❌ Aucune enseigne détectée")
        return (nil, 0.0, nil)
    }
    
    /// Vérifie la présence d'une enseigne avec des bornes de mot pour éviter les faux positifs
    /// (ex: "Action" détecté dans "transaction").
    private static func containsStoreName(_ storeName: String, in text: String) -> Bool {
        let escapedName = NSRegularExpression.escapedPattern(for: storeName)
        let pattern = "(?<![\\p{L}\\p{N}])\(escapedName)(?![\\p{L}\\p{N}])"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text.localizedCaseInsensitiveContains(storeName)
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }
    
    /// Retourne la première ligne OCR qui correspond à l'enseigne détectée
    private static func firstMatchingLine(for storeName: String, in text: String) -> String? {
        let trimmedLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return trimmedLines.first { containsStoreName(storeName, in: $0) }
    }
    
    /// Compte le nombre d'occurrences d'une enseigne avec des bornes de mot.
    private static func countStoreOccurrences(_ storeName: String, in text: String) -> Int {
        let escapedName = NSRegularExpression.escapedPattern(for: storeName)
        let pattern = "(?<![\\p{L}\\p{N}])\(escapedName)(?![\\p{L}\\p{N}])"
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return containsStoreName(storeName, in: text) ? 1 : 0
        }
        
        let range = NSRange(text.startIndex..., in: text)
        return regex.numberOfMatches(in: text, options: [], range: range)
    }

    /// Extrait le marchand à partir des titres standard des bons d'achat.
    private static func detectStoreNameFromVoucherTitle(in lines: [String]) -> String? {
        let titlePatterns = [
            #"(?i)\bVOTRE\s+E?[-\s]?(?:CARTE\s+CADEAU|BILLET|BON|CHEQUE|CHÈQUE)\s+(.+)$"#,
            #"(?i)\bComment\s+utiliser\s+m(?:on|a)\s+E?[-\s]?(?:CARTE\s+CADEAU|BILLET|BON|CHEQUE|CHÈQUE)\s+(.+?)[\s?]*$"#
        ]

        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }

            for pattern in titlePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let nsLine = trimmedLine as NSString
                let range = NSRange(location: 0, length: nsLine.length)

                guard let match = regex.firstMatch(in: trimmedLine, range: range),
                      match.numberOfRanges > 1 else {
                    continue
                }

                let rawCandidate = nsLine.substring(with: match.range(at: 1))
                if let candidate = cleanStoreNameCandidate(rawCandidate) {
                    return candidate
                }
            }
        }

        return nil
    }

    /// Nettoie un candidat marchand sans l'ajouter à la liste des enseignes connues.
    private static func cleanStoreNameCandidate(_ rawCandidate: String) -> String? {
        var candidate = rawCandidate
            .replacingOccurrences(of: #"(?i)\bN[°º]\s*[A-Z0-9-]+\b"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"(?i)\bINCLUS\b.*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        candidate = candidate.trimmingCharacters(in: CharacterSet(charactersIn: " .:-–—?"))
        candidate = candidate.replacingOccurrences(
            of: #"(?i)^(?:DE|DU|DES|D'|L'|LA|LE|LES)\s+"#,
            with: "",
            options: .regularExpression
        )

        guard candidate.count >= 2 && candidate.count <= 60 else { return nil }
        guard candidate.rangeOfCharacter(from: .letters) != nil else { return nil }
        guard !isIgnoredIssuerName(candidate) else { return nil }

        return canonicalStoreName(for: candidate)
    }

    /// Normalise les formes OCR courantes vers les noms déjà utilisés par l'app.
    private static func canonicalStoreName(for candidate: String) -> String {
        let normalized = candidate
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: "&", with: " ET ")
            .replacingOccurrences(of: #"[^A-Z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized.contains("NATURE") && normalized.contains("DECOUVERTE") {
            return "Nature et Decouvertes"
        }

        return formatStoreName(candidate)
    }

    /// Certains noms présents dans les PDFs Reduc Factory décrivent l'émetteur ou le support,
    /// pas l'enseigne où le bon est utilisé.
    private static func isIgnoredIssuerName(_ name: String) -> Bool {
        let normalized = name
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let ignoredNames = [
            "REDUC FACTORY",
            "QWERTYS"
        ]

        return ignoredNames.contains(normalized)
    }

    private static func hasMatchingURL(for storeName: String, in uppercasedText: String) -> Bool {
        let normalizedStoreName = storeName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9]+"#, with: "", options: .regularExpression)

        let normalizedText = uppercasedText
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .uppercased()
            .replacingOccurrences(of: #"[^A-Z0-9.]+"#, with: "", options: .regularExpression)

        return normalizedText.contains("WWW.\(normalizedStoreName)")
            || normalizedText.contains("\(normalizedStoreName).FR")
            || normalizedText.contains("\(normalizedStoreName).COM")
    }
    
    /// Détecte le nom de l'enseigne en utilisant des heuristiques intelligentes
    /// - Returns: Tuple contenant le nom, la méthode et le contexte de détection
    private static func detectStoreNameByHeuristics(from text: String) -> (name: String, method: StoreNameLearning.DetectionMethod, context: StoreNameLearning.DetectionContext)? {
        let lines = text.components(separatedBy: .newlines)
        
        // Heuristique 1: Les 5 premières lignes contiennent souvent le nom de l'enseigne
        for (index, line) in lines.prefix(5).enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Ignorer les lignes trop courtes ou trop longues
            guard trimmedLine.count >= 3 && trimmedLine.count <= 50 else { continue }
            
            var context = StoreNameLearning.DetectionContext()
            context.isInFirstLines = true
            
            // Pattern 1: Ligne entièrement en majuscules (probable nom d'enseigne)
            if trimmedLine == trimmedLine.uppercased() && 
               trimmedLine.rangeOfCharacter(from: .letters) != nil {
                // Vérifier que ce n'est pas un mot générique
                let genericWords = ["BON", "CADEAU", "CHEQUE", "CARTE", "VOUCHER", "GIFT", "CARD", "CODE"]
                if !genericWords.contains(where: { trimmedLine.contains($0) }),
                   !isIgnoredIssuerName(trimmedLine) {
                    debugLog("  → Candidat ligne \(index + 1) (majuscules): \(trimmedLine)")
                    context.isAllUppercase = true
                    return (canonicalStoreName(for: trimmedLine), .uppercaseLine, context)
                }
            }
            
            // Pattern 2: Première ligne non-vide significative
            if index == 0 && trimmedLine.count >= 3 {
                let words = trimmedLine.split(separator: " ")
                // Si c'est 1-3 mots, probablement le nom
                if words.count <= 3 && words.allSatisfy({ $0.count >= 2 }),
                   !isIgnoredIssuerName(trimmedLine) {
                    debugLog("  → Candidat première ligne: \(trimmedLine)")
                    return (canonicalStoreName(for: trimmedLine), .firstLine, context)
                }
            }
        }
        
        var context = StoreNameLearning.DetectionContext()
        
        // Heuristique 2: Chercher des patterns de type "www.ENSEIGNE.com" ou "ENSEIGNE.com"
        let urlPattern = #/(?:www\.)?([A-Za-z][A-Za-z0-9-]+)\.(?:com|fr|net)/#
        if let match = text.firstMatch(of: urlPattern) {
            let domain = String(match.1)
            // Exclure les domaines génériques
            let genericDomains = ["carte", "cadeau", "bon", "voucher", "gift"]
            if !genericDomains.contains(domain.lowercased()),
               !isIgnoredIssuerName(domain) {
                debugLog("  → Candidat depuis URL: \(domain)")
                context.hasMatchingURL = true
                return (canonicalStoreName(for: domain), .urlExtraction, context)
            }
        }
        
        // Heuristique 3: Chercher "Enseigne : XXXX" ou "Store: XXXX"
        let storePattern = #/(?:Enseigne|Store|Magasin|Boutique)[\s:]+([A-Z][A-Za-z\s]{2,30})/#
        if let match = text.firstMatch(of: storePattern) {
            let storeName = String(match.1).trimmingCharacters(in: .whitespaces)
            if !isIgnoredIssuerName(storeName) {
                debugLog("  → Candidat depuis label 'Enseigne': \(storeName)")
                return (canonicalStoreName(for: storeName), .labeledStore, context)
            }
        }
        
        // Heuristique 4: Chercher des mots avec capitales (Title Case) au début
        let titleCasePattern = #/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b/#
        let matches = text.matches(of: titleCasePattern)
        
        for match in matches.prefix(10) {  // Limiter aux 10 premières occurrences
            let candidate = String(match.1)
            
            // Vérifier que ce n'est pas un mot trop générique
            let genericWords = ["Date", "Code", "Number", "Numero", "Valeur", "Montant", "Total", "Carte", "Bon"]
            if !genericWords.contains(where: { candidate.contains($0) }) &&
                candidate.count >= 4 &&
                !isIgnoredIssuerName(candidate) {
                debugLog("  → Candidat Title Case: \(candidate)")
                return (canonicalStoreName(for: candidate), .titleCase, context)
            }
        }
        
        return nil
    }
    
    /// Formate le nom de l'enseigne de manière cohérente
    private static func formatStoreName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si tout est en majuscules, convertir en Title Case
        if trimmed == trimmed.uppercased() {
            if trimmed.rangeOfCharacter(from: .decimalDigits) != nil {
                return trimmed
            }

            return trimmed.capitalized
        }
        
        // Sinon, conserver la casse d'origine
        return trimmed
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

    private static func storeColorHex(for storeName: String) -> String? {
        if let learnedColor = StoreNameLearning.shared.getLearnedColor(for: storeName) {
            return learnedColor
        }

        if let presetColor = StorePreset.presets[storeName] {
            return presetColor
        }

        for (preset, color) in StorePreset.presets where storeName.localizedCaseInsensitiveContains(preset) {
            return color
        }

        return nil
    }
}

enum PDFAnalyzerError: LocalizedError {
    case invalidPDF
    case invalidImage
    case analysisError
    
    var errorDescription: String? {
        switch self {
        case .invalidPDF:
            return "Le fichier PDF n'est pas valide"
        case .invalidImage:
            return "L'image sélectionnée n'est pas valide"
        case .analysisError:
            return "Erreur lors de l'analyse du PDF"
        }
    }
}
