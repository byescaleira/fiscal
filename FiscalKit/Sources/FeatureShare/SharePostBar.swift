import FiscalDesignSystem
import SwiftUI

struct SharePostBar: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        VStack(spacing: .spaceS) {
            SharePostMessages()
            if model.isExportingVideo {
                ShareVideoProgress()
            } else {
                Button {
                    model.startPost()
                } label: {
                    Label(model.destination.postTitle, systemImage: "square.and.arrow.up")
                        .lineLimit(1)
                        .minimumScaleFactor(.shareTextShrink)
                        .frame(maxWidth: .infinity)
                }
                .primaryButton()
                .disabled(model.rendered == nil || model.isPosting)
            }
        }
        .padding(.horizontal, .spaceL)
        .padding(.vertical, .spaceS)
        .readableWidth()
        .frame(maxWidth: .infinity)
    }
}

private struct ShareVideoProgress: View {
    @Environment(ShareModel.self) private var model
    @Environment(\.appTint) private var tint

    var body: some View {
        HStack(spacing: .spaceM) {
            VStack(alignment: .leading, spacing: .spaceXS) {
                Text("Preparing the video")
                    .font(.footnote)
                ProgressBar(value: model.exportProgress, color: tint)
            }
            Button("Cancel", role: .cancel) {
                model.cancelPost()
            }
            .fixedSize()
        }
    }
}

private struct SharePostMessages: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Group {
            if model.postFailed {
                Text("Couldn't prepare the file. Try again.")
            }
            if model.videoFellBack {
                Text("Couldn't make the video; the image goes instead.")
            }
            switch model.notice {
            case .savedToPhotos(let isVideo):
                if isVideo {
                    Text("Saved to Photos. Open TikTok and pick the video.")
                } else {
                    Text("Saved to Photos. Open TikTok and pick the image.")
                }
            case .failed(let reason):
                Text(verbatim: reason)
            case nil:
                EmptyView()
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
}
