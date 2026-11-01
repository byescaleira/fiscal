import Foundation

extension ShareModel {
    public var usesVideo: Bool {
        switch destination.media {
        case .video: true
        case .either: sendsVideo
        case .image: false
        }
    }

    public var offersMediaChoice: Bool { destination.media == .either }

    public func startPost() {
        guard !isPosting else { return }
        postTask = Task { await post() }
    }

    public func cancelPost() {
        postTask?.cancel()
    }

    public func post() async {
        guard !isPosting else { return }
        isPosting = true
        postFailed = false
        videoFellBack = false
        notice = nil
        exportProgress = 0
        discardExport()
        defer {
            isPosting = false
            isExportingVideo = false
        }
        render(scale: renderScale, portraits: renderPortraits)
        guard let card else {
            postFailed = true
            return
        }
        var isVideo = usesVideo
        var file: URL?
        if isVideo {
            isExportingVideo = true
            do {
                file = try await makeVideo(card, code, renderPortraits) { [weak self] value in
                    self?.exportProgress = value
                }
            } catch is CancellationError {
                exportProgress = 0
                return
            } catch {
                videoFellBack = true
                isVideo = false
            }
            isExportingVideo = false
        }
        guard let url = file ?? rendered.flatMap({ try? ShareRenderer.write($0.file) }) else {
            postFailed = true
            return
        }
        exportProgress = 1
        exportedFile = url
        let caption = destination.acceptsCaption ? caption : nil
        let result = await delivery.send(
            url, isVideo: isVideo, caption: caption, route: destination.delivery,
            metaAppID: metaAppID, topColor: card.storyColors.top,
            bottomColor: card.storyColors.bottom)
        finish(result, file: url, caption: caption, isVideo: isVideo)
    }

    public func discardExport() {
        guard let exportedFile else { return }
        try? FileManager.default.removeItem(at: exportedFile.deletingLastPathComponent())
        self.exportedFile = nil
    }

    private func finish(
        _ result: ShareDeliveryResult, file: URL, caption: String?, isVideo: Bool
    ) {
        switch result {
        case .needsShareSheet:
            postRequest = SharePostRequest(file: file, caption: caption)
        case .openedStories:
            discardExport()
        case .savedToPhotos:
            notice = .savedToPhotos(isVideo: isVideo)
            discardExport()
        case .failed(let reason):
            notice = .failed(reason)
            discardExport()
        }
    }
}
