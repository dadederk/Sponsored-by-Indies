import Foundation
import Testing
@testable import SponsoredByIndiesWebsite

struct BuildOutputTests {
    @Test func replacementRemovesObsoletePagesAndFailureRestoresPreviousOutput() throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        let output = root.appendingPathComponent("Build")
        let staging = root.appendingPathComponent("staging")
        try files.createDirectory(at: output, withIntermediateDirectories: true)
        try files.createDirectory(at: staging, withIntermediateDirectories: true)
        try "obsolete profile".write(to: output.appendingPathComponent("old.html"), atomically: true, encoding: .utf8)
        try "new page".write(to: staging.appendingPathComponent("index.html"), atomically: true, encoding: .utf8)
        try BuildOutput.install(staging, at: output)
        #expect(!files.fileExists(atPath: output.appendingPathComponent("old.html").path))
        #expect(try String(contentsOf: output.appendingPathComponent("index.html"), encoding: .utf8) == "new page")
        #expect(throws: (any Error).self) { try BuildOutput.install(staging, at: output) }
        #expect(try String(contentsOf: output.appendingPathComponent("index.html"), encoding: .utf8) == "new page")
    }
}
