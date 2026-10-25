import CloudKit
import FiscalDomain

public struct CloudKitFlagSource: RemoteFlagSource {
    private let containerIdentifier: String

    public init(containerIdentifier: String = FiscalDatabase.cloudContainer) {
        self.containerIdentifier = containerIdentifier
    }

    public func fetch() async throws -> [String: RemoteFlag] {
        let database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        let query = CKQuery(recordType: "FeatureFlag", predicate: NSPredicate(value: true))
        let (results, _) = try await database.records(matching: query, resultsLimit: 200)
        var flags: [String: RemoteFlag] = [:]
        for case (_, .success(let record)) in results {
            guard let name = record["name"] as? String else { continue }
            flags[name] = RemoteFlag(
                isOn: (record["isOn"] as? Int ?? 0) == 1, rollout: record["rollout"] as? Int ?? 100)
        }
        return flags
    }
}
