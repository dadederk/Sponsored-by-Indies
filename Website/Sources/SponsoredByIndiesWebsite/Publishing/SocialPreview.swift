import AppKit

/// Render the same resolved vector artwork for sharing, profiles and browser icons.
@MainActor
enum SocialPreview {
    static func install(in directory: URL) throws {
        guard let logo = NSImage(contentsOf: directory.appending(path: "logo.svg")),
              let inverse = NSImage(contentsOf: directory.appending(path: "logo-inverse.svg")),
              let icon = NSImage(contentsOf: directory.appending(path: "favicon.svg")) else {
            throw RenderError.unavailableGraphics
        }
        let palette = DesignTokens.palette
        try png(width: 1200, height: 630, background: palette.paper) {
            logo.draw(in: NSRect(x: 65, y: 205, width: 290, height: 290))
            draw("Sponsored by", at: NSPoint(x: 390, y: 405), size: 36, color: palette.ink)
            draw("Indies", at: NSPoint(x: 385, y: 305), size: 90, color: palette.ink, weight: .bold)
            draw("A little extra. From your community.", at: NSPoint(x: 390, y: 260), size: 27, color: palette.accent)
            fill(NSRect(x: 0, y: 0, width: 1200, height: 140), with: palette.ink)
            draw("Indie bundles for Swift & iOS conferences", at: NSPoint(x: 70, y: 52), size: 34, color: palette.accentSoft)
        }.write(to: directory.appending(path: "social-preview.png"), options: .atomic)
        try png(width: 1024, height: 1024, background: palette.ink) {
            inverse.draw(in: NSRect(x: 155, y: 155, width: 714, height: 714))
        }.write(to: directory.appending(path: "social-avatar.png"), options: .atomic)
        try png(width: 1500, height: 500, background: palette.paper) {
            logo.draw(in: NSRect(x: 70, y: 105, width: 300, height: 300))
            draw("Sponsored by", at: NSPoint(x: 420, y: 315), size: 38, color: palette.ink)
            draw("Indies", at: NSPoint(x: 415, y: 205), size: 100, color: palette.ink, weight: .bold)
            draw("A little extra. From your community.", at: NSPoint(x: 420, y: 150), size: 32, color: palette.accent)
            fill(NSRect(x: 0, y: 0, width: 1500, height: 65), with: palette.ink)
            draw("Independent makers. Shared support.", at: NSPoint(x: 80, y: 19), size: 24, color: palette.accentSoft)
        }.write(to: directory.appending(path: "social-banner.png"), options: .atomic)
        try png(width: 1800, height: 450, background: palette.paper) {
            logo.draw(in: NSRect(x: 70, y: 100, width: 280, height: 280))
            draw("Sponsored by", at: NSPoint(x: 400, y: 270), size: 38, color: palette.ink)
            draw("Indies", at: NSPoint(x: 395, y: 160), size: 100, color: palette.ink, weight: .bold)
            draw("A little extra.", at: NSPoint(x: 1050, y: 245), size: 52, color: palette.accent)
            draw("From your community.", at: NSPoint(x: 1050, y: 190), size: 40, color: palette.accent)
            fill(NSRect(x: 0, y: 0, width: 1800, height: 60), with: palette.ink)
            draw("Indie bundles for Swift & iOS conferences", at: NSPoint(x: 80, y: 17), size: 25, color: palette.accentSoft)
        }.write(to: directory.appending(path: "readme-banner.png"), options: .atomic)
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

    private static func draw(_ text: String, at point: NSPoint, size: CGFloat, color hex: String, weight: NSFont.Weight = .regular) {
        (text as NSString).draw(at: point, withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color(hex)
        ])
    }

    private static func color(_ hex: String) -> NSColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }

    enum RenderError: Error { case unavailableGraphics }
}
