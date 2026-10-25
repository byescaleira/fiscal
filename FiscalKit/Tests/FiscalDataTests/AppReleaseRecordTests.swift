import CloudKit
import FiscalDomain
import Foundation
import Testing

@testable import FiscalData

struct AppReleaseRecordTests {
    private func record(
        type: String = CloudKitAppReleaseSource.recordType, minimum: String,
        recommended: String, builds: (Int, Int)? = nil
    ) -> CKRecord {
        let record = CKRecord(recordType: type, recordID: CKRecord.ID(recordName: "ios"))
        record["platform"] = "ios" as NSString
        record["minimumVersion"] = minimum as NSString
        record["recommendedVersion"] = recommended as NSString
        if let builds {
            record["minimumBuild"] = NSNumber(value: Int64(builds.0))
            record["recommendedBuild"] = NSNumber(value: Int64(builds.1))
        }
        return record
    }

    @Test func readsTheFields() throws {
        let release = try #require(
            CloudKitAppReleaseSource.release(
                from: record(minimum: "1.0.0", recommended: "1.10.0", builds: (60, 80))))
        #expect(release.minimumVersion == AppVersion("1.0"))
        #expect(release.minimumBuild == 60)
        #expect(release.recommendedVersion == AppVersion("1.10.0"))
        #expect(release.recommendedBuild == 80)
    }

    @Test func recommendedNeverFallsBelowTheMinimum() throws {
        let release = try #require(
            CloudKitAppReleaseSource.release(
                from: record(minimum: "1.2.0", recommended: "1.1.0", builds: (90, 10))))
        #expect(release.recommendedVersion == AppVersion("1.2.0"))
        #expect(release.recommendedBuild == 90)
    }

    @Test func missingBuildsCountAsZero() throws {
        let release = try #require(
            CloudKitAppReleaseSource.release(from: record(minimum: "1.0.0", recommended: "1.0.0"))
        )
        #expect(release.minimumBuild == 0)
        #expect(release.recommendedBuild == 0)
    }

    @Test func rejectsBrokenRecords() {
        #expect(
            CloudKitAppReleaseSource.release(from: record(minimum: "one", recommended: "1.0.0"))
                == nil)
        #expect(
            CloudKitAppReleaseSource.release(
                from: record(type: "FeatureFlag", minimum: "1.0.0", recommended: "1.0.0")) == nil)
    }
}
