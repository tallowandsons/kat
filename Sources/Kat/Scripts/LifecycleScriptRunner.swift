import Foundation

/// Runs the enabled "on break start"/"on break end" scripts. Providers are read fresh on
/// each call — same pattern as `BreakScheduler.scheduleProvider` — so Preferences edits
/// (task 8) take effect without any explicit reload step.
@MainActor
final class LifecycleScriptRunner {
    var onStartScriptsProvider: () -> [LifecycleScript] = { [] }
    var onEndScriptsProvider: () -> [LifecycleScript] = { [] }

    func runOnStartScripts() {
        run(onStartScriptsProvider())
    }

    func runOnEndScripts() {
        run(onEndScriptsProvider())
    }

    private func run(_ scripts: [LifecycleScript]) {
        for script in scripts where script.isEnabled {
            ScriptRunner.run(path: script.scriptPath)
        }
    }
}
