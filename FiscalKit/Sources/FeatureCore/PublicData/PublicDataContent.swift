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
        ContentUnavailableView {
            Label("Couldn't load the data", systemImage: error.symbol)
        } description: {
            Text(verbatim: error.message)
        } actions: {
            Button("Try Again") { Task { await retry() } }
                .primaryButton()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.groupedBackground)
    }
}

extension PublicDataError {
    public var symbol: String {
        switch self {
        case .offline: "wifi.slash"
        case .notFound: "doc.questionmark"
        case .rejected, .unavailable, .invalidData: "exclamationmark.icloud"
        }
    }
}
