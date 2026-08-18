import Foundation

/// Pauses whatever's currently playing via `MediaRemote.framework`'s private
/// `MRMediaRemoteSendCommand` API — the same technique `nowplaying-cli` uses under the
/// hood (confirmed by inspecting its binary's symbol table), reimplemented natively here
/// via `dlopen`/`dlsym` so Kat doesn't depend on an external Homebrew-installed tool.
///
/// MediaRemote has no public headers — the command constants below are reverse-engineered
/// values used consistently across the open-source "Now Playing" tooling ecosystem, not
/// documented by Apple. This only affects apps/sites that register with the system's Now
/// Playing info center (`MPNowPlayingInfoCenter`) in the first place — e.g. Music, Spotify,
/// Safari video/audio — a custom app with no Now Playing integration can't be controlled
/// this way by anything, including Control Center's own media controls.
enum MediaController {
    private static let mediaRemotePath = "/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote"
    private static let kMRPause: Int32 = 1

    private typealias SendCommandFunction = @convention(c) (Int32, AnyObject?) -> Bool

    static func pausePlayingMedia() {
        guard let handle = dlopen(mediaRemotePath, RTLD_LAZY) else {
            Log.media.error("Could not load MediaRemote.framework")
            return
        }
        defer { dlclose(handle) }

        guard let symbol = dlsym(handle, "MRMediaRemoteSendCommand") else {
            Log.media.error("MRMediaRemoteSendCommand symbol not found")
            return
        }

        let sendCommand = unsafeBitCast(symbol, to: SendCommandFunction.self)
        let dispatched = sendCommand(kMRPause, nil)
        Log.media.info("Pause command dispatched: \(dispatched, privacy: .public)")
    }
}
