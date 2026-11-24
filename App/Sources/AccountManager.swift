import Foundation
import WebKit

struct InstagramAccount: Codable, Equatable {
    var username: String
    var avatarURL: String?
}

/// Instagram hesapları arasında geçiş (Instagram uygulamasındaki gibi).
/// Her hesabın instagram.com çerezleri telefonda ayrı saklanır; geçişte çerezler değiştirilir.
final class AccountManager {
    static let shared = AccountManager()

    private(set) var accounts: [InstagramAccount] = []
    /// Şu an giriş yapılmış hesap (sayfadan öğrenilir).
    private(set) var current: String?

    private let defaults = UserDefaults.standard
    private let listKey = "odak.instagram.accounts"
    private let currentKey = "odak.instagram.current"

    private init() {
        if let data = defaults.data(forKey: listKey),
           let list = try? JSONDecoder().decode([InstagramAccount].self, from: data) {
            accounts = list
        }
        current = defaults.string(forKey: currentKey)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(accounts) {
            defaults.set(data, forKey: listKey)
        }
        defaults.set(current, forKey: currentKey)
    }

    /// Sayfada giriş yapılmış hesap görüldü: listeye ekle ve "şu anki" yap.
    func didSeeProfile(username: String, avatarURL: String?) {
        if let index = accounts.firstIndex(where: { $0.username == username }) {
            if let avatar = avatarURL { accounts[index].avatarURL = avatar }
        } else {
            accounts.append(InstagramAccount(username: username, avatarURL: avatarURL))
        }
        current = username
        persist()
    }

    /// Hesabı listeden ve telefondan kaldırır (şu anki hesap kaldırılamaz).
    func remove(username: String) {
        guard username != current else { return }
        accounts.removeAll { $0.username == username }
        try? FileManager.default.removeItem(at: cookieFile(for: username))
        persist()
    }

    func switchAccount(to username: String, cookieStore: WKHTTPCookieStore, completion: @escaping () -> Void) {
        guard username != current else {
            completion()
            return
        }
        swapCookies(in: cookieStore, restoring: username) {
            self.current = username
            self.persist()
            completion()
        }
    }

    /// Yeni hesapla giriş için şu anki hesabı saklayıp oturumu kapatır (hesap silinmez).
    func prepareNewLogin(cookieStore: WKHTTPCookieStore, completion: @escaping () -> Void) {
        swapCookies(in: cookieStore, restoring: nil) {
            self.current = nil
            self.persist()
            completion()
        }
    }

    // MARK: Çerezler

    private func isInstagramCookie(_ cookie: HTTPCookie) -> Bool {
        let domain = cookie.domain.lowercased()
        return domain == "instagram.com" || domain.hasSuffix(".instagram.com")
    }

    /// Şu anki hesabın çerezlerini saklar, siler ve (varsa) hedef hesabınkileri yükler.
    private func swapCookies(in store: WKHTTPCookieStore, restoring username: String?, completion: @escaping () -> Void) {
        store.getAllCookies { all in
            let instagram = all.filter { self.isInstagramCookie($0) }
            if let current = self.current {
                self.saveCookies(instagram, for: current)
            }

            let removal = DispatchGroup()
            for cookie in instagram {
                removal.enter()
                store.delete(cookie) { removal.leave() }
            }
            removal.notify(queue: .main) {
                let restore = username.map { self.loadCookies(for: $0) } ?? []
                let adding = DispatchGroup()
                for cookie in restore {
                    adding.enter()
                    store.setCookie(cookie) { adding.leave() }
                }
                adding.notify(queue: .main, execute: completion)
            }
        }
    }

    private var folder: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("accounts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func cookieFile(for username: String) -> URL {
        folder.appendingPathComponent("\(username).json")
    }

    private func saveCookies(_ cookies: [HTTPCookie], for username: String) {
        guard let data = try? JSONEncoder().encode(cookies.map { StoredCookie($0) }) else { return }
        try? data.write(to: cookieFile(for: username), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    private func loadCookies(for username: String) -> [HTTPCookie] {
        guard let data = try? Data(contentsOf: cookieFile(for: username)),
              let stored = try? JSONDecoder().decode([StoredCookie].self, from: data) else { return [] }
        return stored.compactMap { $0.cookie }
    }
}

/// Diske yazılabilen çerez kopyası.
private struct StoredCookie: Codable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let expires: Date?
    let secure: Bool
    let httpOnly: Bool
    let sameSite: String?

    init(_ cookie: HTTPCookie) {
        name = cookie.name
        value = cookie.value
        domain = cookie.domain
        path = cookie.path
        expires = cookie.expiresDate
        secure = cookie.isSecure
        httpOnly = cookie.isHTTPOnly
        sameSite = cookie.sameSitePolicy?.rawValue
    }

    var cookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name, .value: value, .domain: domain, .path: path,
        ]
        if let date = expires { properties[.expires] = date }
        if secure { properties[.secure] = "TRUE" }
        if httpOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
        if let policy = sameSite { properties[.sameSitePolicy] = policy }
        return HTTPCookie(properties: properties)
    }
}
