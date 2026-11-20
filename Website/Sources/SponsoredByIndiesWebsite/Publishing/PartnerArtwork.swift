import AppKit
import ImageIO
import UniformTypeIdentifiers

/// A fixed composition using original assets; no generated lettering or layout randomness.
struct PartnerArtwork {
    let conference: Conference
    let edition: Edition
    let projects: [Project]
    let group: PartnerArtworkGroup?

    enum Symbol: String, CaseIterable { case cross, heart }

    init(catalog: Catalog, editionID: String, projectID: String? = nil, groupID: String? = nil) throws {
        guard let edition = catalog.editions.first(where: { $0.id == editionID }) else {
            throw CatalogError.invalid("Unknown artwork edition: \(editionID).")
        }
        let conference = catalog.conference(for: edition)
        guard conference.branding?.logoPath != nil else {
            throw CatalogError.invalid("Conference \(conference.id) needs a vector logo for partner artwork.")
        }
        guard projectID == nil || groupID == nil else {
            throw CatalogError.invalid("Choose a product or an artwork group.")
        }
        if let groupID {
            guard let group = edition.artworkGroups?.first(where: { $0.id == groupID }), group.projectIDs.count == 2,
                  Set(group.projectIDs).count == 2 else {
                throw CatalogError.invalid("Unknown or invalid artwork group: \(groupID).")
            }
            self.group = group
        } else {
            self.group = nil
        }
        let ids = group?.projectIDs ?? projectID.map { [$0] } ?? []
        self.projects = try ids.map { id in
            guard let project = catalog.projects.first(where: { $0.id == id }), project.iconPath != nil,
                  catalog.visibleOffers(for: edition).contains(where: { $0.projectID == id }) else {
                throw CatalogError.invalid("Artwork requires original artwork and an approved contribution in \(editionID): \(id).")
            }
            return project
        }
        self.conference = conference
        self.edition = edition
        // IDs become export paths; product posts must not replace the sponsor's files.
        guard [edition.id, partnerID].allSatisfy({
            $0.range(of: "\\A[a-z0-9]+(?:-[a-z0-9]+)*\\z", options: .regularExpression) != nil
        }), projects.isEmpty || partnerID != "sponsored-by-indies" else {
            throw CatalogError.invalid("Artwork requires distinct, safe edition and partner IDs.")
        }
    }

    var partnerID: String { group?.id ?? projects.first?.id ?? "sponsored-by-indies" }
    var folder: String { "social/\(conference.slug)/\(edition.slug)/\(partnerID)" }

    func filename(for symbol: Symbol) -> String {
        "\(conference.slug)-\(edition.slug)-\(partnerID)-\(symbol.rawValue).png"
    }

    static func batch(catalog: Catalog, editionID: String) throws -> [PartnerArtwork] {
        let sponsor = try PartnerArtwork(catalog: catalog, editionID: editionID)
        let groups = sponsor.edition.artworkGroups ?? []
        var result = [sponsor]
        var addedGroups = Set<String>()
        for contribution in catalog.visibleProductContributions(for: sponsor.edition) {
            guard let id = contribution.product.projectID else {
                throw CatalogError.invalid("Partner artwork requires stable product IDs.")
            }
            if let group = groups.first(where: { $0.projectIDs.contains(id) }) {
                if addedGroups.insert(group.id).inserted {
                    result.append(try PartnerArtwork(catalog: catalog, editionID: editionID, groupID: group.id))
                }
            } else {
                result.append(try PartnerArtwork(catalog: catalog, editionID: editionID, projectID: id))
            }
        }
        guard Set(result.map(\.partnerID)).count == result.count else {
            throw CatalogError.invalid("Partner artwork filenames must be distinct.")
        }
        return result
    }

    @MainActor
    static func installBatch(_ artworks: [PartnerArtwork], in directory: URL, assets: URL, brandLogo: URL) throws {
        let files = FileManager.default
        let parent = directory.deletingLastPathComponent()
        try files.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appending(path: "partner-\(UUID().uuidString)")
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: staging) }
        for artwork in artworks {
            try artwork.png(symbol: .cross, assets: assets, brandLogo: brandLogo)
                .write(to: staging.appending(path: artwork.filename(for: .cross)), options: .atomic)
        }
        try BuildOutput.install(staging, at: directory)
    }

    @MainActor
    func install(in directory: URL, assets: URL, brandLogo: URL) throws {
        let files = FileManager.default
        let parent = directory.deletingLastPathComponent()
        try files.createDirectory(at: parent, withIntermediateDirectories: true)
        let staging = parent.appending(path: "partner-\(UUID().uuidString)")
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: staging) }
        for symbol in Symbol.allCases {
            try png(symbol: symbol, assets: assets, brandLogo: brandLogo)
                .write(to: staging.appending(path: filename(for: symbol)), options: .atomic)
        }
        try BuildOutput.install(staging, at: directory)
    }

    @MainActor
    func png(symbol: Symbol, assets: URL, brandLogo: URL) throws -> Data {
        typealias Layout = DesignTokens.PartnerArtwork
        guard let branding = conference.branding, let logoPath = branding.logoPath else {
            throw CatalogError.invalid("Missing conference artwork.")
        }
        let vector = try String(contentsOf: assets.appending(path: String(logoPath.dropFirst())), encoding: .utf8)
        let resolved = try DesignTokens.renderSVG(vector, colors: [
            "conference-background": branding.background,
            "conference-highlight": branding.highlight,
            "conference-accent": branding.accent,
            "conference-detail": branding.detail
        ])
        guard let conferenceLogo = NSImage(data: Data(resolved.utf8)),
              let signature = NSImage(contentsOf: brandLogo),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Layout.width, height: Layout.height,
                  bitsPerComponent: 8, bytesPerRow: Layout.width * 4, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CatalogError.invalid("Cannot read or prepare partner artwork.")
        }
        let products = try projects.map { project in
            guard let iconPath = project.iconPath,
                  let source = CGImageSourceCreateWithURL(assets.appending(path: String(iconPath.dropFirst())) as CFURL, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                throw CatalogError.invalid("Cannot read product artwork: \(project.id).")
            }
            return NSImage(cgImage: try Self.removingTransparentPadding(from: image), size: .zero)
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        context.interpolationQuality = .high
        let palette = DesignTokens.palette
        context.setFillColor(color(palette.paper))
        context.fill(CGRect(x: 0, y: 0, width: Layout.width, height: Layout.height))
        context.setFillColor(color(palette.tint))
        context.fillEllipse(in: Layout.upperCurve)
        context.fillEllipse(in: Layout.lowerCurve)
        context.setFillColor(color(branding.artworkBackground ?? branding.background))
        context.fillEllipse(in: Layout.conferenceFrame)
        fit(conferenceLogo, in: Layout.conferenceFrame.insetBy(dx: Layout.conferenceLogoInset, dy: Layout.conferenceLogoInset))
        draw(symbol, in: context)
        if !products.isEmpty {
            let frames = products.count == 1 ? [Layout.productFrame] : Layout.pairedProductFrames
            for (product, frame) in zip(products, frames) {
                context.saveGState()
                // App tiles are square. Preserve portrait book covers without rounding or cropping them.
                if product.size.width == product.size.height {
                    let rect = fittedFrame(product, in: frame)
                    let radius = rect.width * Layout.productRadius / Layout.productFrame.width
                    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
                    context.clip()
                }
                fit(product, in: frame)
                context.restoreGState()
            }
            fit(signature, in: Layout.signatureFrame)
        } else {
            fit(signature, in: Layout.brandFrame)
        }
        // Font-free vector symbols and logos, fixed geometry and original PNGs
        // make repeated renders byte-identical on the same rendering runtime.
        guard let image = context.makeImage() else {
            throw CatalogError.invalid("Cannot finish partner artwork.")
        }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil) else {
            throw CatalogError.invalid("Cannot encode partner artwork.")
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw CatalogError.invalid("Cannot encode partner artwork.")
        }
        return output as Data
    }

    /// Size the visible artwork consistently when maker exports include transparent canvas padding.
    static func removingTransparentPadding(from image: CGImage) throws -> CGImage {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let bitmap = CGContext(data: nil, width: image.width, height: image.height,
                  bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue),
              let bytes = bitmap.data?.assumingMemoryBound(to: UInt8.self) else {
            throw CatalogError.invalid("Cannot inspect artwork transparency.")
        }
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        var minX = image.width, minY = image.height, maxX = -1, maxY = -1
        for y in 0..<image.height {
            for x in 0..<image.width where bytes[(y * image.width + x) * 4 + 3] > 0 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let cropped = image.cropping(to: CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)) else {
            throw CatalogError.invalid("Product artwork must contain visible pixels.")
        }
        return cropped
    }

    @MainActor
    private func fit(_ image: NSImage, in frame: CGRect) {
        image.draw(in: fittedFrame(image, in: frame))
    }

    @MainActor
    private func fittedFrame(_ image: NSImage, in frame: CGRect) -> CGRect {
        let scale = min(frame.width / image.size.width, frame.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        return CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                      width: size.width, height: size.height)
    }

    private func draw(_ symbol: Symbol, in context: CGContext) {
        typealias Layout = DesignTokens.PartnerArtwork
        let frame = Layout.symbolFrame
        context.saveGState()
        defer { context.restoreGState() }
        switch symbol {
        case .cross:
            let rect = frame.insetBy(dx: Layout.crossInset, dy: Layout.crossInset)
            context.setStrokeColor(color(DesignTokens.palette.ink))
            context.setLineWidth(Layout.crossStroke)
            context.setLineCap(.round)
            context.move(to: CGPoint(x: rect.minX, y: rect.minY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            context.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            context.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            context.strokePath()
        case .heart:
            // Normalised Bézier outline avoids platform-specific emoji and fonts.
            context.translateBy(x: frame.minX, y: frame.minY)
            context.scaleBy(x: frame.width, y: frame.height)
            context.setFillColor(color(DesignTokens.palette.accent))
            context.move(to: CGPoint(x: 0.5, y: 0.06))
            context.addCurve(to: CGPoint(x: 0.03, y: 0.62), control1: CGPoint(x: 0.35, y: 0.23), control2: CGPoint(x: 0.03, y: 0.39))
            context.addCurve(to: CGPoint(x: 0.5, y: 0.81), control1: CGPoint(x: 0.03, y: 0.97), control2: CGPoint(x: 0.35, y: 1.02))
            context.addCurve(to: CGPoint(x: 0.97, y: 0.62), control1: CGPoint(x: 0.65, y: 1.02), control2: CGPoint(x: 0.97, y: 0.97))
            context.addCurve(to: CGPoint(x: 0.5, y: 0.06), control1: CGPoint(x: 0.97, y: 0.39), control2: CGPoint(x: 0.65, y: 0.23))
            context.closePath()
            context.fillPath()
        }
    }

    private func color(_ hex: String) -> CGColor {
        let value = UInt32(hex.dropFirst(), radix: 16)!
        return CGColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
                       green: CGFloat((value >> 8) & 255) / 255,
                       blue: CGFloat(value & 255) / 255, alpha: 1)
    }
}
