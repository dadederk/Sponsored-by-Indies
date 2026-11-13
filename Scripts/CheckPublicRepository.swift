import Foundation
import CoreFoundation

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func gitOutput(_ arguments: [String]) throws -> Data {
    let git = Process()
    git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    git.arguments = arguments
    let output = Pipe()
    git.standardOutput = output
    try git.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    git.waitUntilExit()
    guard git.terminationStatus == 0 else { fail("Could not inspect the Git index.") }
    return data
}

func checkApprovals(_ data: Data, context: String) throws {
    let record = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    for key in ["participations", "offers"] {
        guard let entries = record?[key] as? [[String: Any]] else {
            fail("Missing \(key) in \(context).")
        }
        // JSONSerialization also bridges the number 1 to Bool; approval requires JSON true.
        guard entries.allSatisfy({ entry in
            guard let approval = entry["publicationApproved"] as? NSNumber,
                  CFGetTypeID(approval) == CFBooleanGetTypeID() else { return false }
            return approval.boolValue
        }) else {
            fail("Unapproved \(key) in \(context) must stay in private planning, outside public source.")
        }
        if key == "offers", entries.contains(where: {
            ($0["savingEstimate"] as? [String: Any])?.keys.contains("selectionNote") == true
        }) {
            fail("Price review notes in \(context) must stay in private planning, outside public source.")
        }
    }
}

// Check the index as well as the working tree so accidentally staged notes fail.
let data = try gitOutput(["ls-files", "-z"])

let paths = String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
let rootFiles = Set(["README.md", "AGENTS.md", ".gitignore", ".github/workflows/pages.yml", "Scripts/CheckPublicRepository.swift", "Images/readme-banner.png"])
let websiteFiles = Set(["Website/Package.swift", "Website/Package.resolved", "Website/package.json",
                        "Website/package-lock.json", "Website/playwright.config.mjs"])
let websiteFolders = ["Website/Sources/", "Website/Tests/", "Website/Assets/", "Website/Data/"]
let unexpected = paths.filter { path in
    if rootFiles.contains(path) { return false }
    if path.lowercased().hasSuffix(".md") { return true }
    return !websiteFiles.contains(path) && !websiteFolders.contains(where: { path.hasPrefix($0) })
}
guard unexpected.isEmpty else {
    fail("Files outside the public website allowlist: \(unexpected.joined(separator: ", "))")
}

// Read the actual indexed blobs: the working copy may already have been fixed
// without staging that correction, leaving an unapproved record in the commit.
for path in paths where path.hasPrefix("Website/Data/Conferences/") && path.hasSuffix(".json") {
    try checkApprovals(gitOutput(["show", ":\(path)"]), context: "staged \(path)")
}

let conferences = URL(fileURLWithPath: "Website/Data/Conferences")
for file in try FileManager.default.contentsOfDirectory(at: conferences, includingPropertiesForKeys: nil)
    where file.pathExtension == "json" {
    try checkApprovals(Data(contentsOf: file), context: "working copy \(file.lastPathComponent)")
}
print("Public repository file and publication-approval checks passed.")
