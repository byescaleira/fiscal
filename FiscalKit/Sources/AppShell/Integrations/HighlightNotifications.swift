import FiscalDomain
import Foundation

#if canImport(ActivityKit) && os(iOS)
    import UserNotifications
#endif

public enum FiscalNotifications {
    @MainActor
    public static func install() {
        #if canImport(ActivityKit) && os(iOS)
            UNUserNotificationCenter.current().delegate = HighlightNotificationDelegate.shared
        #endif
    }
}

enum HighlightNotificationStatus: Sendable {
    case authorized, denied, undetermined
}

@MainActor
protocol HighlightNotificationScheduling: AnyObject {
    func status() async -> HighlightNotificationStatus
    func requestPermission() async -> Bool
    func pending() async -> PlannedAlert?
    func schedule(_ highlight: Highlight, at date: Date) async throws
    func cancel() async
}

extension HighlightBoard {
    var notificationBody: String {
        [subtitle, uncertaintyShort ?? ""].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

#if canImport(ActivityKit) && os(iOS)
    @MainActor
    final class HighlightNotifications: HighlightNotificationScheduling {
        static let identifier = "fiscal.highlight.daily"
        private static let highlightKey = "highlightId"
        private static let fireKey = "fireAt"
        nonisolated static let urlKey = "url"

        private var center: UNUserNotificationCenter { .current() }

        func status() async -> HighlightNotificationStatus {
            switch await center.notificationSettings().authorizationStatus {
            case .authorized, .provisional, .ephemeral: .authorized
            case .notDetermined: .undetermined
            default: .denied
            }
        }

        func requestPermission() async -> Bool {
            (try? await center.requestAuthorization(options: [.alert])) ?? false
        }

        func pending() async -> PlannedAlert? {
            let requests = await center.pendingNotificationRequests()
            guard
                let info = requests.first(where: { $0.identifier == Self.identifier })?.content
                    .userInfo,
                let id = info[Self.highlightKey] as? String,
                let fire = info[Self.fireKey] as? Double
            else { return nil }
            return PlannedAlert(highlightId: id, fireDate: Date(timeIntervalSince1970: fire))
        }

        func schedule(_ highlight: Highlight, at date: Date) async throws {
            let board = HighlightBoard(highlight)
            let content = UNMutableNotificationContent()
            content.title = highlight.plainSummary ?? highlight.title
            content.body = board.notificationBody
            content.userInfo = [
                Self.highlightKey: board.id,
                Self.fireKey: date.timeIntervalSince1970,
                Self.urlKey: board.url?.absoluteString ?? "",
            ]
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: date)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            try await center.add(
                UNNotificationRequest(
                    identifier: Self.identifier, content: content, trigger: trigger))
        }

        func cancel() async {
            center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        }
    }

    @MainActor
    final class HighlightNotificationDelegate: NSObject,
        @preconcurrency UNUserNotificationCenterDelegate
    {
        static let shared = HighlightNotificationDelegate()

        func userNotificationCenter(
            _ center: UNUserNotificationCenter, willPresent notification: UNNotification
        ) async -> UNNotificationPresentationOptions {
            [.banner, .list]
        }

        func userNotificationCenter(
            _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
        ) async {
            guard
                let value = response.notification.request.content.userInfo[
                    HighlightNotifications.urlKey] as? String,
                let url = URL(string: value)
            else { return }
            FiscalServices.shared.pendingURL = url
        }
    }
#else
    @MainActor
    final class HighlightNotifications: HighlightNotificationScheduling {
        func status() async -> HighlightNotificationStatus { .denied }
        func requestPermission() async -> Bool { false }
        func pending() async -> PlannedAlert? { nil }
        func schedule(_ highlight: Highlight, at date: Date) async throws {}
        func cancel() async {}
    }
#endif
