import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Preserve canonical artwork while publishing copies sized for fixed card slots.
enum ImageOptimization {
    static func path(for original: String) -> String {
        let path = original.hasSuffix(".webp") ? original + ".png" : original
        return "/optimized" + path
    }

    static func prepare(in directory: URL) throws {
        let files = FileManager.default
        for (folder, size) in [("app-icons", DesignTokens.productIconSize), ("portraits", DesignTokens.builderPortraitSize)] {
            let source = directory.appending(path: folder)
            guard files.fileExists(atPath: source.path) else { continue }
            for file in try files.contentsOfDirectory(at: source, includingPropertiesForKeys: nil).sorted(by: { $0.path < $1.path }) {
                guard ["png", "jpg", "webp"].contains(file.pathExtension) else { continue }
                let target = directory.appending(path: String(path(for: "/" + folder + "/" + file.lastPathComponent).dropFirst()))
                try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
                try resize(file, to: target, maximumDimension: size * 3)
            }
        }
    }

    static func resize(_ source: URL, to target: URL, maximumDimension: Int) throws {
        guard maximumDimension > 0,
              let imageSource = CGImageSourceCreateWithURL(source as CFURL, nil),
              CGImageSourceGetCount(imageSource) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw CatalogError.invalid("Cannot read a static image: \(source.path)")
        }
        if max(width, height) <= maximumDimension && source.pathExtension == target.pathExtension {
            try FileManager.default.copyItem(at: source, to: target)
            return
        }
        // ImageIO applies EXIF orientation; the pixel bound never enlarges a source.
        guard let image = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(maximumDimension, max(width, height))
        ] as CFDictionary) else {
            throw CatalogError.invalid("Cannot resize image: \(source.path)")
        }
        // High-bit-depth originals are useful masters, but not needed in tiny cards.
        // Keep RGB profiles (including Display P3) and alpha in 8-bit delivery copies.
        let colourSpace = image.colorSpace?.model == .rgb ? image.colorSpace : CGColorSpace(name: CGColorSpace.sRGB)
        guard let colourSpace,
              let bitmap = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
                  bytesPerRow: image.width * 4, space: colourSpace,
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CatalogError.invalid("Cannot prepare image colours: \(source.path)")
        }
        bitmap.setBlendMode(.copy)
        bitmap.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let deliveryImage = bitmap.makeImage() else {
            throw CatalogError.invalid("Cannot prepare image pixels: \(source.path)")
        }
        let type = target.pathExtension == "jpg" ? UTType.jpeg : UTType.png
        guard let destination = CGImageDestinationCreateWithURL(target as CFURL, type.identifier as CFString, 1, nil) else {
            throw CatalogError.invalid("Cannot write image: \(target.path)")
        }
        // The CGImage retains its colour space. Resampled copies omit source EXIF
        // and location metadata; photographic JPEG copies use high quality.
        let options: [CFString: Any] = type == .jpeg ? [kCGImageDestinationLossyCompressionQuality: 0.9] : [:]
        CGImageDestinationAddImage(destination, deliveryImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw CatalogError.invalid("Cannot finish image: \(target.path)")
        }
    }

    static func compressPNGs(in directory: URL, cacheDirectory: URL? = nil) throws {
        let environment = ProcessInfo.processInfo.environment
        let paths = (environment["PATH"] ?? "").split(separator: ":").map(String.init)
            + ["/opt/homebrew/bin", "/usr/local/bin"]
        guard let executable = paths.map({ URL(fileURLWithPath: $0).appending(path: "optipng") })
            .first(where: { FileManager.default.isExecutableFile(atPath: $0.path) }) else {
            throw CatalogError.invalid("PNG optimisation requires OptiPNG. Install it with: brew install optipng")
        }
        guard let enumerator = FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil) else {
            throw CatalogError.invalid("Cannot inspect images in \(directory.path)")
        }
        let images = enumerator.compactMap { $0 as? URL }.filter { $0.pathExtension == "png" }.sorted { $0.path < $1.path }
        if let cacheDirectory { try FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true) }
        var pending: [(image: URL, cache: URL?)] = []
        for image in images {
            let input = try Data(contentsOf: image)
            let digest = SHA256.hash(data: Data("optipng-o2-v1".utf8) + input)
                .map { String(("0" + String($0, radix: 16)).suffix(2)) }.joined()
            let cache = cacheDirectory?.appending(path: digest + ".png")
            if let cache, let data = try? Data(contentsOf: cache),
               data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
               let source = CGImageSourceCreateWithData(data as CFData, nil),
               CGImageSourceGetStatus(source) == .statusComplete {
                try data.write(to: image, options: .atomic)
            } else {
                pending.append((image, cache))
            }
        }
        guard !pending.isEmpty else { return }
        let process = Process()
        process.executableURL = executable
        // No quantisation or metadata stripping: colour profiles and alpha survive.
        process.arguments = ["-quiet", "-o2", "--"] + pending.map { $0.image.path }
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CatalogError.invalid("PNG optimisation failed; the previous publication has been preserved.")
        }
        for (image, cache) in pending {
            if let cache { try Data(contentsOf: image).write(to: cache, options: .atomic) }
        }
    }
}
