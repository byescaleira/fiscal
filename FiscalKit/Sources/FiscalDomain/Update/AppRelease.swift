import Foundation

public enum UpdateState: String, CaseIterable, Codable, Sendable {
    case current, recommended, required
}

public enum AppPlatform: String, CaseIterable, Codable, Sendable {
    case ios, macos, tvos, visionos

    public static var current: AppPlatform {
        #if os(macOS)
            .macos
        #elseif os(tvOS)
            .tvos
        #elseif os(visionOS)
            .visionos
        #else
            .ios
        #endif
    }
}

public struct InstalledApp: Hashable, Sendable, CustomStringConvertible {
    public let version: AppVersion
    public let build: Int

    public init(version: AppVersion, build: Int) {
        self.version = version
        self.build = build
    }

    public init?(info: [String: Any]) {
        guard
            let version = (info["CFBundleShortVersionString"] as? String).flatMap(
                AppVersion.init),
            let build = (info["CFBundleVersion"] as? String).flatMap({ Int($0) })
        else { return nil }
        self.init(version: version, build: build)
    }

    public static var main: InstalledApp? { InstalledApp(info: Bundle.main.infoDictionary ?? [:]) }

    public var description: String { "\(version) (\(build))" }
}

public struct AppRelease: Hashable, Sendable, Codable {
    public let minimumVersion: AppVersion
    public let minimumBuild: Int
    public let recommendedVersion: AppVersion
    public let recommendedBuild: Int

    public init(
        minimumVersion: AppVersion, minimumBuild: Int, recommendedVersion: AppVersion,
        recommendedBuild: Int
    ) {
        self.minimumVersion = minimumVersion
        self.minimumBuild = minimumBuild
        self.recommendedVersion = recommendedVersion
        self.recommendedBuild = recommendedBuild
    }

    public func state(for installed: InstalledApp) -> UpdateState {
        if installed.version < minimumVersion || installed.build < minimumBuild { return .required }
        if installed.version < recommendedVersion || installed.build < recommendedBuild {
            return .recommended
        }
        return .current
    }

    public var recommendationID: String { "\(recommendedVersion) (\(recommendedBuild))" }
}

public protocol AppReleaseSource: Sendable {
    func fetch(platform: AppPlatform) async throws -> AppRelease?
}
