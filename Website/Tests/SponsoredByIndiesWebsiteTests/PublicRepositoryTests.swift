import Foundation
import Testing

struct PublicRepositoryTests {
    @Test(arguments: [
        ("participations", "unapproved"), ("offers", "unapproved"),
        ("participations", "numeric approval"), ("offers", "numeric approval"),
        ("offers", "price note"), ("offers", "null price note")
    ])
    func approvalsAndPrivateNotesAreCheckedInBothIndexAndWorkingCopy(key: String, invalidContent: String) throws {
        let files = FileManager.default
        let root = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? files.removeItem(at: root) }
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let relativePath = "Website/Data/Conferences/example.json"
        let record = root.appendingPathComponent(relativePath)
        try files.createDirectory(at: record.deletingLastPathComponent(), withIntermediateDirectories: true)
        let script = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Scripts/CheckPublicRepository.swift")

        func run(_ executable: String, _ arguments: [String]) throws -> (status: Int32, output: String) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.currentDirectoryURL = root
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return (process.terminationStatus, String(decoding: data, as: UTF8.self))
        }
        func git(_ arguments: [String]) throws {
            let result = try run("/usr/bin/git", arguments)
            try #require(result.status == 0, "\(result.output)")
        }
        func writeRecord(allowed: Bool) throws {
            var entry: [String: Any] = ["publicationApproved": allowed]
            if invalidContent.contains("price note") {
                entry["publicationApproved"] = true
                if !allowed {
                    let note: Any = invalidContent == "null price note" ? NSNull() : "Internal follow-up"
                    entry["savingEstimate"] = ["selectionNote": note]
                }
            } else if !allowed && invalidContent == "numeric approval" {
                entry["publicationApproved"] = 1
            }
            let record: [String: Any] = [key: [entry], key == "offers" ? "participations" : "offers": []]
            let data = try JSONSerialization.data(withJSONObject: record)
            try data.write(to: root.appendingPathComponent(relativePath))
        }

        try git(["init", "-q"])
        try writeRecord(allowed: false)
        try git(["add", relativePath])
        try writeRecord(allowed: true)
        let stagedFailure = try run("/usr/bin/swift", [script.path])
        #expect(stagedFailure.status != 0)
        let failureLabel = invalidContent.contains("price note") ? "Price review notes" : "Unapproved \(key)"
        #expect(stagedFailure.output.contains("\(failureLabel) in staged"))

        try git(["add", relativePath])
        try writeRecord(allowed: false)
        let workingFailure = try run("/usr/bin/swift", [script.path])
        #expect(workingFailure.status != 0)
        #expect(workingFailure.output.contains("\(failureLabel) in working copy"))

        try writeRecord(allowed: true)
        let success = try run("/usr/bin/swift", [script.path])
        #expect(success.status == 0)
        #expect(success.output.contains("checks passed"))
    }
}
