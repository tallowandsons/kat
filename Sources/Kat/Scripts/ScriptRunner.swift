import Foundation

/// Runs a user-provided shell command/script path, fire-and-forget. Used by lifecycle
/// scripts (on break start/end) and custom overlay buttons alike.
enum ScriptRunner {
    static func run(path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", trimmed]
        process.terminationHandler = { proc in
            if proc.terminationStatus != 0 {
                Log.scripts.error("Exited \(proc.terminationStatus, privacy: .public): \(trimmed, privacy: .public)")
            }
        }

        do {
            try process.run()
        } catch {
            Log.scripts.error("Failed to launch \(trimmed, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }
}
