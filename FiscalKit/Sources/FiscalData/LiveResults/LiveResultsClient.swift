import FiscalDomain
import Foundation

public struct LiveResultsClient: LiveResultsService {
    private let dataURL: URL
    private let session: URLSession
    private let offline: OfflinePackStore?

    public init(
        dataURL: URL, session: URLSession = .shared, offline: OfflinePackStore? = nil
    ) {
        self.dataURL = dataURL
        self.session = session
        self.offline = offline
    }

    public static func fromBundle(_ bundle: Bundle = .main) -> LiveResultsClient? {
        PublicDataClient.dataURL(bundle).map { LiveResultsClient(dataURL: $0, offline: .shared) }
    }

    public func races() async throws -> [Race] {
        do {
            let list = try await raceList(
                at: dataURL.appending(path: PublicDataLayout.version).appending(path: "races.json"))
            if offline != nil { OfflineNotice.shared.markOnline() }
            return list.races
        } catch {
            guard let offline, let data = await offline.data(for: "races.json"),
                let list = try? JSONDecoder().decode(RaceList.self, from: data)
            else { throw error }
            OfflineNotice.shared.markOffline(dataFrom: await offline.updatedAt)
            return list.races
        }
    }

    private func raceList(at url: URL) async throws -> RaceList {
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        let (data, response) = try await session.data(for: request)
        try Self.check(response)
        return try JSONDecoder().decode(RaceList.self, from: data)
    }

    private static func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw LiveResultsError.unavailable }
        switch http.statusCode {
        case 200..<300: return
        case 400..<500 where http.statusCode != 429:
            throw LiveResultsError.rejected(http.statusCode)
        default: throw LiveResultsError.unavailable
        }
    }
}
