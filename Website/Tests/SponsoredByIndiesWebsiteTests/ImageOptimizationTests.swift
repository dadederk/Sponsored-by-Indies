import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

@testable import SponsoredByIndiesWebsite

struct ImageOptimizationTests {
    @Test func webPCopiesCannotOverwritePNGsWithTheSameName() {
        let webP = ImageOptimization.path(for: "/portraits/builder.webp")
        #expect(webP.hasSuffix(".png"))
        #expect(webP != ImageOptimization.path(for: "/portraits/builder.png"))
    }

    @Test(arguments: [(400, 400, 192, 192), (200, 400, 96, 192), (32, 16, 32, 16)])
    func cardCopiesKeepProportionsAndNeverUpscale(width: Int, height: Int, expectedWidth: Int, expectedHeight: Int) throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "original.png")
        let output = root.appending(path: "copy.png")
        try fixture(width: width, height: height, at: source)
        let original = try Data(contentsOf: source)
        try ImageOptimization.resize(source, to: output, maximumDimension: 192)
        let image = try decode(output)
        #expect(image.width == expectedWidth)
        #expect(image.height == expectedHeight)
        #expect(image.alphaInfo == .premultipliedLast || image.alphaInfo == .last)
        #expect(image.colorSpace?.name == CGColorSpace.sRGB)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test func rotatedPortraitsUseTheirDisplayOrientation() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "portrait.jpg")
        let output = root.appending(path: "copy.jpg")
        try fixture(width: 40, height: 20, at: source, orientation: 6)
        try ImageOptimization.resize(source, to: output, maximumDimension: 20)
        let image = try decode(output)
        #expect(image.width == 10)
        #expect(image.height == 20)
    }

    @Test func resamplingRetainsWideGamutColourSpace() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "original.png")
        let output = root.appending(path: "copy.png")
        try fixture(width: 128, height: 128, at: source, colourSpaceName: CGColorSpace.displayP3)
        try ImageOptimization.resize(source, to: output, maximumDimension: 32)
        #expect(try decode(output).colorSpace?.name == CGColorSpace.displayP3)
    }

    @Test func deliveryCopiesUseEightBitsWithoutChangingTheMaster() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "master.png")
        let output = root.appending(path: "copy.png")
        try fixture(width: 256, height: 256, at: source, bitsPerComponent: 16)
        #expect(try decode(source).bitsPerComponent == 16)
        try ImageOptimization.resize(source, to: output, maximumDimension: 192)
        #expect(try decode(output).bitsPerComponent == 8)
        #expect(try decode(source).bitsPerComponent == 16)
    }

    @Test func pngCompressionPreservesPixelsAndColourProfile() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appending(path: "image.png")
        try fixture(width: 64, height: 64, at: file)
        let before = try decode(file)
        // Decode now: CGImage may otherwise read the file lazily after replacement.
        let beforePixels = try pixels(before)
        let beforeColourSpace = before.colorSpace?.name
        let size = try Data(contentsOf: file).count
        try ImageOptimization.compressPNGs(in: root)
        let after = try decode(file)
        let afterPixels = try pixels(after)
        #expect(beforePixels == afterPixels)
        #expect(beforeColourSpace == after.colorSpace?.name)
        #expect(try Data(contentsOf: file).count <= size)
    }

    @Test func invalidImagesFailInsteadOfPublishingBrokenCopies() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appending(path: "broken.png")
        try Data("Not an image".utf8).write(to: source)
        #expect(throws: CatalogError.self) {
            try ImageOptimization.resize(source, to: root.appending(path: "copy.png"), maximumDimension: 192)
        }
    }

    @Test func cachedPNGsFollowInputChangesAndRecoverFromCorruption() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let images = root.appending(path: "images")
        let cache = root.appending(path: "cache")
        try FileManager.default.createDirectory(at: images, withIntermediateDirectories: true)
        let file = images.appending(path: "image.png")
        try fixture(width: 64, height: 64, at: file)
        let original = try Data(contentsOf: file)
        try ImageOptimization.compressPNGs(in: images, cacheDirectory: cache)
        let compressed = try Data(contentsOf: file)
        try original.write(to: file)
        try ImageOptimization.compressPNGs(in: images, cacheDirectory: cache)
        #expect(try Data(contentsOf: file) == compressed)
        try fixture(width: 32, height: 32, at: file)
        try ImageOptimization.compressPNGs(in: images, cacheDirectory: cache)
        #expect(try decode(file).width == 32)
        for cached in try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: nil) {
            try Data("Broken cache".utf8).write(to: cached)
        }
        try original.write(to: file)
        try ImageOptimization.compressPNGs(in: images, cacheDirectory: cache)
        #expect(try decode(file).width == 64)
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func fixture(width: Int, height: Int, at url: URL, orientation: Int = 1,
                         colourSpaceName: CFString = CGColorSpace.sRGB, bitsPerComponent: Int = 8) throws {
        let colourSpace = try #require(CGColorSpace(name: colourSpaceName))
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: bitsPerComponent,
            bytesPerRow: width * 4 * bitsPerComponent / 8, space: colourSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.8, green: 0.2, blue: 0.1, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
        let type = url.pathExtension == "jpg" ? UTType.jpeg : UTType.png
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, try #require(context.makeImage()), [kCGImagePropertyOrientation: orientation] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))
    }

    private func decode(_ url: URL) throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func pixels(_ image: CGImage) throws -> Data {
        let colourSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8,
            bytesPerRow: image.width * 4, space: colourSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Data(bytes: try #require(context.data), count: image.width * image.height * 4)
    }
}
