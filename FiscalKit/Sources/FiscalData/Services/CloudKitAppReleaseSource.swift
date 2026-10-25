import CloudKit
import FiscalDomain

public struct CloudKitAppReleaseSource: AppReleaseSource {
    public static let recordType = "AppRelease"
    private let containerIdentifier: String

    public init(containerIdentifier: String = FiscalDatabase.cloudContainer) {
        self.containerIdentifier = containerIdentifier
    }

    public func fetch(platform: AppPlatform) async throws -> AppRelease? {
        let database = CKContainer(identifier: containerIdentifier).publicCloudDatabase
        do {
            let record = try await database.record(for: CKRecord.ID(recordName: platform.rawValue))
            guard let release = Self.release(from: record) else { throw FiscalError.onFetch }
            return release
        } catch let error as CKError where error.code == .unknownItem {
            return nil
        }
    }

    static func release(from record: CKRecord) -> AppRelease? {
        guard record.recordType == recordType,
            let minimumVersion = (record["minimumVersion"] as? String).flatMap(AppVersion.init),
            let recommendedVersion = (record["recommendedVersion"] as? String).flatMap(
                AppVersion.init)
        else { return nil }
        let minimumBuild = record["minimumBuild"] as? Int ?? 0
        return AppRelease(
            minimumVersion: minimumVersion, minimumBuild: minimumBuild,
            recommendedVersion: max(recommendedVersion, minimumVersion),
            recommendedBuild: max(record["recommendedBuild"] as? Int ?? 0, minimumBuild))
    }
}
