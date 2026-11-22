import Foundation
import Testing
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

struct BookMontageTests {
    @Test func montageIsReproducibleTransparentAndPreservesOutputOnInvalidInput() throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let covers = try (0..<5).map { try fixture.cover(index: $0) }
        try fixture.save(entries: covers)
        let first = try fixture.run()
        try #require(first.status == 0, "\(first.message)")
        let original = try Data(contentsOf: fixture.output)
        let source = try #require(CGImageSourceCreateWithData(original as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.width == 1240 && image.height == 1500)
        #expect(image.alphaInfo != .none && image.alphaInfo != .noneSkipFirst && image.alphaInfo != .noneSkipLast)
        let pixels = try #require(image.dataProvider?.data)
        let bytes = try #require(CFDataGetBytePtr(pixels))
        #expect(bytes[3] == 0, "The outer canvas must stay transparent.")
        let second = try fixture.run()
        try #require(second.status == 0, "\(second.message)")
        #expect(try Data(contentsOf: fixture.output) == original)
        try fixture.save(entries: covers.reversed())
        let reversed = try fixture.run()
        try #require(reversed.status == 0, "\(reversed.message)")
        let reordered = try Data(contentsOf: fixture.output)
        #expect(reordered != original, "The manifest order controls the composition.")
        for invalid in [Array(covers.prefix(1)), [covers[0], covers[0]],
                        [covers[0], ["file": "missing.png", "title": "Missing book"]]] {
            try fixture.save(entries: invalid)
            #expect(try fixture.run().status != 0)
            #expect(try Data(contentsOf: fixture.output) == reordered)
        }
        try fixture.save(layout: "unknown", entries: covers)
        #expect(try fixture.run().status != 0)
        #expect(try Data(contentsOf: fixture.output) == reordered)
    }

    @Test(arguments: ["cover", "manifest", "cover-symlink", "manifest-symlink", "directory-symlink", "hard-link"])
    func sourceFilesCannotBeUsedAsOutput(alias: String) throws {
        // A .png manifest ensures the CLI's output-extension check cannot mask the source guard.
        let fixture = try Fixture(manifestName: "manifest.png")
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        try fixture.save(entries: [fixture.cover(index: 0), fixture.cover(index: 1)])
        let cover = fixture.root.appendingPathComponent("cover-0.png")
        let originalCover = try Data(contentsOf: cover)
        let originalManifest = try Data(contentsOf: fixture.manifest)
        let output: URL
        switch alias {
        case "cover": output = cover
        case "manifest": output = fixture.manifest
        case "directory-symlink":
            let directory = fixture.root.appendingPathComponent("linked-directory")
            try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: fixture.root)
            output = directory.appendingPathComponent(cover.lastPathComponent)
        case "hard-link":
            output = fixture.root.appendingPathComponent("linked-cover.png")
            try FileManager.default.linkItem(at: cover, to: output)
        default:
            output = fixture.root.appendingPathComponent("linked-source.png")
            try FileManager.default.createSymbolicLink(at: output,
                withDestinationURL: alias == "cover-symlink" ? cover : fixture.manifest)
        }
        let result = try fixture.run(output: output)
        #expect(result.status != 0)
        #expect(result.message.contains("must not replace a source cover or the manifest"))
        #expect(try Data(contentsOf: cover) == originalCover)
        #expect(try Data(contentsOf: fixture.manifest) == originalManifest)
    }

    @Test(arguments: 2...8)
    func orientedCoversRenderLikeUprightOriginals(orientation: Int) throws {
        let fixture = try Fixture()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let upright = try fixture.cover(index: 0)
        let second = try fixture.cover(index: 1)
        try fixture.save(entries: [upright, second])
        let reference = try fixture.run()
        try #require(reference.status == 0, "\(reference.message)")
        let expected = try Data(contentsOf: fixture.output)
        let oriented = try fixture.cover(index: 0, orientation: orientation)
        let source = fixture.root.appendingPathComponent(try #require(oriented["file"]))
        let original = try Data(contentsOf: source)
        try fixture.save(entries: [oriented, second])
        let result = try fixture.run()
        try #require(result.status == 0, "\(result.message)")
        #expect(try Data(contentsOf: fixture.output) == expected,
                "Rotations and mirrors must preserve the upright cover's pixels and proportions.")
        #expect(try Data(contentsOf: source) == original)
    }

    private struct Fixture {
        let root: URL
        let manifest: URL
        var output: URL { root.appendingPathComponent("series.png") }

        init(manifestName: String = "series.json") throws {
            root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            manifest = root.appendingPathComponent(manifestName)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func save(layout: String = "staggered-v1", entries: [[String: String]]) throws {
            try JSONSerialization.data(withJSONObject: ["layout": layout, "covers": entries]).write(to: manifest)
        }

        func run(output: URL? = nil) throws -> (status: Int32, message: String) {
            let script = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Scripts/MakeBookMontage.swift")
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/swift")
            process.arguments = [script.path, manifest.path, (output ?? self.output).path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            let response = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: response, as: UTF8.self))
        }

        func cover(index: Int, orientation: Int = 1) throws -> [String: String] {
            let width = orientation >= 5 ? 30 : 20
            let height = orientation >= 5 ? 20 : 30
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            // Asymmetric quadrants expose both rotations and mirrors. Store inverse EXIF
            // coordinates so every input describes the same upright 20 × 30 cover.
            for y in 0..<30 {
                for x in 0..<20 {
                    let stored: (Int, Int)
                    switch orientation {
                    case 2: stored = (19 - x, y)
                    case 3: stored = (19 - x, 29 - y)
                    case 4: stored = (x, 29 - y)
                    case 5: stored = (y, x)
                    case 6: stored = (y, 19 - x)
                    case 7: stored = (29 - y, 19 - x)
                    case 8: stored = (29 - y, x)
                    default: stored = (x, y)
                    }
                    let offset = (stored.1 * width + stored.0) * 4
                    pixels[offset] = x < 10 ? 255 : 0
                    pixels[offset + 1] = y < 15 ? 255 : 0
                    pixels[offset + 2] = UInt8(index * 40)
                    pixels[offset + 3] = 255
                }
            }
            let provider = try #require(CGDataProvider(data: Data(pixels) as CFData))
            let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
            let image = try #require(CGImage(width: width, height: height, bitsPerComponent: 8,
                bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            let filename = orientation == 1 ? "cover-\(index).png" : "cover-\(index)-orientation-\(orientation).png"
            let target = root.appendingPathComponent(filename)
            let writer = try #require(CGImageDestinationCreateWithURL(target as CFURL, UTType.png.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(writer, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
            try #require(CGImageDestinationFinalize(writer))
            return ["file": target.lastPathComponent, "title": "Book \(index)"]
        }
    }
}
