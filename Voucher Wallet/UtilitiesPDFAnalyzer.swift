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
        
        init(id: UUID = UUID(), pageNumber: Int, voucherNumber: String, codeType: CodeType, storeName: String? = nil, storeNameConfidence: Double = 0.0, amount: Double? = nil, pinCode: String? = nil, expirationDate: Date? = nil, codeImageData: Data? = nil) {
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
        
        await progressHandler?(.loading(message: "Chargement du PDF..."))
        
        guard let pdfDocument = PDFDocument(data: data) else {
            throw PDFAnalyzerError.invalidPDF
        }
        
        var result = AnalysisResult()
        
        print("📄 Analyse d'un PDF avec \(pdfDocument.pageCount) page(s)")
        
        let totalPages = pdfDocument.pageCount
        await progressHandler?(.loading(message: "PDF chargé (\(totalPages) page\(totalPages > 1 ? "s" : ""))"))
        
        // Analyser chaque page séparément
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }
            
            let currentPage = pageIndex + 1
            await progressHandler?(.analyzingPage(current: currentPage, total: totalPages))
            
            print("\n📃 Page \(currentPage)/\(totalPages)")
            
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
                print("✅ Bon détecté sur la page \(currentPage): \(voucher.voucherNumber)")
            }
        }
        
        // Si aucun bon individuel n'a été détecté, créer un résultat global
        if result.detectedVouchers.isEmpty {
            await progressHandler?(.extractingData(message: "Extraction des informations..."))
            
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
            
            // Détecter le nom de l'enseigne avec score de confiance
            let storeDetection = detectStoreName(from: allText)
            result.detectedStoreName = storeDetection.name
            result.storeNameConfidence = storeDetection.confidence
            result.detectionMethod = storeDetection.method
            
            print("✅ Numéros détectés: \(result.possibleVoucherNumbers)")
            print("🏪 Enseigne détectée: \(result.detectedStoreName ?? "Aucune") (confiance: \(String(format: "%.0f%%", result.storeNameConfidence * 100)))")
        } else {
            print("\n🎉 \(result.detectedVouchers.count) bon(s) détecté(s) au total")
        }
        
        await progressHandler?(.completed)
        
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
        await progressHandler?(.detectingBarcodes(pageNumber: pageNumber))
        let codes = try await detectBarcodes(in: pageImage)
        for code in codes {
            if code.symbology == .qr {
                pageResult.qrCodes.append(code)
            } else {
                pageResult.barcodes.append(code)
            }
        }
        
        // Effectuer l'OCR pour extraire le texte
        await progressHandler?(.performingOCR(pageNumber: pageNumber))
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
            
            let voucher = DetectedVoucher(
                pageNumber: pageNumber,
                voucherNumber: number,
                codeType: codeType,
                storeName: storeDetection.name,
                storeNameConfidence: storeDetection.confidence,
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
    
    /// Extrait les codes PIN possibles (1 à 10 chiffres)
    private static func extractPinCodes(from text: String) -> [String] {
        var pins: [String] = []
        
        // 1. Rechercher "Code PIN" ou "Code pin" (le plus spécifique)
        let codePinPattern = #/Code\s+(PIN|pin|Pin)[\s:]*(\d{1,10})(?!\d)/#
        let codePinMatches = text.matches(of: codePinPattern)
        for match in codePinMatches {
            let pinCode = String(match.2)
            pins.append(pinCode)
            print("📍 Code PIN détecté (pattern 'Code PIN'): \(pinCode)")
        }
        
        // 2. Rechercher "PIN" ou "pin" suivi de chiffres (moins spécifique)
        // Seulement si on n'a pas déjà trouvé de PIN avec le pattern précédent
        if pins.isEmpty {
            let pinPattern = #/(PIN|pin|Pin)[\s:]*(\d{1,10})(?!\d)/#
            let matches = text.matches(of: pinPattern)
            
            for match in matches {
                let pinCode = String(match.2)
                pins.append(pinCode)
                print("📍 Code PIN détecté (pattern 'PIN'): \(pinCode)")
            }
        }
        
        // 3. Rechercher "code secret" (utilisé par certaines enseignes)
        // Chercher les deux variantes de casse séparément
        let secretPatternLower = #/(code\s+secret|secret)[\s:]*(\d{1,10})(?!\d)/#
        let secretMatches = text.matches(of: secretPatternLower)
        for match in secretMatches {
            let pinCode = String(match.2)
            pins.append(pinCode)
            print("📍 Code PIN détecté (pattern 'code secret'): \(pinCode)")
        }
        
        let secretPatternUpper = #/(Code\s+Secret|Secret|CODE\s+SECRET|SECRET)[\s:]*(\d{1,10})(?!\d)/#
        let secretMatchesUpper = text.matches(of: secretPatternUpper)
        for match in secretMatchesUpper {
            let pinCode = String(match.2)
            pins.append(pinCode)
            print("📍 Code PIN détecté (pattern 'Code Secret'): \(pinCode)")
        }
        
        let uniquePins = Array(Set(pins))
        if !uniquePins.isEmpty {
            print("🔐 Codes PIN extraits: \(uniquePins)")
        }
        
        return uniquePins
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
    
    /// Détecte le nom de l'enseigne dans le texte avec score de confiance
    /// - Returns: Tuple contenant le nom, le score de confiance et la méthode de détection
    private static func detectStoreName(from text: String) -> (name: String?, confidence: Double, method: StoreNameLearning.DetectionMethod?) {
        let learning = StoreNameLearning.shared
        
        // Liste des enseignes connues (pour une détection prioritaire)
        let knownStores = [
            "Carrefour", "Decathlon", "Fnac", "Amazon", "Ikea",
            "Auchan", "Leclerc", "Boulanger", "Darty", "Intersport",
            "H&M", "Zara", "Sephora", "Galeries Lafayette", "Printemps",
            "King Jouet", "La Grande Récré", "Cultura", "Leroy Merlin",
            "Castorama", "Bricorama", "BUT", "Conforama", "Maisons du Monde"
        ]
        
        let uppercasedText = text.uppercased()
        let lines = text.components(separatedBy: .newlines)
        
        // Créer un contexte de détection
        var context = StoreNameLearning.DetectionContext()
        
        // 1. Recherche dans les enseignes connues (prioritaire)
        for storeName in knownStores {
            if uppercasedText.contains(storeName.uppercased()) {
                print("🏪 Enseigne connue trouvée: \(storeName)")
                
                // Enrichir le contexte
                context.hasMatchingURL = uppercasedText.contains(storeName.uppercased().replacingOccurrences(of: " ", with: ""))
                context.isInFirstLines = lines.prefix(5).contains { $0.uppercased().contains(storeName.uppercased()) }
                context.isAllUppercase = uppercasedText.contains(storeName.uppercased())
                
                let confidence = learning.calculateConfidenceScore(
                    for: storeName,
                    detectionMethod: .knownStore,
                    context: context
                )
                
                print("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (storeName, confidence, .knownStore)
            }
        }
        
        // 2. Recherche dans les enseignes apprises
        let learnedStores = learning.getLearnedStoreNames()
        for storeName in learnedStores {
            if uppercasedText.contains(storeName.uppercased()) {
                print("🏪 Enseigne apprise trouvée: \(storeName)")
                
                context.hasMatchingURL = uppercasedText.contains(storeName.uppercased().replacingOccurrences(of: " ", with: ""))
                context.isInFirstLines = lines.prefix(5).contains { $0.uppercased().contains(storeName.uppercased()) }
                context.isAllUppercase = uppercasedText.contains(storeName.uppercased())
                
                let confidence = learning.calculateConfidenceScore(
                    for: storeName,
                    detectionMethod: .learnedStore,
                    context: context
                )
                
                print("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (storeName, confidence, .learnedStore)
            }
        }
        
        // 3. Recherche de variations courantes
        let variations = [
            "E.LECLERC": "Leclerc",
            "E LECLERC": "Leclerc",
            "KING-JOUET": "King Jouet",
            "KING JOUET": "King Jouet"
        ]
        
        for (variant, storeName) in variations {
            if uppercasedText.contains(variant) {
                print("🏪 Enseigne trouvée (variation): \(storeName)")
                
                context.hasMatchingURL = false
                context.isInFirstLines = true
                context.isAllUppercase = true
                
                let confidence = learning.calculateConfidenceScore(
                    for: storeName,
                    detectionMethod: .knownStore,
                    context: context
                )
                
                print("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (storeName, confidence, .knownStore)
            }
        }
        
        // 4. Détection intelligente par heuristiques
        if let (detectedName, method, detectionContext) = detectStoreNameByHeuristics(from: text) {
            print("🏪 Enseigne détectée par heuristique: \(detectedName)")
            
            // Vérifier si ce nom a un mapping vers un nom validé
            if let validatedName = learning.findValidatedName(for: detectedName) {
                print("  🔗 Nom validé trouvé: \(validatedName)")
                
                let confidence = learning.calculateConfidenceScore(
                    for: validatedName,
                    detectionMethod: .learnedStore,
                    context: detectionContext
                )
                
                print("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
                return (validatedName, confidence, .learnedStore)
            }
            
            let confidence = learning.calculateConfidenceScore(
                for: detectedName,
                detectionMethod: method,
                context: detectionContext
            )
            
            print("  📊 Score de confiance: \(String(format: "%.0f%%", confidence * 100))")
            return (detectedName, confidence, method)
        }
        
        print("❌ Aucune enseigne détectée")
        return (nil, 0.0, nil)
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
            context.lineNumber = index
            
            // Pattern 1: Ligne entièrement en majuscules (probable nom d'enseigne)
            if trimmedLine == trimmedLine.uppercased() && 
               trimmedLine.rangeOfCharacter(from: .letters) != nil {
                // Vérifier que ce n'est pas un mot générique
                let genericWords = ["BON", "CADEAU", "CHEQUE", "CARTE", "VOUCHER", "GIFT", "CARD", "CODE"]
                if !genericWords.contains(where: { trimmedLine.contains($0) }) {
                    print("  → Candidat ligne \(index + 1) (majuscules): \(trimmedLine)")
                    context.isAllUppercase = true
                    return (formatStoreName(trimmedLine), .uppercaseLine, context)
                }
            }
            
            // Pattern 2: Première ligne non-vide significative
            if index == 0 && trimmedLine.count >= 3 {
                let words = trimmedLine.split(separator: " ")
                // Si c'est 1-3 mots, probablement le nom
                if words.count <= 3 && words.allSatisfy({ $0.count >= 2 }) {
                    print("  → Candidat première ligne: \(trimmedLine)")
                    return (formatStoreName(trimmedLine), .firstLine, context)
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
            if !genericDomains.contains(domain.lowercased()) {
                print("  → Candidat depuis URL: \(domain)")
                context.hasMatchingURL = true
                return (formatStoreName(domain), .urlExtraction, context)
            }
        }
        
        // Heuristique 3: Chercher "Enseigne : XXXX" ou "Store: XXXX"
        let storePattern = #/(?:Enseigne|Store|Magasin|Boutique)[\s:]+([A-Z][A-Za-z\s]{2,30})/#
        if let match = text.firstMatch(of: storePattern) {
            let storeName = String(match.1).trimmingCharacters(in: .whitespaces)
            print("  → Candidat depuis label 'Enseigne': \(storeName)")
            return (formatStoreName(storeName), .labeledStore, context)
        }
        
        // Heuristique 4: Chercher des mots avec capitales (Title Case) au début
        let titleCasePattern = #/\b([A-Z][a-z]+(?:\s+[A-Z][a-z]+){0,2})\b/#
        let matches = text.matches(of: titleCasePattern)
        
        for match in matches.prefix(10) {  // Limiter aux 10 premières occurrences
            let candidate = String(match.1)
            
            // Vérifier que ce n'est pas un mot trop générique
            let genericWords = ["Date", "Code", "Number", "Numero", "Valeur", "Montant", "Total", "Carte", "Bon"]
            if !genericWords.contains(where: { candidate.contains($0) }) && candidate.count >= 4 {
                print("  → Candidat Title Case: \(candidate)")
                return (candidate, .titleCase, context)
            }
        }
        
        return nil
    }
    
    /// Formate le nom de l'enseigne de manière cohérente
    private static func formatStoreName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Si tout est en majuscules, convertir en Title Case
        if trimmed == trimmed.uppercased() {
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
