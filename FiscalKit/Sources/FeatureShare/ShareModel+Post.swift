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

    public var hasPostMessage: Bool { statusMessage != nil }

    public var statusMessage: String? {
        if postFailed { return String(appLocalized: "Couldn't prepare the file. Try again.") }
        switch notice {
        case .savedToPhotos(true):
            return String(appLocalized: "Saved to Photos. Open TikTok and pick the video.")
        case .savedToPhotos(false):
            return String(appLocalized: "Saved to Photos. Open TikTok and pick the image.")
        case .failed(let reason):
            return reason
        case nil:
            return videoFellBack
                ? String(appLocalized: "Couldn't make the video; the image goes instead.") : nil
        }
    }

    public func startPost() {
        guard !isPosting else { return }
        postTask = Task { await post() }
    }

    public func cancelPost() {
        postTask?.cancel()
    }

    func waitForPost() async {
        await postTask?.value
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
        render(scale: renderScale)
        guard let card else {
            postFailed = true
            return
        }
        var isVideo = usesVideo
        var file: URL?
        if isVideo {
            isExportingVideo = true
            do {
                file = try await makeVideo(card, code) { [weak self] value in
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
        exportedFile = url
        guard !Task.isCancelled else {
            exportProgress = 0
            discardExport()
            return
        }
        exportProgress = 1
        let caption = destination.acceptsCaption ? caption : nil
        let result = await delivery.send(
            url, isVideo: isVideo, caption: caption, route: destination.delivery,
            metaAppID: metaAppID, topColor: card.storyColors.top,
            bottomColor: card.storyColors.bottom)
        finish(result, file: url, caption: caption, isVideo: isVideo)
    }

    public func leave() {
        cancelPost()
        discardExport()
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
