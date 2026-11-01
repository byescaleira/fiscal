import FiscalDomain
import Foundation

#if canImport(UIKit) && !os(visionOS)
    import Photos
    import UIKit
#endif

public enum ShareDeliveryResult: Equatable, Sendable {
    case openedStories
    case savedToPhotos(openedApp: Bool)
    case needsShareSheet
    case failed(String)
}

public enum ShareDeliveryError: LocalizedError, Equatable {
    case photosAccessDenied
    case photosFailed

    public var errorDescription: String? {
        switch self {
        case .photosAccessDenied:
            String(
                appLocalized: "Fiscal can't add to Photos. Allow it in Settings > Fiscal > Photos.")
        case .photosFailed: String(appLocalized: "Couldn't save to Photos.")
        }
    }
}

@MainActor
public struct ShareDelivery {
    public typealias PasteboardWriter = @MainActor ([[String: Any]], Date) -> Void
    public typealias URLOpener = @MainActor (URL) async -> Bool
    public typealias URLChecker = @MainActor (URL) -> Bool
    public typealias PhotosSaver = @MainActor (URL, Bool) async throws -> Void

    public static let pasteboardLifetime: TimeInterval = 300
    struct StoriesApp {
        static let instagram = StoriesApp(
            scheme: "instagram-stories://share", prefix: "com.instagram", sendsAppID: false)
        static let facebook = StoriesApp(
            scheme: "facebook-stories://share", prefix: "com.facebook", sendsAppID: true)

        let scheme: String
        let prefix: String
        let sendsAppID: Bool
    }

    private let writePasteboard: PasteboardWriter
    private let open: URLOpener
    private let canOpen: URLChecker
    private let saveToPhotos: PhotosSaver
    private let now: @MainActor () -> Date

    public init(
        writePasteboard: @escaping PasteboardWriter, open: @escaping URLOpener,
        canOpen: @escaping URLChecker, saveToPhotos: @escaping PhotosSaver,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.writePasteboard = writePasteboard
        self.open = open
        self.canOpen = canOpen
        self.saveToPhotos = saveToPhotos
        self.now = now
    }

    public func send(
        _ file: URL, isVideo: Bool, caption: String?, route: ShareDeliveryRoute, metaAppID: String?,
        topColor: String, bottomColor: String
    ) async -> ShareDeliveryResult {
        #if canImport(UIKit) && !os(visionOS)
            switch route {
            case .instagramStories:
                return await stories(
                    file, isVideo: isVideo, app: .instagram, metaAppID: metaAppID,
                    colors: (topColor, bottomColor))
            case .facebookStories:
                return await stories(
                    file, isVideo: isVideo, app: .facebook, metaAppID: metaAppID,
                    colors: (topColor, bottomColor))
            case .photosThenOpen(let app):
                return await photos(file, isVideo: isVideo, then: app)
            case .shareSheet:
                return .needsShareSheet
            }
        #else
            return .needsShareSheet
        #endif
    }

    private func stories(
        _ file: URL, isVideo: Bool, app: StoriesApp, metaAppID: String?,
        colors: (top: String, bottom: String)
    ) async -> ShareDeliveryResult {
        guard let appID = metaAppID?.trimmingCharacters(in: .whitespaces), !appID.isEmpty,
            let base = URL(string: app.scheme), canOpen(base),
            var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else { return .needsShareSheet }
        components.queryItems = [URLQueryItem(name: "source_application", value: appID)]
        guard let url = components.url,
            let data = try? Data(contentsOf: file, options: .mappedIfSafe)
        else { return .needsShareSheet }
        let sticker = app.prefix + ".sharedSticker."
        var item: [String: Any] = [
            sticker + (isVideo ? "backgroundVideo" : "backgroundImage"): data,
            sticker + "backgroundTopColor": colors.top,
            sticker + "backgroundBottomColor": colors.bottom,
        ]
        if app.sendsAppID { item[sticker + "appID"] = appID }
        writePasteboard([item], now().addingTimeInterval(Self.pasteboardLifetime))
        return await open(url) ? .openedStories : .needsShareSheet
    }

    private func photos(_ file: URL, isVideo: Bool, then app: URL?) async -> ShareDeliveryResult {
        do {
            try await saveToPhotos(file, isVideo)
        } catch {
            return .failed(error.localizedDescription)
        }
        guard let app, canOpen(app) else { return .savedToPhotos(openedApp: false) }
        return .savedToPhotos(openedApp: await open(app))
    }
}

#if canImport(UIKit) && !os(visionOS)
    extension ShareDelivery {
        public static var live: ShareDelivery {
            ShareDelivery(
                writePasteboard: { items, expiration in
                    UIPasteboard.general.setItems(
                        items, options: [.expirationDate: expiration, .localOnly: true])
                },
                open: { url in await UIApplication.shared.open(url) },
                canOpen: { url in UIApplication.shared.canOpenURL(url) },
                saveToPhotos: { file, isVideo in try await PhotosLibrary.add(file, isVideo: isVideo)
                })
        }
    }

    enum PhotosLibrary {
        static func add(_ file: URL, isVideo: Bool) async throws {
            let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard status == .authorized || status == .limited else {
                throw ShareDeliveryError.photosAccessDenied
            }
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetCreationRequest.forAsset()
                        .addResource(with: isVideo ? .video : .photo, fileURL: file, options: nil)
                }
            } catch {
                throw ShareDeliveryError.photosFailed
            }
        }
    }
#else
    extension ShareDelivery {
        public static var live: ShareDelivery {
            ShareDelivery(
                writePasteboard: { _, _ in }, open: { _ in false }, canOpen: { _ in false },
                saveToPhotos: { _, _ in throw ShareDeliveryError.photosFailed })
        }
    }
#endif
