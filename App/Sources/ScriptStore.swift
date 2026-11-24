import Foundation

/// Odak script'ini GitHub'dan günceller; böylece script değişiklikleri için
/// uygulamayı telefona yeniden yüklemek gerekmez.
///
/// Sıra: önbellekteki ve uygulama içindeki kopyadan sürümü yüksek olanı hemen kullan,
/// arka planda GitHub'daki sürümü indir, farklıysa kaydet ve sayfayı yenile.
enum ScriptStore {
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/barancarter1234-code/odak-app/main/App/odak.user.js")!

    private static var cacheURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("odak.user.js")
    }

    /// Şu an kullanılacak script.
    static func current() -> String {
        let cached = (try? String(contentsOf: cacheURL, encoding: .utf8)).flatMap { isValid($0) ? $0 : nil }
        let bundled = Bundle.main.url(forResource: "odak.user", withExtension: "js")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) }

        switch (cached, bundled) {
        case let (c?, b?):
            // Uygulama yeniden yüklendiyse içindeki kopya önbellekten yeni olabilir
            return isNewer(b, than: c) ? b : c
        case let (c?, nil):
            return c
        case let (nil, b?):
            return b
        default:
            return ""
        }
    }

    /// GitHub'daki sürümü indirir. Kullanılandan farklıysa kaydeder ve yeni metni verir; değilse nil.
    static func fetchUpdate(completion: @escaping (String?) -> Void) {
        var request = URLRequest(url: remoteURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        URLSession.shared.dataTask(with: request) { data, response, _ in
            var update: String?
            if let http = response as? HTTPURLResponse, http.statusCode == 200,
               let data = data, let text = String(data: data, encoding: .utf8),
               isValid(text), text != current() {
                try? text.write(to: cacheURL, atomically: true, encoding: .utf8)
                update = text
            }
            DispatchQueue.main.async { completion(update) }
        }.resume()
    }

    /// Hata sayfası gibi yanlış bir içerik enjekte edilmesin.
    private static func isValid(_ script: String) -> Bool {
        script.contains("==UserScript==") && script.contains("})();") && script.count > 1000
    }

    private static func version(of script: String) -> [Int] {
        guard let range = script.range(of: #"@version\s+[\d.]+"#, options: .regularExpression) else { return [] }
        let value = script[range].split(whereSeparator: { $0 == " " || $0 == "\t" }).last ?? ""
        return value.split(separator: ".").compactMap { Int($0) }
    }

    private static func isNewer(_ a: String, than b: String) -> Bool {
        let va = version(of: a)
        let vb = version(of: b)
        for i in 0..<max(va.count, vb.count) {
            let x = i < va.count ? va[i] : 0
            let y = i < vb.count ? vb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
