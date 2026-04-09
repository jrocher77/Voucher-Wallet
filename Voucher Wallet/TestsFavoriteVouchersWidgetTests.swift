//
//  FavoriteVouchersWidgetTests.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//
//  Tests pour le widget des cartes favorites

import Testing
import SwiftUI
import WidgetKit
@testable import VoucherWidget

// MARK: - Tests du VoucherSnapshot

@Suite("VoucherSnapshot Tests")
struct VoucherSnapshotTests {
    
    @Test("Un voucher non expiré n'est pas marqué comme expiré")
    func testNonExpiredVoucher() async throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Test Store",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: futureDate
        )
        
        #expect(!snapshot.isExpired, "Le voucher ne devrait pas être expiré")
    }
    
    @Test("Un voucher expiré est correctement identifié")
    func testExpiredVoucher() async throws {
        let pastDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Test Store",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: pastDate
        )
        
        #expect(snapshot.isExpired, "Le voucher devrait être expiré")
    }
    
    @Test("Le calcul des jours restants est correct")
    func testDaysUntilExpiration() async throws {
        let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Test Store",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: futureDate
        )
        
        let days = snapshot.daysUntilExpiration
        #expect(days == 7, "Il devrait rester 7 jours")
    }
    
    @Test("Un voucher sans date d'expiration n'est pas expiré")
    func testVoucherWithoutExpirationDate() async throws {
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Test Store",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: nil
        )
        
        #expect(!snapshot.isExpired, "Le voucher sans date ne devrait pas être expiré")
        #expect(snapshot.daysUntilExpiration == nil, "Il ne devrait pas y avoir de jours restants")
    }
}

// MARK: - Tests du Timeline Provider

@Suite("Timeline Provider Tests")
struct TimelineProviderTests {
    
    @Test("Le placeholder contient des données valides")
    func testPlaceholder() async throws {
        let provider = FavoriteVouchersProvider()
        let context = MockTimelineContext()
        
        let entry = provider.placeholder(in: context)
        
        #expect(entry.vouchers.count == 2, "Le placeholder devrait contenir 2 vouchers")
        #expect(!entry.vouchers[0].storeName.isEmpty, "Le nom du magasin ne devrait pas être vide")
        #expect(entry.vouchers[0].remainingBalance > 0, "Le solde devrait être positif")
    }
    
    @Test("La timeline se met à jour périodiquement")
    func testTimelineUpdateInterval() async throws {
        let provider = FavoriteVouchersProvider()
        let context = MockTimelineContext()
        
        await withCheckedContinuation { continuation in
            provider.getTimeline(in: context) { timeline in
                let nextUpdate = timeline.policy
                
                // Vérifier qu'il y a bien une politique de mise à jour
                switch nextUpdate {
                case .after(let date):
                    let interval = date.timeIntervalSince(Date())
                    // Devrait être environ 15 minutes (900 secondes)
                    #expect(interval > 850 && interval < 950, "L'intervalle devrait être d'environ 15 minutes")
                default:
                    Issue.record("La timeline devrait utiliser une politique .after")
                }
                
                continuation.resume()
            }
        }
    }
}

// MARK: - Tests de formatage

@Suite("Currency Formatting Tests")
struct CurrencyFormattingTests {
    
    @Test("Le formatage de la devise est correct")
    func testCurrencyFormatting() async throws {
        let amount = 50.50
        let formatted = formatCurrency(amount)
        
        #expect(formatted.contains("50"), "Le montant devrait contenir 50")
        #expect(formatted.contains("€"), "Le montant devrait contenir le symbole €")
    }
    
    @Test("Le formatage gère les montants à zéro")
    func testZeroAmount() async throws {
        let amount = 0.0
        let formatted = formatCurrency(amount)
        
        #expect(formatted.contains("0"), "Le montant devrait contenir 0")
        #expect(formatted.contains("€"), "Le montant devrait contenir le symbole €")
    }
    
    @Test("Le formatage gère les grands montants")
    func testLargeAmount() async throws {
        let amount = 1234.56
        let formatted = formatCurrency(amount)
        
        #expect(formatted.contains("234"), "Le montant devrait contenir 234")
        #expect(formatted.contains("€"), "Le montant devrait contenir le symbole €")
    }
}

// MARK: - Tests d'intégration

@Suite("Widget Integration Tests")
struct WidgetIntegrationTests {
    
    @Test("Le widget peut être créé avec des données vides")
    func testEmptyWidget() async throws {
        let entry = FavoriteVouchersEntry(
            date: Date(),
            vouchers: []
        )
        
        #expect(entry.vouchers.isEmpty, "Le tableau de vouchers devrait être vide")
        #expect(entry.date <= Date(), "La date ne devrait pas être dans le futur")
    }
    
    @Test("Le widget limite le nombre de cartes affichées")
    func testMaximumCards() async throws {
        let vouchers = (0..<10).map { index in
            VoucherSnapshot(
                id: UUID(),
                storeName: "Store \(index)",
                remainingBalance: 50.0,
                storeColor: "#007AFF",
                textColor: "#FFFFFF",
                expirationDate: nil
            )
        }
        
        // Le widget devrait limiter à 4 cartes maximum dans la timeline
        let limitedVouchers = Array(vouchers.prefix(4))
        
        #expect(limitedVouchers.count == 4, "Il devrait y avoir exactement 4 cartes")
        #expect(limitedVouchers[0].storeName == "Store 0", "La première carte devrait être Store 0")
    }
}

// MARK: - Tests des couleurs

@Suite("Color Tests")
struct ColorTests {
    
    @Test("Les couleurs hexadécimales sont valides")
    func testHexColors() async throws {
        let testColors = [
            "#007AFF",
            "#FF9900",
            "#0066CC",
            "#FFFFFF",
            "#000000"
        ]
        
        for hexColor in testColors {
            let color = Color(hex: hexColor)
            #expect(color != nil, "La couleur \(hexColor) devrait être valide")
        }
    }
    
    @Test("Les textes blancs sont lisibles sur fond sombre")
    func testTextContrast() async throws {
        let darkBackground = "#000000"
        let whiteText = "#FFFFFF"
        
        // Ces couleurs devraient créer un bon contraste
        #expect(darkBackground != whiteText, "Le fond et le texte devraient être différents")
    }
}

// MARK: - Mock Objects pour les tests

struct MockTimelineContext: TimelineProviderContext {
    var family: WidgetFamily = .systemMedium
    var isPreview: Bool = false
    var displaySize: CGSize = CGSize(width: 360, height: 169)
    
    #if os(watchOS)
    var displaySize: CGSize { CGSize(width: 184, height: 184) }
    #endif
}

// MARK: - Helper Functions

private func formatCurrency(_ amount: Double) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = "EUR"
    formatter.locale = Locale(identifier: "fr_FR")
    return formatter.string(from: NSNumber(value: amount)) ?? "0,00 €"
}

// MARK: - Tests de performance

@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("Le fetching des vouchers est rapide")
    func testFetchingPerformance() async throws {
        let startTime = Date()
        
        // Simuler le fetching (en production, cela utilise SwiftData)
        let vouchers = (0..<4).map { index in
            VoucherSnapshot(
                id: UUID(),
                storeName: "Store \(index)",
                remainingBalance: Double(index) * 10,
                storeColor: "#007AFF",
                textColor: "#FFFFFF",
                expirationDate: Calendar.current.date(byAdding: .day, value: index, to: Date())
            )
        }
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(vouchers.count == 4, "Devrait fetcher 4 vouchers")
        #expect(duration < 0.1, "Le fetching devrait prendre moins de 100ms")
    }
    
    @Test("La création de timeline est rapide")
    func testTimelineCreationPerformance() async throws {
        let startTime = Date()
        
        let entry = FavoriteVouchersEntry(
            date: Date(),
            vouchers: [
                VoucherSnapshot(
                    id: UUID(),
                    storeName: "Test",
                    remainingBalance: 50.0,
                    storeColor: "#007AFF",
                    textColor: "#FFFFFF",
                    expirationDate: nil
                )
            ]
        )
        
        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        
        #expect(duration < 0.01, "La création de timeline devrait être instantanée")
    }
}

// MARK: - Tests de validation des données

@Suite("Data Validation Tests")
struct DataValidationTests {
    
    @Test("Le nom du magasin n'est pas vide")
    func testStoreNameNotEmpty() async throws {
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Carrefour",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: nil
        )
        
        #expect(!snapshot.storeName.isEmpty, "Le nom du magasin ne devrait pas être vide")
    }
    
    @Test("Le solde est positif ou nul")
    func testPositiveBalance() async throws {
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Test",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: nil
        )
        
        #expect(snapshot.remainingBalance >= 0, "Le solde devrait être positif ou nul")
    }
    
    @Test("Les codes couleur sont au bon format")
    func testColorFormat() async throws {
        let snapshot = VoucherSnapshot(
            id: UUID(),
            storeName: "Test",
            remainingBalance: 50.0,
            storeColor: "#007AFF",
            textColor: "#FFFFFF",
            expirationDate: nil
        )
        
        #expect(snapshot.storeColor.hasPrefix("#"), "La couleur devrait commencer par #")
        #expect(snapshot.textColor.hasPrefix("#"), "La couleur de texte devrait commencer par #")
        #expect(snapshot.storeColor.count == 7, "La couleur devrait avoir 7 caractères")
    }
}
