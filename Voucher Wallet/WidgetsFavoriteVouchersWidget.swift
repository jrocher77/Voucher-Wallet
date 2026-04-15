//
//  FavoriteVouchersWidget.swift
//  Voucher Wallet
//
//  Created by JEREMY on 09/04/2026.
//
//  Widget pour afficher les cartes favorites

import WidgetKit
import SwiftUI
import SwiftData
import AppIntents

// MARK: - App Intent pour ouvrir un voucher

struct OpenVoucherIntent: AppIntent {
    static var title: LocalizedStringResource = "Ouvrir un bon"
    static var openAppWhenRun: Bool = true
    
    @Parameter(title: "Voucher ID")
    var voucherID: String
    
    init() {
        self.voucherID = ""
    }
    
    init(voucherID: String) {
        self.voucherID = voucherID
    }
    
    func perform() async throws -> some IntentResult {
        print("🎯 OpenVoucherIntent appelé pour: \(voucherID)")
        
        // Stocker l'ID dans UserDefaults partagé
        if let userDefaults = UserDefaults(suiteName: SharedModelContainer.appGroupIdentifier) {
            userDefaults.set(voucherID, forKey: "selectedVoucherID")
            userDefaults.synchronize()
            print("✅ Voucher ID stocké: \(voucherID)")
        }
        
        return .result()
    }
}

// MARK: - Widget Configuration

struct FavoriteVouchersWidget: Widget {
    let kind: String = "FavoriteVouchersWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FavoriteVouchersProvider()) { entry in
            FavoriteVouchersWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .contentMarginsDisabled()
        .configurationDisplayName("Mes bons d'achat favoris")
        .description("Affiche vos cartes de fidélité et bons d'achat favoris.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

// MARK: - Timeline Entry

struct FavoriteVouchersEntry: TimelineEntry {
    let date: Date
    let vouchers: [VoucherSnapshot]
}

// MARK: - Voucher Snapshot (pour le widget)

struct VoucherSnapshot: Identifiable {
    let id: UUID
    let storeName: String
    let remainingBalance: Double
    let originalAmount: Double?
    let totalExpenses: Double
    let storeColor: String
    let textColor: String
    let expirationDate: Date?
    
    var isExpired: Bool {
        guard let expirationDate else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDay = calendar.startOfDay(for: expirationDate)
        return expirationDay < today
    }
    
    var daysUntilExpiration: Int? {
        guard let expirationDate else { return nil }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let expirationDay = calendar.startOfDay(for: expirationDate)
        return calendar.dateComponents([.day], from: today, to: expirationDay).day
    }
}

// MARK: - Timeline Provider

struct FavoriteVouchersProvider: TimelineProvider {
    typealias Entry = FavoriteVouchersEntry
    
    func placeholder(in context: Context) -> FavoriteVouchersEntry {
        FavoriteVouchersEntry(
            date: Date(),
            vouchers: [
                VoucherSnapshot(
                    id: UUID(),
                    storeName: "Carrefour",
                    remainingBalance: 50.0,
                    originalAmount: 50.0,
                    totalExpenses: 0,
                    storeColor: "#0066CC",
                    textColor: "#FFFFFF",
                    expirationDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())
                ),
                VoucherSnapshot(
                    id: UUID(),
                    storeName: "Decathlon",
                    remainingBalance: 100.0,
                    originalAmount: 100.0,
                    totalExpenses: 0,
                    storeColor: "#0082C3",
                    textColor: "#FFFFFF",
                    expirationDate: Calendar.current.date(byAdding: .day, value: 60, to: Date())
                )
            ]
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (FavoriteVouchersEntry) -> Void) {
        let entry: FavoriteVouchersEntry
        
        if context.isPreview {
            entry = placeholder(in: context)
        } else {
            entry = FavoriteVouchersEntry(
                date: Date(),
                vouchers: fetchFavoriteVouchers()
            )
        }
        
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<FavoriteVouchersEntry>) -> Void) {
        let currentDate = Date()
        let vouchers = fetchFavoriteVouchers()
        
        let entry = FavoriteVouchersEntry(
            date: currentDate,
            vouchers: vouchers
        )
        
        // Mise à jour toutes les 15 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
    
    // Fonction pour récupérer les vouchers favoris depuis SwiftData
    private func fetchFavoriteVouchers() -> [VoucherSnapshot] {
        do {
            // Utiliser le container partagé via App Group
            let container = try SharedModelContainer.create()
            let context = ModelContext(container)
            
            let descriptor = FetchDescriptor<Voucher>(
                predicate: #Predicate { $0.isFavorite == true },
                sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
            )
            
            let vouchers = try context.fetch(descriptor)
            
            print("🔍 Widget: Trouvé \(vouchers.count) cartes favorites")
            
            let snapshots = vouchers.prefix(4).map { voucher in
                VoucherSnapshot(
                    id: voucher.id,
                    storeName: voucher.storeName,
                    remainingBalance: voucher.remainingBalance,
                    originalAmount: voucher.amount,
                    totalExpenses: voucher.totalExpenses,
                    storeColor: voucher.storeColor,
                    textColor: voucher.textColor,
                    expirationDate: voucher.expirationDate
                )
            }
            
            print("📊 Widget: Retourne \(snapshots.count) snapshots")
            for snapshot in snapshots {
                print("   - \(snapshot.storeName): \(snapshot.remainingBalance)€")
            }
            
            return snapshots
        } catch {
            print("❌ Erreur lors de la récupération des vouchers favoris: \(error)")
            return []
        }
    }
}

// MARK: - Widget View

struct FavoriteVouchersWidgetView: View {
    @Environment(\.widgetFamily) var widgetFamily
    let entry: FavoriteVouchersEntry
    private let compactCardsRowHeight: CGFloat = 132
    
    var body: some View {
        if entry.vouchers.isEmpty {
            emptyStateView
        } else {
            switch widgetFamily {
            case .systemMedium:
                mediumWidgetView
            case .systemLarge:
                largeWidgetView
            default:
                mediumWidgetView
            }
        }
    }
    
    // Vue pour état vide
    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Image(systemName: "star.slash")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            
            Text("Aucune carte favorite")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text("Ajoutez des favoris dans l'app")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // Vue pour widget moyen (2 cartes)
    private var mediumWidgetView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView
            
            HStack(spacing: 8) {
                ForEach(entry.vouchers.prefix(2), id: \.id) { voucher in
                    if let deepLink = voucherDeepLinkURL(for: voucher) {
                        Link(destination: deepLink) {
                            WidgetVoucherCardView(voucher: voucher)
                                .frame(maxWidth: .infinity)
                                .containerBackground(for: .widget) {
                                    Color.clear
                                }
                        }
                        .buttonStyle(.plain)
                    } else {
                        WidgetVoucherCardView(voucher: voucher)
                            .frame(maxWidth: .infinity)
                            .containerBackground(for: .widget) {
                                Color.clear
                            }
                    }
                }
                
                // Si une seule carte, ajouter un espace vide pour équilibrer
                if entry.vouchers.count == 1 {
                    Color.clear
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }
    
    // Vue pour widget large (4 cartes en grille)
    private var largeWidgetView: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerView

            if entry.vouchers.count <= 2 {
                HStack(spacing: 8) {
                    ForEach(entry.vouchers.prefix(2), id: \.id) { voucher in
                        if let deepLink = voucherDeepLinkURL(for: voucher) {
                            Link(destination: deepLink) {
                                WidgetVoucherCardView(voucher: voucher)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.plain)
                        } else {
                            WidgetVoucherCardView(voucher: voucher)
                                .frame(maxWidth: .infinity)
                        }
                    }

                    if entry.vouchers.count == 1 {
                        Color.clear.frame(maxWidth: .infinity)
                    }
                }
                .frame(height: compactCardsRowHeight)
                .padding(.horizontal, 12)
                .padding(.top, 2)
                .padding(.bottom, 12)

                Spacer(minLength: 0)
            } else {
                VStack(spacing: 8) {
                    // Première ligne (2 cartes)
                    HStack(spacing: 8) {
                        ForEach(entry.vouchers.prefix(2), id: \.id) { voucher in
                            if let deepLink = voucherDeepLinkURL(for: voucher) {
                                Link(destination: deepLink) {
                                    WidgetVoucherCardView(voucher: voucher)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            } else {
                                WidgetVoucherCardView(voucher: voucher)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)

                    // Deuxième ligne (2 cartes supplémentaires)
                    HStack(spacing: 8) {
                        ForEach(Array(entry.vouchers.dropFirst(2).prefix(2)), id: \.id) { voucher in
                            if let deepLink = voucherDeepLinkURL(for: voucher) {
                                Link(destination: deepLink) {
                                    WidgetVoucherCardView(voucher: voucher)
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.plain)
                            } else {
                                WidgetVoucherCardView(voucher: voucher)
                                    .frame(maxWidth: .infinity)
                            }
                        }

                        // Remplir avec espace vide si seulement 3 cartes
                        if entry.vouchers.count == 3 {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }
    
    // En-tête du widget
    private var headerView: some View {
        HStack {
            Image(systemName: "star.fill")
                .foregroundStyle(.yellow)
            Text("Mes bons d'achat favoris")
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 10)
    }
    
    private func voucherDeepLinkURL(for voucher: VoucherSnapshot) -> URL? {
        var components = URLComponents()
        components.scheme = "voucherwallet"
        components.host = "voucher"
        components.path = "/\(voucher.id.uuidString)"
        return components.url
    }
}

// MARK: - Widget Voucher Card View

struct WidgetVoucherCardView: View {
    let voucher: VoucherSnapshot
    
    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: 4) {
                // Nom de l'enseigne
                Text(voucher.storeName)
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
                    .foregroundStyle(Color(hex: voucher.textColor))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                
                Spacer(minLength: 0)
                
                // Solde restant
                VStack(alignment: .leading, spacing: 2) {
                    Text("Solde")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(Color(hex: voucher.textColor).opacity(0.8))
                    
                    Text(formatCurrency(voucher.remainingBalance))
                        .font(.system(.title3, design: .rounded))
                        .fontWeight(.bold)
                        .foregroundStyle(Color(hex: voucher.textColor))
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)

                    if voucher.totalExpenses > 0, let originalAmount = voucher.originalAmount {
                        Text("sur \(formatCurrency(originalAmount))")
                            .font(.system(.caption2, design: .rounded))
                            .foregroundStyle(Color(hex: voucher.textColor).opacity(0.75))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                }
                
                // Badge d'expiration affiché en permanence si une date existe
                if let daysLeft = voucher.daysUntilExpiration {
                    expirationBadge(daysLeft: daysLeft)
                }
            }
            .padding(8)
            .frame(width: geometry.size.width, height: geometry.size.height)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: voucher.storeColor))
            )
        }
    }
    
    @ViewBuilder
    private func expirationBadge(daysLeft: Int) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .font(.system(size: 8))
            
            if daysLeft < 0 {
                Text("Expiré")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            } else {
                Text(daysRemainingText(for: daysLeft))
                    .font(.system(size: 9, weight: .medium, design: .rounded))
            }
        }
        .foregroundStyle(daysLeft <= 0 ? .white : Color(hex: voucher.textColor))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(daysLeft <= 0 ? .red : Color(hex: voucher.textColor).opacity(0.2))
        )
    }

    private func daysRemainingText(for daysLeft: Int) -> String {
        if daysLeft == 0 {
            return "Expire aujourd'hui"
        }
        if daysLeft == 1 {
            return "\(daysLeft) jour restant"
        }
        return "\(daysLeft) jours restants"
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "fr_FR")
        return formatter.string(from: NSNumber(value: amount)) ?? "0,00 €"
    }
}

// MARK: - Preview

#Preview(as: .systemMedium) {
    FavoriteVouchersWidget()
} timeline: {
    FavoriteVouchersEntry(
        date: Date(),
        vouchers: [
            VoucherSnapshot(
                id: UUID(),
                storeName: "Carrefour",
                remainingBalance: 50.0,
                originalAmount: 80.0,
                totalExpenses: 30.0,
                storeColor: "#0066CC",
                textColor: "#FFFFFF",
                expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())
            ),
            VoucherSnapshot(
                id: UUID(),
                storeName: "Decathlon",
                remainingBalance: 100.0,
                originalAmount: 100.0,
                totalExpenses: 0.0,
                storeColor: "#0082C3",
                textColor: "#FFFFFF",
                expirationDate: Calendar.current.date(byAdding: .day, value: 60, to: Date())
            )
        ]
    )
    
    FavoriteVouchersEntry(
        date: Date(),
        vouchers: []
    )
}

#Preview(as: .systemLarge) {
    FavoriteVouchersWidget()
} timeline: {
    FavoriteVouchersEntry(
        date: Date(),
        vouchers: [
            VoucherSnapshot(
                id: UUID(),
                storeName: "Carrefour",
                remainingBalance: 50.0,
                originalAmount: 80.0,
                totalExpenses: 30.0,
                storeColor: "#0066CC",
                textColor: "#FFFFFF",
                expirationDate: Calendar.current.date(byAdding: .day, value: 5, to: Date())
            ),
            VoucherSnapshot(
                id: UUID(),
                storeName: "Decathlon",
                remainingBalance: 100.0,
                originalAmount: 100.0,
                totalExpenses: 0.0,
                storeColor: "#0082C3",
                textColor: "#FFFFFF",
                expirationDate: Calendar.current.date(byAdding: .day, value: 60, to: Date())
            ),
            VoucherSnapshot(
                id: UUID(),
                storeName: "Fnac",
                remainingBalance: 25.0,
                originalAmount: 50.0,
                totalExpenses: 25.0,
                storeColor: "#F39200",
                textColor: "#FFFFFF",
                expirationDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
            ),
            VoucherSnapshot(
                id: UUID(),
                storeName: "Amazon",
                remainingBalance: 75.0,
                originalAmount: 75.0,
                totalExpenses: 0.0,
                storeColor: "#FF9900",
                textColor: "#000000",
                expirationDate: Calendar.current.date(byAdding: .month, value: 6, to: Date())
            )
        ]
    )
}
