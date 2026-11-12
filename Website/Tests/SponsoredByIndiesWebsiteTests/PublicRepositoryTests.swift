import Foundation
import Testing

struct PublicRepositoryTests {
    @Test(arguments: ["participations", "offers"])
    func approvalsAreCheckedInBothIndexAndWorkingCopy(key: String) throws {
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
        func writeRecord(approved: Bool) throws {
            let data = try JSONSerialization.data(withJSONObject: [
                key: [["publicationApproved": approved]], key == "offers" ? "participations" : "offers": []
            ])
            try data.write(to: record)
        }

        try git(["init", "-q"])
        try writeRecord(approved: false)
        try git(["add", relativePath])
        try writeRecord(approved: true)
        let stagedFailure = try run("/usr/bin/swift", [script.path])
        #expect(stagedFailure.status != 0)
        #expect(stagedFailure.output.contains("Unapproved \(key) in staged"))

        try git(["add", relativePath])
        try writeRecord(approved: false)
        let workingFailure = try run("/usr/bin/swift", [script.path])
        #expect(workingFailure.status != 0)
        #expect(workingFailure.output.contains("Unapproved \(key) in working copy"))

        try writeRecord(approved: true)
        let success = try run("/usr/bin/swift", [script.path])
        #expect(success.status == 0)
        #expect(success.output.contains("checks passed"))
    }
}
