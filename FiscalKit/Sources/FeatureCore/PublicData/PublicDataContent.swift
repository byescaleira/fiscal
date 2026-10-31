import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct PublicDataContent<Content: View, Empty: View>: View {
    private let phase: PublicDataPhase
    private let isEmpty: Bool
    private let retry: @MainActor () async -> Void
    private let content: Content
    private let empty: Empty

    public init(
        phase: PublicDataPhase, isEmpty: Bool, retry: @escaping @MainActor () async -> Void,
        @ViewBuilder content: () -> Content, @ViewBuilder empty: () -> Empty
    ) {
        self.phase = phase
        self.isEmpty = isEmpty
        self.retry = retry
        self.content = content()
        self.empty = empty()
    }

    public var body: some View {
        if !isEmpty {
            content
        } else {
            switch phase {
            case .idle, .loading:
                ProgressView("Loading")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .failed(let error):
                PublicDataFailure(error: error, retry: retry)
            case .loaded:
                empty
            }
        }
    }
}

private struct PublicDataFailure: View {
    let error: PublicDataError
    let retry: @MainActor () async -> Void

    var body: some View {
        EmptyStateView(
            title: error.titleKey, description: error.messageKey, actionTitle: "Try Again",
            action: { Task { await retry() } }
        ) {
            IconRow("Official sources", symbol: "building.columns", color: .retroDenim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.plainBackground)
    }
}

extension PublicDataError {
    var titleKey: LocalizedStringKey {
        switch self {
        case .offline: "Available with a connection"
        default: "Couldn't load the data"
        }
    }

    var messageKey: LocalizedStringKey {
        switch self {
        case .notFound: "This data isn't published yet."
        case .rejected, .unavailable:
            "Couldn't reach the public data server. Try again in a moment."
        case .offline: "This isn't saved for offline use. Connect to the internet to see it."
        case .invalidData: "The public data came in a format Fiscal can't read."
        }
    }

    public var symbol: String {
        switch self {
        case .offline: "wifi.slash"
        case .notFound: "doc.questionmark"
        case .rejected, .unavailable, .invalidData: "exclamationmark.icloud"
        }
    }
}
