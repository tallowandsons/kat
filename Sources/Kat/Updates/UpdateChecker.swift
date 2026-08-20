import Foundation

/// Fetches the latest GitHub release tag for a repo and compares it against a version
/// string. Stateless by design — `UpdateAvailabilityMonitor` owns the polling/settings.
enum UpdateChecker {
    static func latestVersion(repo: String) async -> String? {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return nil }
        var request = URLRequest(url: url)
        request.setValue("Kat", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String
        else { return nil }

        return tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
    }

    /// Dotted-integer comparison (not full SemVer — a pre-release suffix like "-beta.1"
    /// just gets dropped by the `Int` parse). Good enough for tags like "1.2.0"/"v1.10.0".
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        func parts(_ version: String) -> [Int] { version.split(separator: ".").compactMap { Int($0) } }
        let a = parts(candidate)
        let b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
