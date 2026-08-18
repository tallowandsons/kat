import Foundation
import Testing
@testable import Kat

@Suite("ScriptRunner")
struct ScriptRunnerTests {
    /// Writes an executable shell script that touches `marker` when run.
    private func makeScript(writingTo marker: URL) throws -> URL {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sh")
        let contents = "#!/bin/sh\necho done > \"\(marker.path)\"\n"
        try contents.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        return scriptPath
    }

    private func waitUntilExists(_ url: URL, timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    @Test("Runs the script at the given path")
    func runsScript() async throws {
        let marker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let script = try makeScript(writingTo: marker)
        defer { try? FileManager.default.removeItem(at: script) }

        await MainActor.run { ScriptRunner.run(path: script.path) }

        #expect(await waitUntilExists(marker))
        try? FileManager.default.removeItem(at: marker)
    }

    @Test("Empty or whitespace-only paths are a no-op")
    func ignoresEmptyPath() async {
        // Just verifying this doesn't crash/throw — Process would fail fast on "".
        await MainActor.run {
            ScriptRunner.run(path: "")
            ScriptRunner.run(path: "   ")
        }
    }
}

@Suite("LifecycleScriptRunner")
struct LifecycleScriptRunnerTests {
    private func makeScript(writingTo marker: URL) throws -> URL {
        let scriptPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".sh")
        let contents = "#!/bin/sh\necho done > \"\(marker.path)\"\n"
        try contents.write(to: scriptPath, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptPath.path)
        return scriptPath
    }

    private func waitUntilExists(_ url: URL, timeout: TimeInterval = 3) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    @Test("Only enabled scripts run")
    @MainActor
    func onlyEnabledScriptsRun() async throws {
        let enabledMarker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let disabledMarker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let enabledScript = try makeScript(writingTo: enabledMarker)
        let disabledScript = try makeScript(writingTo: disabledMarker)
        defer {
            try? FileManager.default.removeItem(at: enabledScript)
            try? FileManager.default.removeItem(at: disabledScript)
        }

        let runner = LifecycleScriptRunner()
        runner.onStartScriptsProvider = {
            [
                LifecycleScript(label: "enabled", scriptPath: enabledScript.path, isEnabled: true),
                LifecycleScript(label: "disabled", scriptPath: disabledScript.path, isEnabled: false)
            ]
        }

        runner.runOnStartScripts()

        #expect(await waitUntilExists(enabledMarker))
        // Give the disabled one the same window it would've had, then confirm it never ran.
        try? await Task.sleep(nanoseconds: 200_000_000)
        #expect(!FileManager.default.fileExists(atPath: disabledMarker.path))

        try? FileManager.default.removeItem(at: enabledMarker)
    }
}
