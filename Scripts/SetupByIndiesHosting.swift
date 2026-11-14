import Foundation
import Darwin

let sourceRepository = "dadederk/Sponsored-by-Indies"
let publicationRepository = "dadederk/By-Indies-Pages"
let domain = "byindies.com"
let publicationDescription = "Independent projects and the people who make them. Generated from Sponsored by Indies."
let secretName = "BY_INDIES_PAGES_TOKEN"
let variableName = "BY_INDIES_PAGES_REPOSITORY"

struct SetupError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

var commandTimeout: TimeInterval = 60

func progress(_ message: String) {
    print(message)
    fflush(stdout)
}

func command(_ arguments: [String]) throws -> (status: Int32, output: String) {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
    process.arguments = ["gh"] + arguments
    // A file cannot fill a pipe buffer while the parent waits for completion.
    let log = FileManager.default.temporaryDirectory.appending(path: "by-indies-command-\(UUID().uuidString).log")
    guard FileManager.default.createFile(atPath: log.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
        throw SetupError("Could not create a temporary command log.")
    }
    defer { try? FileManager.default.removeItem(at: log) }
    let output = try FileHandle(forWritingTo: log)
    defer { try? output.close() }
    process.standardOutput = output
    process.standardError = output
    let completed = DispatchSemaphore(value: 0)
    process.terminationHandler = { _ in completed.signal() }
    try process.run()
    if completed.wait(timeout: .now() + commandTimeout) == .timedOut {
        process.terminate()
        if completed.wait(timeout: .now() + 2) == .timedOut {
            kill(process.processIdentifier, SIGKILL)
        }
        process.waitUntilExit()
        throw SetupError("GitHub command timed out after \(Int(commandTimeout)) seconds: gh \(arguments.joined(separator: " ")). No later setup steps were run. Check your connection and retry.")
    }
    process.waitUntilExit()
    let data = try Data(contentsOf: log)
    return (process.terminationStatus, String(decoding: data, as: UTF8.self))
}

func checkedCommand(_ arguments: [String]) throws -> String {
    let result = try command(arguments)
    guard result.status == 0 else { throw SetupError(result.output.isEmpty ? "GitHub command failed." : result.output) }
    return result.output
}

func api(_ path: String, method: String = "GET", fields: [String: Any]? = nil, allowMissing: Bool = false) throws -> Any? {
    var arguments = ["api", path, "--method", method]
    // JSON files preserve booleans and nested Pages configuration without shell quoting.
    let file = FileManager.default.temporaryDirectory.appending(path: "by-indies-setup-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: file) }
    if let fields {
        try JSONSerialization.data(withJSONObject: fields).write(to: file, options: .atomic)
        arguments += ["--input", file.path]
    }
    let result = try command(arguments)
    if allowMissing && result.status != 0 && result.output.contains("(HTTP 404)") { return nil }
    guard result.status == 0 else { throw SetupError(result.output) }
    guard !result.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return try JSONSerialization.jsonObject(with: Data(result.output.utf8))
}

func repository(_ name: String, allowMissing: Bool = false) throws -> [String: Any]? {
    try api("repos/\(name)", allowMissing: allowMissing) as? [String: Any]
}

func enableHTTPS() throws {
    progress("Checking HTTPS…")
    guard let pages = try api("repos/\(publicationRepository)/pages") as? [String: Any],
          pages["cname"] as? String == domain else {
        throw SetupError("Configure the publication’s Pages custom domain as \(domain) first.")
    }
    if pages["https_enforced"] as? Bool == true {
        print("HTTPS is already enforced.")
    } else if (pages["https_certificate"] as? [String: Any])?["state"] as? String == "approved" {
        _ = try api("repos/\(publicationRepository)/pages", method: "PUT", fields: ["https_enforced": true])
        print("HTTPS is now enforced.")
    } else {
        print("The HTTPS certificate is not ready. After DNS settles, run this script with --enable-https again.")
    }
}

func configureHosting() throws {
    progress("Checking GitHub access…")
    guard let source = try repository(sourceRepository),
          (source["permissions"] as? [String: Any])?["admin"] as? Bool == true else {
        throw SetupError("The signed-in GitHub account needs admin access to \(sourceRepository).")
    }
    let sourcePages = try api("repos/\(sourceRepository)/pages", allowMissing: true) as? [String: Any]
    if let cname = sourcePages?["cname"] as? String, cname != "sponsored.byindies.com" {
        throw SetupError("The source repository uses another Pages domain (\(cname)). Review it before continuing.")
    }
    progress("Checking the publication repository…")
    var target = try repository(publicationRepository, allowMissing: true)
    let created = target == nil
    if created {
        print("Creating \(publicationRepository)…")
        _ = try checkedCommand(["repo", "create", publicationRepository, "--public", "--add-readme",
                                "--description", publicationDescription,
                                "--homepage", "https://\(domain)", "--disable-issues", "--disable-wiki"])
        target = try repository(publicationRepository)
    }
    guard let target, target["private"] as? Bool == false,
          (target["permissions"] as? [String: Any])?["admin"] as? Bool == true else {
        throw SetupError("The publication repository must be public and accessible to your account as an admin.")
    }
    if let branch = target["default_branch"] as? String, branch != "main" {
        guard created, let encoded = branch.addingPercentEncoding(withAllowedCharacters: .alphanumerics) else {
            throw SetupError("The existing publication repository needs a main branch.")
        }
        _ = try api("repos/\(publicationRepository)/branches/\(encoded)/rename", method: "POST", fields: ["new_name": "main"])
    }
    // Reuse a starter repository or our generated publication, never an unrelated project.
    if !created {
        let contents = try api("repos/\(publicationRepository)/contents") as? [[String: Any]] ?? []
        let names = Set(contents.compactMap { $0["name"] as? String })
        let readme = try api("repos/\(publicationRepository)/contents/README.md", allowMissing: true) as? [String: Any]
        let data = (readme?["content"] as? String).flatMap { Data(base64Encoded: $0, options: .ignoreUnknownCharacters) }
        let text = data.map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        let heading = "# " + publicationRepository.split(separator: "/").last!
        let starter = names.contains("README.md") && names.isSubset(of: ["README.md", "CNAME", ".nojekyll"]) &&
            [heading, heading + "\n" + publicationDescription, heading + "\n\n" + publicationDescription].contains(text)
        let generated = text.hasPrefix("<!-- Generated by Sponsored-by-Indies. Edit the source repository. -->")
        guard starter || generated else { throw SetupError("The destination contains another project. Its contents have not been changed.") }
    }
    var pages = try api("repos/\(publicationRepository)/pages", allowMissing: true) as? [String: Any]
    if let cname = pages?["cname"] as? String, cname != domain {
        throw SetupError("The publication already serves another domain (\(cname)). Its repository and Pages settings have not been changed.")
    }
    progress("Configuring repository details…")
    _ = try api("repos/\(publicationRepository)", method: "PATCH", fields: [
        "description": publicationDescription,
        "homepage": "https://\(domain)", "has_issues": false, "has_wiki": false, "has_projects": false
    ])
    progress("Configuring Pages…")
    let branch: [String: Any] = ["branch": "main", "path": "/"]
    if pages == nil {
        _ = try api("repos/\(publicationRepository)/pages", method: "POST", fields: ["build_type": "legacy", "source": branch])
    }
    _ = try api("repos/\(publicationRepository)/pages", method: "PUT", fields: ["build_type": "legacy", "source": branch, "cname": domain])
    pages = try api("repos/\(publicationRepository)/pages") as? [String: Any]
    guard pages?["cname"] as? String == domain else { throw SetupError("GitHub did not save the custom domain.") }
    print("Pages is configured for \(domain), using main and / (root).")

    progress("Checking the publishing secret…")
    let secrets = try checkedCommand(["secret", "list", "--repo", sourceRepository, "--json", "name"])
    let names = try JSONSerialization.jsonObject(with: Data(secrets.utf8)) as? [[String: String]] ?? []
    if !names.contains(where: { $0["name"] == secretName }) {
        throw SetupError("The publishing secret has not been saved. Run gh secret set \(secretName) --repo \(sourceRepository) directly in your Terminal, then rerun this script. Create a fine-grained token for \(publicationRepository) with Contents: read and write if you do not already have one.")
    }

    // Enable the publishing job only once its destination and credential are ready.
    progress("Setting the publishing repository variable…")
    _ = try checkedCommand(["variable", "set", variableName, "--repo", sourceRepository, "--body", publicationRepository])
    print("The source repository’s publishing secret and variable are configured.")
    try enableHTTPS()
    print("Commit and push the reviewed source changes to main to publish Sponsored by Indies and its showcase preview page.")
    print("Publishing to the separate By Indies repository also requires BY_INDIES_PUBLISH_ENABLED=true when you are ready to launch.")
    print("Then set the apex DNS A records to 185.199.108.153, 185.199.109.153, 185.199.110.153 and 185.199.111.153.")
    print("Keep sponsored as a CNAME to dadederk.github.io. DNS has not been changed by this script.")
}

do {
    var arguments = Array(CommandLine.arguments.dropFirst())
    if let index = arguments.firstIndex(of: "--timeout") {
        guard arguments.indices.contains(index + 1), let seconds = Int(arguments[index + 1]), (1...300).contains(seconds) else {
            throw SetupError("--timeout requires a number of seconds from 1 to 300.")
        }
        commandTimeout = TimeInterval(seconds)
        arguments.removeSubrange(index...index + 1)
    }
    switch arguments {
    case [], ["--dry-run"]:
        print("By Indies hosting setup — no changes made.")
        print("With --apply, this script will:")
        print("• Create or reuse \(publicationRepository), with a public main branch.")
        print("• Set its description and website link; direct contributions and issues to the source repository.")
        print("• Configure branch-based Pages hosting for \(domain).")
        print("• Check for \(secretName), then set \(variableName) on \(sourceRepository).")
        print("• Enforce HTTPS if its certificate is ready.")
        print("Run: swift Scripts/SetupByIndiesHosting.swift --apply")
    case ["--apply"]: try configureHosting()
    case ["--enable-https"]: try enableHTTPS()
    default: throw SetupError("Use --dry-run, --apply or --enable-https, with optional --timeout seconds.")
    }
} catch {
    FileHandle.standardError.write(Data("Setup stopped: \(error)\n".utf8))
    exit(1)
}
