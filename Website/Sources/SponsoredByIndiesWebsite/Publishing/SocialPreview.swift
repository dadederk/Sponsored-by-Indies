import AppKit
import CoreText

/// Render the same resolved vector artwork for sharing, profiles and browser icons.
@MainActor
enum SocialPreview {
    static func install(in directory: URL, identity: SiteIdentity = .sponsored, bundles: [BundleArtwork] = []) throws {
        guard let emphasis = NSFont(name: "Georgia-BoldItalic", size: 1),
              let headlineEmphasis = NSFont(name: "Georgia-Italic", size: 1) else {
            throw RenderError.unavailableFont
        }
        guard let logo = NSImage(contentsOf: directory.appending(path: "logo.svg")),
              let inverse = NSImage(contentsOf: directory.appending(path: "logo-inverse.svg")),
              let icon = NSImage(contentsOf: directory.appending(path: "favicon.svg")) else {
            throw RenderError.unavailableGraphics
        }
        let palette = DesignTokens.palette
        try png(width: 1200, height: 630, background: palette.paper) {
            wordmark(logo: logo, emphasis: emphasis, at: NSPoint(x: 65, y: 390), markSize: 160, identity: identity)
            headline(at: NSPoint(x: 70, y: 245), size: 74, emphasis: headlineEmphasis, identity: identity)
            fill(NSRect(x: 0, y: 0, width: 1200, height: 80), with: palette.ink)
            draw(identity.summary, at: NSPoint(x: 70, y: 25), size: 28, color: palette.accentSoft)
        }.write(to: directory.appending(path: "social-preview.png"), options: .atomic)
        try png(width: 1024, height: 1024, background: palette.ink) {
            inverse.draw(in: NSRect(x: 155, y: 155, width: 714, height: 714))
        }.write(to: directory.appending(path: "social-avatar.png"), options: .atomic)
        try png(width: 1500, height: 500, background: palette.paper) {
            wordmark(logo: logo, emphasis: emphasis, at: NSPoint(x: 60, y: 165), markSize: 190, identity: identity)
            headline(at: NSPoint(x: 850, y: 265), size: 50, emphasis: headlineEmphasis, identity: identity)
            fill(NSRect(x: 0, y: 0, width: 1500, height: 65), with: palette.ink)
            draw(identity.summary, at: NSPoint(x: 60, y: 19), size: 24, color: palette.accentSoft)
        }.write(to: directory.appending(path: "social-banner.png"), options: .atomic)
        try png(width: 1800, height: 450, background: palette.paper) {
            wordmark(logo: logo, emphasis: emphasis, at: NSPoint(x: 60, y: 140), markSize: 200, identity: identity)
            headline(at: NSPoint(x: 900, y: 230), size: 60, emphasis: headlineEmphasis, identity: identity)
            fill(NSRect(x: 0, y: 0, width: 1800, height: 60), with: palette.ink)
            draw(identity.summary, at: NSPoint(x: 80, y: 17), size: 25, color: palette.accentSoft)
        }.write(to: directory.appending(path: "readme-banner.png"), options: .atomic)
        var renderedBundles = Set<String>()
        for bundle in bundles where renderedBundles.insert(bundle.imagePath).inserted {
            let target = directory.appending(path: String(bundle.imagePath.dropFirst()))
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png(width: 1200, height: 630, background: palette.paper) {
                let branding = bundle.conference.branding
                let background = branding?.background ?? palette.ink
                fill(NSRect(x: 0, y: 160, width: 1200, height: 470), with: background)
                fittedText("\(bundle.edition.label) INDIE BUNDLE", in: NSRect(x: 70, y: 520, width: 1060, height: 50),
                           size: 28, color: branding?.highlight ?? palette.accentSoft, weight: .semibold)
                fittedText(bundle.conference.name, in: NSRect(x: 65, y: 335, width: 1070, height: 155),
                           size: 104, color: branding?.accent ?? palette.accentSoft, weight: .bold)
                fittedText(bundle.edition.dateLabel, in: NSRect(x: 70, y: 260, width: 1060, height: 50),
                           size: 32, color: palette.white)
                fittedText(bundle.conference.location, in: NSRect(x: 70, y: 200, width: 1060, height: 50),
                           size: 32, color: branding?.detail ?? palette.paper)
                wordmark(logo: logo, emphasis: emphasis, at: NSPoint(x: 60, y: 25), markSize: 110, identity: .sponsored)
                headline(at: NSPoint(x: 650, y: 85), size: 32, emphasis: headlineEmphasis, identity: .sponsored)
            }.write(to: target, options: .atomic)
        }
        for (name, size) in [("favicon-32.png", 32), ("apple-touch-icon.png", 180)] {
            try png(width: size, height: size, background: palette.ink) {
                icon.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
            }.write(to: directory.appending(path: name), options: .atomic)
        }
        let iconPNG = try Data(contentsOf: directory.appending(path: "favicon-32.png"))
        // A single 32px PNG representation inside the standard ICO container.
        var ico = Data([0, 0, 1, 0, 1, 0, 32, 32, 0, 0, 1, 0, 32, 0])
        for value in [UInt32(iconPNG.count), 22] {
            ico.append(contentsOf: (0..<4).map { UInt8(truncatingIfNeeded: value >> ($0 * 8)) })
        }
        ico.append(iconPNG)
        try ico.write(to: directory.appending(path: "favicon.ico"), options: .atomic)
    }

    /// Share the homepage's navy headline and regular orange serif emphasis.
    private static func headline(at point: NSPoint, size: CGFloat, emphasis: NSFont, identity: SiteIdentity) {
        draw(identity.headline, at: point, size: size, color: DesignTokens.palette.ink, weight: .bold)
        let italic = NSFont(descriptor: emphasis.fontDescriptor, size: size * 1.1)!
        draw(identity.emphasis, at: NSPoint(x: point.x - 3, y: point.y - size * 1.2),
             font: italic, color: DesignTokens.palette.accent)
    }

    /// Match the website's two-line lockup and its relative type sizes.
    private static func wordmark(logo: NSImage, emphasis: NSFont, at point: NSPoint, markSize: CGFloat, identity: SiteIdentity) {
        let palette = DesignTokens.palette
        let scale = markSize / DesignTokens.brandMarkSize
        let x = point.x + markSize + DesignTokens.brandGap * scale
        let label = NSFont.systemFont(ofSize: DesignTokens.brandLabelSize * scale, weight: .bold)
        let byFont = NSFont.systemFont(ofSize: DesignTokens.brandNameSize * scale, weight: .regular)
        let name = NSFont(descriptor: emphasis.fontDescriptor, size: DesignTokens.brandNameSize * scale)!
        logo.draw(in: NSRect(origin: point, size: NSSize(width: markSize, height: markSize)))
        let sponsored = line("Sponsored", font: label, color: palette.blue)
        let indies = line(SiteIdentity.wordmarkName, font: name, color: palette.accent)
        let by = line("by ", font: byFont, color: palette.blue)
        let sponsoredBounds = CTLineGetBoundsWithOptions(sponsored, .useGlyphPathBounds)
        let indiesBounds = CTLineGetBoundsWithOptions(indies, .useGlyphPathBounds)
        let labelHeight = identity == .sponsored ? sponsoredBounds.height + DesignTokens.brandLineGap * scale : 0
        let height = labelHeight + indiesBounds.height
        let top = point.y + (markSize + height) / 2
        let baseline = top - labelHeight - indiesBounds.maxY
        // Glyph bounds keep the italic capitals clear of the line above.
        if identity == .sponsored { draw(sponsored, at: NSPoint(x: x, y: top - sponsoredBounds.maxY)) }
        draw(by, at: NSPoint(x: x, y: baseline))
        draw(indies, at: NSPoint(x: x + CTLineGetTypographicBounds(by, nil, nil, nil), y: baseline))
    }

    private static func line(_ text: String, font: NSFont, color hex: String) -> CTLine {
        CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
            .font: font, .foregroundColor: color(hex)
        ]))
    }

    private static func draw(_ line: CTLine, at baseline: NSPoint) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.textPosition = baseline
        CTLineDraw(line, context)
    }

    private static func png(width: Int, height: Int, background: String, drawing: () -> Void) throws -> Data {
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            throw RenderError.unavailableGraphics
        }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        fill(NSRect(x: 0, y: 0, width: width, height: height), with: background)
        drawing()
        guard let data = bitmap.representation(using: .png, properties: [:]) else {
            throw RenderError.unavailableGraphics
        }
        return data
    }

    private static func fill(_ rect: NSRect, with hex: String) {
        color(hex).setFill()
        NSBezierPath(rect: rect).fill()
    }

    private static func fittedText(_ text: String, in rect: NSRect, size: CGFloat, color hex: String,
                                   weight: NSFont.Weight = .regular) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        var font = NSFont.systemFont(ofSize: size, weight: weight)
        while font.pointSize > 12 {
            let bounds = (text as NSString).boundingRect(with: NSSize(width: rect.width, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin],
                                                        attributes: [.font: font, .paragraphStyle: paragraph])
            if bounds.height <= rect.height { break }
            font = NSFont.systemFont(ofSize: font.pointSize - 1, weight: weight)
        }
        (text as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color(hex), .paragraphStyle: paragraph
        ])
    }

    private static func draw(_ text: String, at point: NSPoint, size: CGFloat, color hex: String, weight: NSFont.Weight = .regular) {
        draw(text, at: point, font: NSFont.systemFont(ofSize: size, weight: weight), color: hex)
    }

    private static func draw(_ text: String, at point: NSPoint, font: NSFont, color hex: String) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: font, .foregroundColor: color(hex)
        ])
    }

    private static func color(_ hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    enum RenderError: Error { case unavailableGraphics, unavailableFont }
}
