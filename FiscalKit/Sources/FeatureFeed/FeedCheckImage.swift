import FeatureCore
import FiscalDesignSystem
import SwiftUI

extension CGFloat {
    fileprivate static let checkImageRatio: CGFloat = 1200.0 / 630.0
}

struct FeedCheckImage: View {
    @State private var state = LoadState.loading
    let page: URL

    private enum LoadState: Equatable {
        case loading
        case found(URL)
        case missing
    }

    var body: some View {
        content
            .task(id: page) {
                guard state == .loading else { return }
                let found = await CheckImageResolver.shared.imageURL(for: page)
                guard !Task.isCancelled else { return }
                state = found.map(LoadState.found) ?? .missing
            }
    }

    @ViewBuilder private var content: some View {
        switch state {
        case .loading:
            placeholder
        case .found(let image):
            VStack(alignment: .leading, spacing: .spaceXS) {
                AsyncImage(url: image) { phase in
                    if let picture = phase.image {
                        picture.resizable().aspectRatio(contentMode: .fit)
                    } else {
                        placeholder
                    }
                }
                .clipShape(.rect(cornerRadius: .radiusM))
                .accessibilityHidden(true)
                Text("Image: Projeto Comprova · CC BY-ND 4.0")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .missing:
            Color.clear.frame(height: 0)
        }
    }

    private var placeholder: some View {
        Color.plainRow
            .aspectRatio(.checkImageRatio, contentMode: .fit)
            .clipShape(.rect(cornerRadius: .radiusM))
    }
}
