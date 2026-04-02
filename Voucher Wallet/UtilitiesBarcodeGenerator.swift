//
//  BarcodeGenerator.swift
//  Voucher Wallet
//
//  Created by JEREMY on 02/04/2026.
//

import UIKit
import CoreImage.CIFilterBuiltins

/// Générateur de codes-barres et QR codes
struct BarcodeGenerator {
    
    /// Génère une image de QR code à partir d'une chaîne
    static func generateQRCode(from string: String) -> UIImage? {
        print("📱 Génération QR code pour: \(string)")
        
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        guard let data = string.data(using: .utf8) else {
            print("❌ Impossible de convertir en UTF-8")
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel") // Haute correction d'erreur
        
        guard let outputImage = filter.outputImage else {
            print("❌ Échec de génération du QR code")
            return nil
        }
        
        // Agrandir beaucoup pour une très haute qualité
        let scale: CGFloat = 20.0 // Plus grand pour une meilleure scannabilité
        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            print("❌ Échec de création de l'image")
            return nil
        }
        
        print("✅ QR code généré avec succès (taille: \(scaledImage.extent.width) x \(scaledImage.extent.height))")
        return UIImage(cgImage: cgImage)
    }
    
    /// Génère une image de code-barres (Code128) à partir d'une chaîne
    static func generateBarcode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        
        // Nettoyer la chaîne: enlever les espaces et caractères spéciaux
        let cleanString = string.replacingOccurrences(of: " ", with: "")
                                .replacingOccurrences(of: "-", with: "")
        
        print("🔢 Génération code-barres pour: \(cleanString)")
        
        guard let data = cleanString.data(using: .ascii) else {
            print("❌ Impossible de convertir en ASCII: \(cleanString)")
            return nil
        }
        
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0, forKey: "inputQuietSpace") // Espace autour du code
        
        guard let outputImage = filter.outputImage else {
            print("❌ Échec de génération du code-barres")
            return nil
        }
        
        // Agrandir beaucoup plus pour une meilleure scannabilité
        let scaleX = 5.0  // Largeur augmentée
        let scaleY = 150.0 // Hauteur augmentée pour faciliter le scan
        let transform = CGAffineTransform(scaleX: scaleX, y: scaleY)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            print("❌ Échec de création de l'image")
            return nil
        }
        
        print("✅ Code-barres généré avec succès (taille: \(scaledImage.extent.width) x \(scaledImage.extent.height))")
        return UIImage(cgImage: cgImage)
    }
    
    /// Génère le code approprié selon le type
    static func generateCode(for voucher: Voucher) -> UIImage? {
        switch voucher.codeType {
        case .qrCode:
            return generateQRCode(from: voucher.voucherNumber)
        case .barcode:
            return generateBarcode(from: voucher.voucherNumber)
        }
    }
    
    /// Convertit UIImage en Data pour stockage
    static func imageToData(_ image: UIImage) -> Data? {
        return image.pngData()
    }
    
    /// Convertit Data en UIImage
    static func dataToImage(_ data: Data) -> UIImage? {
        return UIImage(data: data)
    }
}
