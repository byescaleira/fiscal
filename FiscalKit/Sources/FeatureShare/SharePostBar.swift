import FiscalDesignSystem
import SwiftUI

struct SharePostButton: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        Button {
            model.startPost()
        } label: {
            Label(model.destination.network.title, systemImage: "square.and.arrow.up")
                .labelStyle(.titleAndIcon)
                .lineLimit(1)
                .fixedSize()
        }
        .prominentButton()
        .disabled(model.rendered == nil || model.isPosting)
        .accessibilityLabel(Text(model.destination.postTitle))
    }
}

struct ShareStatusBar: View {
    @Environment(ShareModel.self) private var model

    var body: some View {
        if model.isExportingVideo || model.hasPostMessage {
            VStack(spacing: .spaceS) {
                SharePostMessages()
                if model.isExportingVideo {
                    ShareVideoProgress()
                }
            }
            .padding(.horizontal, .spaceL)
            .padding(.vertical, .spaceS)
            .readableWidth()
            .frame(maxWidth: .infinity)
        }
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
        if let message = model.statusMessage {
            Text(verbatim: message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
