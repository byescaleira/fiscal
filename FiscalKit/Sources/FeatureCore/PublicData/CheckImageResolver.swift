import Foundation

public actor CheckImageResolver {
    public static let shared = CheckImageResolver()
    private static let host = "projetocomprova.com.br"
    private let session: URLSession
    private var known: [URL: URL] = [:]
    private var missing: Set<URL> = []

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.allowsConstrainedNetworkAccess = false
            configuration.allowsExpensiveNetworkAccess = true
            self.session = URLSession(configuration: configuration)
        }
    }

    public nonisolated static func accepts(_ page: URL) -> Bool {
        page.scheme?.lowercased() == "https" && page.host()?.lowercased() == host
    }

    public func imageURL(for page: URL) async -> URL? {
        guard Self.accepts(page) else { return nil }
        if let found = known[page] { return found }
        if missing.contains(page) { return nil }
        guard let (data, response) = try? await session.data(from: page),
            (response as? HTTPURLResponse)?.statusCode == 200
        else { return nil }
        guard let found = Self.imageURL(in: String(decoding: data, as: UTF8.self)) else {
            missing.insert(page)
            return nil
        }
        known[page] = found
        return found
    }

    public nonisolated static func imageURL(in html: String) -> URL? {
        for tag in html.matches(of: /<meta\b[^>]*>/.ignoresCase()) {
            let text = String(tag.0)
            guard text.lowercased().contains("og:image"),
                !text.lowercased().contains("og:image:"),
                let content = text.firstMatch(of: /content\s*=\s*["']([^"']+)["']/.ignoresCase()),
                let url = URL(string: String(content.1)), accepts(url)
            else { continue }
            return url
        }
        return nil
    }
}
