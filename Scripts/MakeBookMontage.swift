import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// Offline authoring tool: cover order and the versioned layout define the artwork.
// Keep manifests and unapproved source covers in private planning.
struct Montage: Decodable {
    struct Cover: Decodable {
        var file: String
        var title: String
    }
    var layout: String
    var covers: [Cover]
}

enum MontageError: Error, CustomStringConvertible {
    case invalid(String)
    var description: String { switch self { case .invalid(let message): message } }
}

func referencesSameFile(_ first: URL, _ second: URL) -> Bool {
    if first.standardizedFileURL.resolvingSymlinksInPath() == second.standardizedFileURL.resolvingSymlinksInPath() {
        return true
    }
    // File identity also catches hard links and differently cased paths on macOS.
    guard let firstID = try? first.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject,
          let secondID = try? second.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as? NSObject else {
        return false
    }
    return firstID.isEqual(secondID)
}

func render(manifest: URL, output: URL) throws {
    let specification = try JSONDecoder().decode(Montage.self, from: Data(contentsOf: manifest))
    guard specification.layout == "staggered-v1" else {
        throw MontageError.invalid("Unknown layout. Use staggered-v1.")
    }
    let positions: [CGPoint]
    switch specification.covers.count {
    case 2: positions = [CGPoint(x: 120, y: 0), CGPoint(x: 600, y: 600)]
    case 3: positions = [CGPoint(x: 300, y: 0), CGPoint(x: 0, y: 600), CGPoint(x: 720, y: 600)]
    case 4: positions = [CGPoint(x: 120, y: 0), CGPoint(x: 600, y: 150),
                         CGPoint(x: 0, y: 520), CGPoint(x: 720, y: 650)]
    case 5: positions = [CGPoint(x: 280, y: 0), CGPoint(x: 0, y: 400),
                         CGPoint(x: 600, y: 250), CGPoint(x: 120, y: 730), CGPoint(x: 720, y: 620)]
    default: throw MontageError.invalid("staggered-v1 needs two to five covers.")
    }
    let directory = manifest.deletingLastPathComponent()
    let files = specification.covers.map { directory.appendingPathComponent($0.file).standardizedFileURL }
    guard Set(files).count == files.count, specification.covers.allSatisfy({ !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
        throw MontageError.invalid("Use distinct cover files and give each a title.")
    }
    guard !([manifest] + files).contains(where: { referencesSameFile($0, output) }) else {
        throw MontageError.invalid("The output must not replace a source cover or the manifest.")
    }
    // Decode everything before writing, so a missing or unsuitable image preserves the old export.
    let images = try files.map { file -> CGImage in
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              max(width, height) <= 12_000,
              // Apply orientation before checking the portrait shape, without reducing source resolution.
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: max(width, height)
              ] as CFDictionary),
              image.width < image.height else {
            throw MontageError.invalid("Use an original portrait cover, not a landscape advert: \(file.lastPathComponent)")
        }
        return image
    }
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
          let context = CGContext(data: nil, width: 1240, height: 1500, bitsPerComponent: 8,
                                  bytesPerRow: 1240 * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue) else {
        throw MontageError.invalid("Could not create the transparent sRGB canvas.")
    }
    context.interpolationQuality = .high
    for (image, origin) in zip(images, positions) {
        let scale = min(480 / CGFloat(image.width), 700 / CGFloat(image.height))
        let size = CGSize(width: CGFloat(image.width) * scale, height: CGFloat(image.height) * scale)
        // Inputs use top-left positions; Core Graphics uses a bottom-left origin.
        let rect = CGRect(x: origin.x + 20, y: 1500 - origin.y - 20 - size.height,
                          width: size.width, height: size.height)
        context.saveGState()
        context.setShadow(offset: CGSize(width: 0, height: -4), blur: 8,
                          color: CGColor(gray: 0, alpha: 0.18))
        context.draw(image, in: rect)
        context.restoreGState()
    }
    guard let image = context.makeImage() else { throw MontageError.invalid("Could not finish the montage.") }
    let data = NSMutableData()
    guard let writer = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
        throw MontageError.invalid("Could not create the PNG export.")
    }
    CGImageDestinationAddImage(writer, image, nil)
    guard CGImageDestinationFinalize(writer) else { throw MontageError.invalid("Could not encode the PNG export.") }
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try (data as Data).write(to: output, options: .atomic)
}

do {
    let arguments = Array(CommandLine.arguments.dropFirst())
    if arguments == ["--help"] {
        print("Usage: swift Scripts/MakeBookMontage.swift manifest.json output.png\nLayout: staggered-v1; two to five original portrait covers, ordered back to front.\nCover file paths are relative to the manifest. Output is a transparent 1240 × 1500 sRGB PNG.")
    } else {
        guard arguments.count == 2, URL(fileURLWithPath: arguments[1]).pathExtension.lowercased() == "png" else {
            throw MontageError.invalid("Usage: swift Scripts/MakeBookMontage.swift manifest.json output.png")
        }
        let manifest = URL(fileURLWithPath: arguments[0])
        try render(manifest: manifest, output: URL(fileURLWithPath: arguments[1]))
        print("Book montage generated.")
    }
} catch {
    FileHandle.standardError.write(Data("\(error)\n".utf8))
    exit(1)
}
