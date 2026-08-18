import Darwin
import Foundation

/// The subset of `BreakScheduler` state shared with `KatSaver.saver` via a JSON file on
/// disk — the screensaver runs in a separate process (loaded by the system's screensaver
/// host), so it can't read `BreakScheduler` in memory directly. This file is compiled
/// into both Kat.app (via SwiftPM) and KatSaver.saver (via Scripts/build-saver.sh passing
/// it directly to swiftc) so the two stay in sync without duplicating the type by hand.
struct BreakStatus: Codable {
    enum Phase: String, Codable {
        case idle
        case onBreak
    }

    var phase: Phase
    var breakEndDate: Date?
    var nextBreakDate: Date?
    /// True only once a password is actually required — see `LockStateMonitor` for why
    /// this is polled from Kat.app rather than queried from inside the screensaver.
    var isScreenLocked: Bool = false
    /// Non-nil while `phase == .idle` means: show this instead of the "next break in…"
    /// countdown. Set when a break ends and cleared once the screensaver actually
    /// disengages (the user returned) — a glance mid-away-time at "next break in 47:12"
    /// right after a break ended reads ambiguously close to what was shown *during* the
    /// break, so this stays sticky until they've actually come back.
    var breakOverMessage: String?

    static let fileURL: URL = {
        URL(fileURLWithPath: realHomeDirectory())
            .appendingPathComponent("Library/Application Support/Kat", isDirectory: true)
            .appendingPathComponent("BreakStatus.json")
    }()

    /// `FileManager`/`NSHomeDirectory()`-based path resolution gets silently redirected to
    /// a sandboxed app's own container — the screensaver host (`legacyScreenSaver.appex`)
    /// is sandboxed, so those APIs would point at its container, not Kat's real shared
    /// file, even though the extension's `temporary-exception.files.absolute-path.read-only`
    /// entitlement covers "/" and would happily read the right path if given one. `getpwuid`
    /// queries the user database directly, bypassing that redirection.
    private static func realHomeDirectory() -> String {
        if let pw = getpwuid(getuid()), let homeDir = pw.pointee.pw_dir {
            return String(cString: homeDir)
        }
        return NSHomeDirectory()
    }

    func write() {
        do {
            try FileManager.default.createDirectory(
                at: Self.fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(self)
            try data.write(to: Self.fileURL, options: .atomic)
        } catch {
            // No shared logger here since this file is compiled standalone into the
            // screensaver too (which doesn't link Kat's Logging.swift); NSLog works
            // in both contexts without extra plumbing.
            NSLog("[Kat] BreakStatus.write() failed: \(error)")
        }
    }

    static func read() -> BreakStatus? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(BreakStatus.self, from: data)
    }
}
