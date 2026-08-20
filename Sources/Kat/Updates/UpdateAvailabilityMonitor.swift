import AppKit
import Observation

/// Polls GitHub for a newer release than the one currently running, gated by
/// `SettingsStore.checkForUpdates`. The repo is read from Info.plist's "GHRepo" key,
/// which `Scripts/build-app.sh` derives from the git remote at build time — blank (no
/// GitHub remote) means the key is omitted entirely and checks are silently disabled.
@MainActor
@Observable
final class UpdateAvailabilityMonitor {
    private(set) var availableVersion: String?

    @ObservationIgnored
    var checkForUpdatesProvider: () -> Bool = { true }

    @ObservationIgnored
    nonisolated(unsafe) private var timer: Timer?

    private var githubRepo: String? {
        (Bundle.main.object(forInfoDictionaryKey: "GHRepo") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    var releasesURL: URL? {
        githubRepo.flatMap { URL(string: "https://github.com/\($0)/releases/latest") }
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        Task { await check() }
        let timer = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Re-run immediately, e.g. right after the user flips the Preferences toggle on.
    func recheck() {
        Task { await check() }
    }

    private func check() async {
        guard checkForUpdatesProvider(), let repo = githubRepo else {
            availableVersion = nil
            return
        }
        guard let latest = await UpdateChecker.latestVersion(repo: repo) else { return }
        let current = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        availableVersion = UpdateChecker.isNewer(latest, than: current) ? latest : nil
    }
}
