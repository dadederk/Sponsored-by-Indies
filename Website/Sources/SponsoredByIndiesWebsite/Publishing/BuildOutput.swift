import Foundation

enum BuildOutput {
    /// Replace the whole generated tree, restoring the old output if moving fails.
    static func install(_ staging: URL, at destination: URL) throws {
        let files = FileManager.default
        let backup = staging.deletingLastPathComponent().appendingPathComponent("backup-\(UUID().uuidString)")
        let hasPrevious = files.fileExists(atPath: destination.path)
        if hasPrevious { try files.moveItem(at: destination, to: backup) }
        do {
            try files.moveItem(at: staging, to: destination)
        } catch {
            if hasPrevious { try files.moveItem(at: backup, to: destination) }
            throw error
        }
        if hasPrevious { try files.removeItem(at: backup) }
    }
}
