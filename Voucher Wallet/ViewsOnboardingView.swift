//
//  ViewsOnboardingView.swift
//  Voucher Wallet
//
//  Created by Codex on 19/05/2026.
//

import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var selectedPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Spacer()

                    Button {
                        finishOnboarding()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                            .frame(width: 44, height: 44)
                            .background(Color(.secondarySystemGroupedBackground), in: Circle())
                            .overlay {
                                Circle()
                                    .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                            }
                    }
                    .accessibilityLabel("Ignorer la démonstration")
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                TabView(selection: $selectedPage) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        OnboardingPageView(page: page)
                            .tag(index)
                            .padding(.horizontal, 24)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 18) {
                    pageIndicator

                    Button {
                        goToNextPage()
                    } label: {
                        Text(selectedPage == pages.count - 1 ? "Commencer" : "Suivant")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(.blue)

                    Button("Ignorer") {
                        finishOnboarding()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                    .opacity(selectedPage < pages.count - 1 ? 1 : 0)
                    .disabled(selectedPage == pages.count - 1)
                    .accessibilityHidden(selectedPage == pages.count - 1)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(pages.indices, id: \.self) { index in
                Capsule()
                    .fill(index == selectedPage ? Color.blue : Color(.tertiaryLabel).opacity(0.45))
                    .frame(width: index == selectedPage ? 24 : 8, height: 8)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedPage)
            }
        }
        .accessibilityLabel("Étape \(selectedPage + 1) sur \(pages.count)")
    }

    private func goToNextPage() {
        if selectedPage < pages.count - 1 {
            withAnimation(.easeInOut) {
                selectedPage += 1
            }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        SettingsManager.shared.markOnboardingAsSeen()
        onFinish()
    }
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 28) {
            Spacer(minLength: 12)

            pageIllustration
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)

                Text(page.message)
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .frame(maxWidth: 330)
            }

            Spacer(minLength: 20)
        }
    }

    @ViewBuilder
    private var pageIllustration: some View {
        switch page.kind {
        case .wallet:
            WalletIllustration()
        case .pdf:
            PDFImportIllustration()
        case .scan:
            ScanIllustration()
        case .checkout:
            CheckoutIllustration()
        case .widget:
            WidgetIllustration()
        case .customize:
            CustomizeIllustration()
        }
    }
}

private struct WalletIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(.blue.gradient)
                .frame(width: 245, height: 155)
                .rotationEffect(.degrees(-6))

            RoundedRectangle(cornerRadius: 26)
                .fill(.green.gradient)
                .frame(width: 245, height: 155)
                .rotationEffect(.degrees(5))
                .offset(x: 14, y: 18)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Bon cadeau")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "wallet.pass.fill")
                }

                Text("Fnac / Darty")
                    .font(.title2.weight(.bold))

                HStack {
                    Text("75,00 €")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Image(systemName: "qrcode")
                        .font(.title2)
                }
            }
            .foregroundStyle(.white)
            .padding(22)
            .frame(width: 245, height: 155)
            .background(.orange.gradient, in: RoundedRectangle(cornerRadius: 26))
            .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
        }
        .frame(height: 230)
    }
}

private struct PDFImportIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 210, height: 260)
                .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 12)

            VStack(spacing: 14) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.red)

                RoundedRectangle(cornerRadius: 5)
                    .fill(.secondary.opacity(0.35))
                    .frame(width: 116, height: 10)

                RoundedRectangle(cornerRadius: 5)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 142, height: 10)

                Label("Importer", systemImage: "square.and.arrow.down")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.blue, in: Capsule())
                    .padding(.top, 10)
            }
        }
        .frame(height: 280)
    }
}

private struct ScanIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 250, height: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "viewfinder")
                        .foregroundStyle(.blue)
                    Text("Analyse PDF")
                        .font(.headline)
                }

                extractedLine("Enseigne", value: "Decathlon")
                extractedLine("Montant", value: "50,00 €")
                extractedLine("Expiration", value: "31/12/2026")

                HStack(spacing: 4) {
                    ForEach(0..<12, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index.isMultiple(of: 3) ? Color.primary : Color.primary.opacity(0.45))
                            .frame(width: index.isMultiple(of: 2) ? 4 : 2, height: 44)
                    }
                }
                .padding(.top, 8)
            }
            .padding(22)
            .frame(width: 250, height: 220)
        }
        .frame(height: 260)
    }

    private func extractedLine(_ title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(Color(.secondaryLabel))
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

private struct CheckoutIllustration: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.green.opacity(0.22))
                .frame(width: 230, height: 230)

            VStack(spacing: 18) {
                Image(systemName: "barcode.viewfinder")
                    .font(.system(size: 76))
                    .foregroundStyle(.green)

                Text("Solde restant")
                    .font(.caption)
                    .foregroundStyle(Color(.secondaryLabel))

                Text("42,30 €")
                    .font(.title.weight(.bold))
            }
            .padding(28)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(.separator).opacity(0.3), lineWidth: 1)
            }
        }
        .frame(height: 260)
    }
}

private struct WidgetIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 32)
                .fill(Color(.secondarySystemGroupedBackground))
                .frame(width: 270, height: 230)
                .overlay {
                    RoundedRectangle(cornerRadius: 32)
                        .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.14), radius: 18, x: 0, y: 12)

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Favoris", systemImage: "star.fill")
                        .font(.headline)
                        .foregroundStyle(.yellow, Color(.label))

                    Spacer()

                    Image(systemName: "widget.small")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                    favoriteTile("Fnac", amount: "75 €", color: .orange)
                    favoriteTile("Ikea", amount: "40 €", color: .blue)
                    favoriteTile("Decathlon", amount: "25 €", color: .green)
                    favoriteTile("Sephora", amount: "60 €", color: .purple)
                }
            }
            .padding(20)
            .frame(width: 270, height: 230)
        }
        .frame(height: 260)
    }

    private func favoriteTile(_ store: String, amount: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "star.fill")
                    .font(.caption2)
            }

            Text(amount)
                .font(.headline.weight(.bold))
        }
        .foregroundStyle(.white)
        .padding(10)
        .frame(height: 70)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.gradient, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct CustomizeIllustration: View {
    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                colorSwatch(.blue)
                colorSwatch(.orange)
                colorSwatch(.green)
                colorSwatch(.purple)
            }

            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 24)
                    .fill(.purple.gradient)
                    .frame(width: 245, height: 155)

                Image(systemName: "star.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                    .padding(18)

                VStack(alignment: .leading, spacing: 20) {
                    Text("Votre style")
                        .font(.headline)
                    Text("Carte favorite")
                        .font(.title2.weight(.bold))
                    Text("Contraste validé")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(.white)
                .padding(22)
                .frame(width: 245, height: 155, alignment: .leading)
            }
            .frame(width: 245, height: 155)
            .shadow(color: .black.opacity(0.16), radius: 18, x: 0, y: 12)
        }
        .frame(height: 260)
    }

    private func colorSwatch(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 42, height: 42)
            .overlay {
                Circle()
                    .stroke(.white, lineWidth: 3)
            }
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}

private struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let kind: OnboardingIllustrationKind

    static let all = [
        OnboardingPage(
            title: "Bienvenue dans Mes bons d'achat",
            message: "Gardez vos bons d'achat au même endroit, prêts à être retrouvés quand vous en avez besoin.",
            kind: .wallet
        ),
        OnboardingPage(
            title: "Importez vos PDF",
            message: "Ajoutez un bon depuis Fichiers, Mail, Safari ou toute app capable de partager un PDF.",
            kind: .pdf
        ),
        OnboardingPage(
            title: "Laissez l'app analyser",
            message: "L'app Mes bons d'achat détecte les informations utiles et préremplit votre bon pour accélérer l'ajout.",
            kind: .scan
        ),
        OnboardingPage(
            title: "Présentez le code en caisse",
            message: "Affichez rapidement le code-barres ou le QR code. Touchez le code pour augmenter la luminosité.",
            kind: .checkout
        ),
        OnboardingPage(
            title: "Gardez vos favoris sous la main",
            message: "Ajoutez jusqu'à 4 bons en favoris pour les afficher dans le widget et les retrouver sans ouvrir l'app.",
            kind: .widget
        ),
        OnboardingPage(
            title: "Personnalisez vos cartes",
            message: "Choisissez les couleurs, marquez vos favoris et retrouvez vos bons les plus utiles en premier.",
            kind: .customize
        )
    ]
}

private enum OnboardingIllustrationKind {
    case wallet
    case pdf
    case scan
    case checkout
    case widget
    case customize
}

#Preview {
    OnboardingView { }
}
