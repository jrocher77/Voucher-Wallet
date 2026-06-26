//
//  ShareViewController.swift
//  VoucherShareExtension
//

import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private static let appGroupIdentifier = "group.com.jrocher77.voucherwallet"
    private static let incomingImageFileName = "IncomingSharedImage"
    private static let openImportURL = URL(string: "voucherwallet://import-shared-image")
    private static let maxImageByteCount = 25 * 1024 * 1024
    private static let preferredImageTypes: [UTType] = [
        .png
    ]

    private var didStartImport = false

    override func loadView() {
        view = LoadingView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartImport else { return }
        didStartImport = true
        importSharedImage()
    }

    private func importSharedImage() {
        guard let provider = extensionContext?
            .inputItems
            .compactMap({ $0 as? NSExtensionItem })
            .flatMap({ $0.attachments ?? [] })
            .first(where: { $0.hasItemConformingToTypeIdentifier(UTType.png.identifier) }) else {
            NSLog("[VoucherShareExtension] No PNG image provider found")
            finish()
            return
        }

        try? Self.removeSharedImageData()

        loadImageData(from: provider) { [weak self] imageData in
            guard let self, let imageData else {
                self?.finish()
                return
            }
            do {
                try Self.writeSharedImageData(imageData)
                self.finish()
            } catch {
                NSLog("[VoucherShareExtension] Shared image write failed: %@", error.localizedDescription)
                self.finish()
            }
        }

        openContainingApp()
    }

    private func loadImageData(from provider: NSItemProvider, completion: @escaping (Data?) -> Void) {
        let typeIdentifiers = Self.imageTypeIdentifiers(from: provider)
        loadDataRepresentation(from: provider, typeIdentifiers: typeIdentifiers, completion: completion)
    }

    private static func imageTypeIdentifiers(from provider: NSItemProvider) -> [String] {
        let registeredTypes = provider.registeredTypeIdentifiers
        let preferredTypes = preferredImageTypes.map(\.identifier)
        let concreteTypes = registeredTypes.filter { identifier in
            guard let type = UTType(identifier) else { return false }
            return type.conforms(to: .image)
        }

        var orderedTypes = preferredTypes.filter { preferredType in
            concreteTypes.contains(preferredType)
        }
        orderedTypes.append(contentsOf: concreteTypes.filter { !orderedTypes.contains($0) })

        return orderedTypes
    }

    private func loadDataRepresentation(
        from provider: NSItemProvider,
        typeIdentifiers: [String],
        completion: @escaping (Data?) -> Void
    ) {
        guard let typeIdentifier = typeIdentifiers.first else {
            completion(nil)
            return
        }

        provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { [weak self] data, error in
            if let data, Self.isAllowedImageData(data) {
                completion(data)
                return
            }

            if let error {
                NSLog(
                    "[VoucherShareExtension] loadDataRepresentation failed for %@: %@",
                    typeIdentifier,
                    error.localizedDescription
                )
            }

            self?.loadDataRepresentation(
                from: provider,
                typeIdentifiers: Array(typeIdentifiers.dropFirst()),
                completion: completion
            )
        }
    }

    private static func isAllowedImageData(_ data: Data) -> Bool {
        data.count <= maxImageByteCount
    }

    private static func writeSharedImageData(_ data: Data) throws {
        guard isAllowedImageData(data) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        let imageURL = try sharedImageURL()
        try data.write(to: imageURL, options: .atomic)
    }

    private static func removeSharedImageData() throws {
        let imageURL = try sharedImageURL()
        guard FileManager.default.fileExists(atPath: imageURL.path) else { return }
        try FileManager.default.removeItem(at: imageURL)
    }

    private static func sharedImageURL() throws -> URL {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            throw CocoaError(.fileNoSuchFile)
        }

        return containerURL.appendingPathComponent(incomingImageFileName)
    }

    private func openContainingApp() {
        guard let url = Self.openImportURL else {
            finish()
            return
        }

        DispatchQueue.main.async {
            if self.openContainingAppUsingResponderChain(url) {
                return
            }

            NSLog("[VoucherShareExtension] Responder chain failed to open containing app")
            self.finish()
        }
    }

    private func openContainingAppUsingResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        let applicationClass: AnyClass? = NSClassFromString("UIApplication")
        var responder = next

        while let currentResponder = responder {
            defer {
                responder = currentResponder.next
            }

            guard let applicationClass,
                  currentResponder.isKind(of: applicationClass),
                  currentResponder.responds(to: selector),
                  let method = currentResponder.method(for: selector) else {
                continue
            }

            typealias OpenURLFunction = @convention(c) (
                AnyObject,
                Selector,
                NSURL,
                NSDictionary,
                @escaping @convention(block) (Bool) -> Void
            ) -> Void

            let completion: @convention(block) (Bool) -> Void = { success in
                if !success {
                    NSLog("[VoucherShareExtension] Modern responder open returned false")
                }
            }

            let function = unsafeBitCast(method, to: OpenURLFunction.self)
            function(
                currentResponder,
                selector,
                url as NSURL,
                [:] as NSDictionary,
                completion
            )
            return true
        }

        return false
    }

    private func finish() {
        DispatchQueue.main.async {
            self.extensionContext?.completeRequest(returningItems: nil)
        }
    }
}

private final class LoadingView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        configure()
    }

    private func configure() {
        backgroundColor = .systemBackground

        let activityIndicator = UIActivityIndicatorView(style: .medium)
        activityIndicator.startAnimating()

        let label = UILabel()
        label.text = "Import de l'image..."
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .label
        label.textAlignment = .center

        let stackView = UIStackView(arrangedSubviews: [activityIndicator, label])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 12
        stackView.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
        ])
    }
}
