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

/// Vue pour afficher une image originale importée en plein écran
struct OriginalImageViewerView: View {
    let imageData: Data
    var allowsSharing: Bool = true
    var masksWhenCaptured: Bool = false
    @Environment(\.dismiss) private var dismiss
    @State private var showingShareSheet = false
    @State private var isScreenCaptured = false

    private var image: UIImage? {
        UIImage(data: imageData)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ZoomableImageView(image: image)
                    .background(Color(.systemBackground))
                } else {
                    ContentUnavailableView(
                        "Image indisponible",
                        systemImage: "photo",
                        description: Text("L'image originale ne peut pas être affichée.")
                    )
                }
            }
            .navigationTitle("Image originale")
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
                ShareSheetView(items: [imageData])
            }
            .overlay {
                if masksWhenCaptured && isScreenCaptured {
                    ContentUnavailableView(
                        "Contenu masqué",
                        systemImage: "eye.slash.fill",
                        description: Text("L'image est masquée pendant la recopie ou l'enregistrement de l'écran.")
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

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = CenteredImageScrollView()
        scrollView.delegate = context.coordinator
        scrollView.backgroundColor = .systemBackground
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.bouncesZoom = true
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)
        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView
        scrollView.onLayout = { [weak coordinator = context.coordinator] scrollView in
            coordinator?.updateLayout(for: scrollView)
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        guard let imageView = context.coordinator.imageView else { return }

        imageView.image = image
        context.coordinator.updateLayout(for: scrollView)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var scrollView: UIScrollView?
        weak var imageView: UIImageView?
        private var lastBoundsSize: CGSize = .zero
        private var lastImageSize: CGSize = .zero

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
        }

        func updateLayout(for scrollView: UIScrollView) {
            guard let imageView, let image = imageView.image else { return }
            let boundsSize = scrollView.bounds.size
            guard boundsSize.width > 0, boundsSize.height > 0 else { return }

            if lastBoundsSize != boundsSize || lastImageSize != image.size {
                lastBoundsSize = boundsSize
                lastImageSize = image.size
                imageView.frame = CGRect(origin: .zero, size: image.size)
                scrollView.contentSize = image.size

                let widthScale = boundsSize.width / image.size.width
                let heightScale = boundsSize.height / image.size.height
                let minimumScale = min(widthScale, heightScale)

                scrollView.minimumZoomScale = minimumScale
                scrollView.maximumZoomScale = max(minimumScale * 5, minimumScale + 1)
                scrollView.zoomScale = minimumScale
            }

            centerImage(in: scrollView)
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let tapPoint = recognizer.location(in: imageView)
                let nextScale = min(scrollView.minimumZoomScale * 2.5, scrollView.maximumZoomScale)
                let size = CGSize(
                    width: scrollView.bounds.width / nextScale,
                    height: scrollView.bounds.height / nextScale
                )
                let origin = CGPoint(
                    x: tapPoint.x - size.width / 2,
                    y: tapPoint.y - size.height / 2
                )
                scrollView.zoom(to: CGRect(origin: origin, size: size), animated: true)
            }
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let horizontalInset = max((scrollView.bounds.width - imageView.frame.width) / 2, 0)
            let verticalInset = max((scrollView.bounds.height - imageView.frame.height) / 2, 0)
            scrollView.contentInset = UIEdgeInsets(
                top: verticalInset,
                left: horizontalInset,
                bottom: verticalInset,
                right: horizontalInset
            )
        }
    }
}

final class CenteredImageScrollView: UIScrollView {
    var onLayout: ((UIScrollView) -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?(self)
    }
}

#Preview {
    // Preview avec un PDF vide
    PDFViewerView(pdfData: Data())
}
