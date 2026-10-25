import FiscalDomain
import Foundation

extension AppUpdateModel {
    public var requiredTitle: String { String(appLocalized: "Update Fiscal") }

    public var requiredMessage: String {
        guard let release = cache.release, let installed else {
            return String(
                appLocalized:
                    "This version is no longer supported. Update to keep using Fiscal. Your data stays on your device and you can export it now."
            )
        }
        let byBuild = installed.version >= release.minimumVersion
        let current = Self.label(installed.version, installed.build, byBuild: byBuild)
        let minimum = Self.label(release.minimumVersion, release.minimumBuild, byBuild: byBuild)
        return String(
            appLocalized:
                "Version \(current) is no longer supported. Update to \(minimum) or later. You can still export your data."
        )
    }

    public var recommendedTitle: String { String(appLocalized: "A new Fiscal is available") }

    public var recommendedMessage: String {
        guard let release = cache.release, let installed else {
            return String(
                appLocalized:
                    "Update for the latest fixes and improvements. It only takes a moment.")
        }
        let byBuild = installed.version >= release.recommendedVersion
        let version = Self.label(
            release.recommendedVersion, release.recommendedBuild, byBuild: byBuild)
        return String(
            appLocalized:
                "Version \(version) is available with the latest fixes and improvements. It only takes a moment."
        )
    }

    private static func label(_ version: AppVersion, _ build: Int, byBuild: Bool) -> String {
        byBuild ? "\(version) (\(build))" : version.description
    }
}
