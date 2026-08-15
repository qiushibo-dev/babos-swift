import Foundation

/// 更新確認。HTML 版から移植。
///
/// リポジトリが public なので GitHub の API は認証なしで叩ける。
/// Releases の最新タグと自分のバージョンを比べるだけ。
///
/// **アプリ内でダウンロードして入れ替えることはしない。**
/// それをやるには署名の検証まで含む仕組みが要る。ここは
/// 「新しいのが出ているか」を答えるところまで。
enum UpdateState: Equatable {
    case idle
    case checking
    case latest
    case available(String)
    case failed(String)
}

private struct GitHubRelease: Decodable {
    let tag_name: String
}

enum Version {
    /// "v0.1.10" → [0, 1, 10]。数字以外は捨てる
    static func parts(_ s: String) -> [Int] {
        s.hasPrefix("v") ? String(s.dropFirst()).split(separator: ".").map { Int($0) ?? 0 }
                         : s.split(separator: ".").map { Int($0) ?? 0 }
    }

    /// **数値で比べる。** 文字列比較だと "0.1.10" < "0.1.9" になり、
    /// 版号が二桁に乗った瞬間に「最新です」と嘘をつく。
    static func isNewer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let d = (i < x.count ? x[i] : 0) - (i < y.count ? y[i] : 0)
            if d != 0 { return d > 0 }
        }
        return false
    }
}

extension Store {

    /// Info.plist から。build.sh が書いているので二重管理にならない
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static let releasesURL = "https://github.com/qiushibo-dev/babos-swift/releases"
    private static let latestAPI =
        "https://api.github.com/repos/qiushibo-dev/babos-swift/releases/latest"

    func checkUpdate() async {
        updateState = .checking
        do {
            var req = URLRequest(url: URL(string: Self.latestAPI)!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 10

            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard http.statusCode == 200 else {
                throw NSError(domain: "GitHub", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }

            let tag = try JSONDecoder().decode(GitHubRelease.self, from: data).tag_name
            // **失敗を黙って飲まない。** オフラインなのか API 側なのかを出す
            updateState = Version.isNewer(tag, than: appVersion) ? .available(tag) : .latest
        } catch {
            updateState = .failed(error.localizedDescription)
        }
    }
}
