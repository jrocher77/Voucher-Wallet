import AppKit

private let width: CGFloat = 1242
private let height: CGFloat = 2688

private struct Palette {
    let top: NSColor
    let middle: NSColor
    let bottom: NSColor
    let pillStart: NSColor
    let pillEnd: NSColor
    let pillText: NSColor
    let title: NSColor
    let subtitle: NSColor
    let accent: NSColor
}

private struct Poster {
    let output: String
    let source: String
    let titleLines: [String]
    let subtitle: String
    let chip: String
    let palette: Palette
    let decoration: (NSGraphicsContext) -> Void
}

private func color(_ hex: UInt, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

private func rectFromTop(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect {
    NSRect(x: x, y: height - y - h, width: w, height: h)
}

private func ovalFromTop(_ centerX: CGFloat, _ centerY: CGFloat, _ diameter: CGFloat) -> NSRect {
    rectFromTop(centerX - diameter / 2, centerY - diameter / 2, diameter, diameter)
}

private func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}

private func text(
    _ value: String,
    x: CGFloat,
    top: CGFloat,
    size: CGFloat,
    weight: NSFont.Weight,
    color: NSColor,
    kern: CGFloat = 0
) {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .kern: kern
    ]
    let string = NSAttributedString(string: value, attributes: attributes)
    string.draw(at: NSPoint(x: x, y: height - top - string.size().height))
}

private func drawBackground(_ palette: Palette) {
    let background = NSGradient(colors: [palette.bottom, palette.middle, palette.top])!
    background.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)
}

private func drawBrandPill(_ palette: Palette) {
    let label = "VOUCHER WALLET"
    let font = NSFont.systemFont(ofSize: 29, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: palette.pillText,
        .kern: 2.5
    ]
    let string = NSAttributedString(string: label, attributes: attributes)
    let horizontalPadding: CGFloat = 36
    let pillWidth = ceil(string.size().width + horizontalPadding * 2)
    let pill = rectFromTop(78, 88, pillWidth, 70)
    let gradient = NSGradient(colors: [palette.pillEnd, palette.pillStart])!
    let path = NSBezierPath(roundedRect: pill, xRadius: 35, yRadius: 35)
    gradient.draw(in: path, angle: 0)
    let textX = pill.minX + (pill.width - string.size().width) / 2
    let textY = pill.minY + (pill.height - string.size().height) / 2
    string.draw(at: NSPoint(x: textX, y: textY))
}

private func drawPhone(with sourceURL: URL) throws {
    let frame = rectFromTop(94, 778, 1054, 2290)
    let bezel = rectFromTop(115, 799, 1012, 2248)
    let screen = rectFromTop(130, 814, 982, 2130)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0x633016, alpha: 0.25)
    shadow.shadowBlurRadius = 70
    shadow.shadowOffset = NSSize(width: 0, height: -34)
    shadow.set()
    roundedRect(frame, radius: 145, fill: color(0x2b211d))
    NSGraphicsContext.restoreGraphicsState()

    roundedRect(bezel, radius: 126, fill: .white)

    guard let image = NSImage(contentsOf: sourceURL) else {
        throw NSError(domain: "VoucherWalletPoster", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Impossible de charger \(sourceURL.path)"
        ])
    }

    NSGraphicsContext.saveGraphicsState()
    NSBezierPath(roundedRect: screen, xRadius: 112, yRadius: 112).addClip()
    image.draw(in: screen, from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
}

private func export(_ poster: Poster, sources: URL, exports: URL) throws {
    guard
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(width),
            pixelsHigh: Int(height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ),
        let context = NSGraphicsContext(bitmapImageRep: bitmap)
    else {
        throw NSError(domain: "VoucherWalletPoster", code: 2)
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.restoreGraphicsState() }

    context.imageInterpolation = .high
    drawBackground(poster.palette)
    poster.decoration(context)
    drawBrandPill(poster.palette)

    for (index, line) in poster.titleLines.enumerated() {
        text(line, x: 78, top: 259 + CGFloat(index) * 112, size: 100, weight: .bold, color: poster.palette.title)
    }
    text(poster.subtitle, x: 82, top: 543, size: 38, weight: .medium, color: poster.palette.subtitle)

    let chipAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 31, weight: .semibold),
        .foregroundColor: poster.palette.accent
    ]
    let chipString = NSAttributedString(string: poster.chip, attributes: chipAttributes)
    let chipHorizontalPadding: CGFloat = 31
    let chipWidth = ceil(chipString.size().width + chipHorizontalPadding * 2)
    let chipRect = rectFromTop(82, 662, chipWidth, 72)
    roundedRect(chipRect, radius: 36, fill: color(0xffffff, alpha: 0.72))
    let chipX = chipRect.minX + (chipRect.width - chipString.size().width) / 2
    let chipY = chipRect.minY + (chipRect.height - chipString.size().height) / 2
    chipString.draw(at: NSPoint(x: chipX, y: chipY))

    try drawPhone(with: sources.appendingPathComponent(poster.source))

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "VoucherWalletPoster", code: 3)
    }
    try png.write(to: exports.appendingPathComponent(poster.output), options: .atomic)
}

private let orange = Palette(
    top: color(0xfff9f1),
    middle: color(0xffe8c5),
    bottom: color(0xffb94b),
    pillStart: color(0xffaa2c),
    pillEnd: color(0xf4891b),
    pillText: color(0x5b2f17),
    title: color(0x3c2215),
    subtitle: color(0x764832),
    accent: color(0x764832)
)

private let detail = Palette(
    top: color(0xfff9f2),
    middle: color(0xffe7c6),
    bottom: color(0xffc35d),
    pillStart: color(0xffaa2c),
    pillEnd: color(0xf4891b),
    pillText: color(0x5b2f17),
    title: color(0x30241f),
    subtitle: color(0x65473a),
    accent: color(0x276b9f)
)

private let widget = Palette(
    top: color(0xf7f2ea),
    middle: color(0xffe1b5),
    bottom: color(0xf99f32),
    pillStart: color(0xffcb40),
    pillEnd: color(0xf39b22),
    pillText: color(0x543018),
    title: color(0x362217),
    subtitle: color(0x704732),
    accent: color(0x704732)
)

private let importPDF = Palette(
    top: color(0xfff9f1),
    middle: color(0xffe8c5),
    bottom: color(0xffbd55),
    pillStart: color(0xffaa2c),
    pillEnd: color(0xf4891b),
    pillText: color(0x5b2f17),
    title: color(0x3c2215),
    subtitle: color(0x764832),
    accent: color(0x2e9252)
)

private let posters: [Poster] = [
    Poster(
        output: "01-tous-vos-bons.png",
        source: "IMG_0622.png",
        titleLines: ["Tous vos bons,", "au m\u{00EA}me endroit"],
        subtitle: "Soldes, dates d'expiration et favoris en un coup d'oeil.",
        chip: "Favoris accessibles rapidement",
        palette: orange,
        decoration: { _ in
            color(0xffcf82, alpha: 0.36).setFill()
            NSBezierPath(ovalIn: ovalFromTop(1122, 120, 476)).fill()
            color(0xffffff, alpha: 0.44).setFill()
            NSBezierPath(ovalIn: ovalFromTop(76, 606, 300)).fill()
        }
    ),
    Poster(
        output: "02-code-en-caisse.png",
        source: "IMG_0623.png",
        titleLines: ["Votre code,", "pr\u{00EA}t en caisse"],
        subtitle: "Affichez votre QR code en quelques secondes.",
        chip: "Solde toujours visible",
        palette: detail,
        decoration: { _ in
            color(0xffb335, alpha: 0.42).setFill()
            let corner = NSBezierPath()
            corner.move(to: NSPoint(x: 940, y: height))
            corner.line(to: NSPoint(x: width, y: height))
            corner.line(to: NSPoint(x: width, y: height - 490))
            corner.curve(to: NSPoint(x: 940, y: height), controlPoint1: NSPoint(x: 1135, y: height - 453), controlPoint2: NSPoint(x: 1018, y: height - 340))
            corner.fill()
            color(0xffe09e, alpha: 0.7).setFill()
            NSBezierPath(ovalIn: ovalFromTop(110, 520, 244)).fill()
        }
    ),
    Poster(
        output: "03-widget-favoris.png",
        source: "IMG_0624.png",
        titleLines: ["Vos favoris", "sur l'\u{00E9}cran d'accueil"],
        subtitle: "Consultez vos soldes sans ouvrir l'app.",
        chip: "Widget de vos favoris",
        palette: widget,
        decoration: { _ in
            color(0xffcf63, alpha: 0.45).setFill()
            NSBezierPath(ovalIn: ovalFromTop(1110, 200, 490)).fill()
            color(0xffffff, alpha: 0.18).setFill()
            NSBezierPath(ovalIn: ovalFromTop(62, 2394, 540)).fill()
        }
    ),
    Poster(
        output: "04-import-pdf.png",
        source: "IMG_import.png",
        titleLines: ["Importez un PDF,", "les infos apparaissent"],
        subtitle: "QR code, enseigne et montant d\u{00E9}tect\u{00E9}s automatiquement.",
        chip: "Analyse automatique",
        palette: importPDF,
        decoration: { _ in
            color(0xffcf82, alpha: 0.34).setFill()
            NSBezierPath(ovalIn: ovalFromTop(1110, 184, 480)).fill()
            color(0x65c877, alpha: 0.12).setFill()
            NSBezierPath(ovalIn: ovalFromTop(82, 594, 270)).fill()
        }
    )
]

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("AppStore", isDirectory: true)
let sources = root.appendingPathComponent("Sources", isDirectory: true)
let exports = root.appendingPathComponent("Exports", isDirectory: true)
try FileManager.default.createDirectory(at: exports, withIntermediateDirectories: true)

for poster in posters {
    try export(poster, sources: sources, exports: exports)
    print("Exporte : \(poster.output)")
}
