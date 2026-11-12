import Foundation

// Check the index as well as the working tree so accidentally staged notes fail.
let git = Process()
git.executableURL = URL(fileURLWithPath: "/usr/bin/git")
git.arguments = ["ls-files", "-z"]
let output = Pipe()
git.standardOutput = output
try git.run()
let data = output.fileHandleForReading.readDataToEndOfFile()
git.waitUntilExit()
guard git.terminationStatus == 0 else { fatalError("Could not inspect tracked files.") }

let paths = String(decoding: data, as: UTF8.self).split(separator: "\0").map(String.init)
let rootFiles = Set(["README.md", "AGENTS.md", ".gitignore", ".github/workflows/pages.yml", "Scripts/CheckPublicRepository.swift", "Images/readme-banner.png"])
let websiteFiles = Set(["Website/Package.swift", "Website/Package.resolved"])
let websiteFolders = ["Website/Sources/", "Website/Tests/", "Website/Assets/", "Website/Data/"]
let unexpected = paths.filter { path in
    if rootFiles.contains(path) { return false }
    if path.lowercased().hasSuffix(".md") { return true }
    return !websiteFiles.contains(path) && !websiteFolders.contains(where: { path.hasPrefix($0) })
}
guard unexpected.isEmpty else {
    fatalError("Files outside the public website allowlist: \(unexpected.joined(separator: ", "))")
}

let conferences = URL(fileURLWithPath: "Website/Data/Conferences")
for file in try FileManager.default.contentsOfDirectory(at: conferences, includingPropertiesForKeys: nil)
    where file.pathExtension == "json" {
    let record = try JSONSerialization.jsonObject(with: Data(contentsOf: file)) as? [String: Any]
    for key in ["participations", "offers"] {
        guard let entries = record?[key] as? [[String: Any]] else {
            fatalError("Missing \(key) in \(file.lastPathComponent).")
        }
        guard entries.allSatisfy({ ($0["publicationApproved"] as? Bool) == true }) else {
            fatalError("Unapproved \(key) must stay in private planning, outside public source.")
        }
    }
}
print("Public repository file and publication-approval checks passed.")
