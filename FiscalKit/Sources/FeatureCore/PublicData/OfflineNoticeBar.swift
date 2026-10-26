import FiscalDesignSystem
import FiscalDomain
import SwiftUI

extension View {
    public func offlineNotice(_ notice: OfflineNotice = .shared) -> some View {
        modifier(OfflineNoticeModifier(notice: notice))
    }
}

private struct OfflineNoticeModifier: ViewModifier {
    let notice: OfflineNotice

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .top, spacing: .zero) {
                if case .offline(let date) = notice.state {
                    OfflineNoticeBar(date: date)
                        .padding(.vertical, .space2XS)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.smooth, value: notice.state)
    }
}

public struct OfflineNoticeBar: View {
    private let date: Date?

    public init(date: Date?) {
        self.date = date
    }

    public var body: some View {
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: "wifi.slash")
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .multilineTextAlignment(.center)
        .padding(.horizontal, .spaceM)
        .padding(.vertical, .spaceXS)
        .surface(in: .capsule)
        .accessibilityElement(children: .combine)
    }

    private var text: String {
        guard let date else { return String(appLocalized: "No connection · saved data") }
        return String(appLocalized: "No connection · data from \(PublicFormat.updated(date))")
    }
}
