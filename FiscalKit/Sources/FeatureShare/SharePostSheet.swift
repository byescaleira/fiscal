import Foundation
import SwiftUI

public struct SharePostRequest: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public let file: URL
    public let caption: String?

    public init(file: URL, caption: String?) {
        self.file = file
        self.caption = caption
    }

    var items: [Any] {
        [file as Any] + (caption.map { [$0 as Any] } ?? [])
    }
}

public enum ShareNotice: Equatable, Sendable {
    case savedToPhotos(isVideo: Bool)
    case failed(String)
}

extension View {
    func sharePostSheet(_ request: Binding<SharePostRequest?>) -> some View {
        modifier(SharePostSheet(request: request))
    }
}

#if os(macOS)
    import AppKit

    private struct SharePostSheet: ViewModifier {
        @Binding var request: SharePostRequest?

        func body(content: Content) -> some View {
            content.background(SharePickerAnchor(request: $request))
        }
    }

    private struct SharePickerAnchor: NSViewRepresentable {
        @Binding var request: SharePostRequest?

        func makeNSView(context: Context) -> NSView { NSView() }

        func updateNSView(_ view: NSView, context: Context) {
            guard let pending = request else { return }
            let picker = NSSharingServicePicker(items: pending.items)
            picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
            Task { @MainActor in request = nil }
        }
    }
#else
    import UIKit

    private struct SharePostSheet: ViewModifier {
        @Binding var request: SharePostRequest?

        func body(content: Content) -> some View {
            content.sheet(item: $request) { pending in
                ShareActivityView(request: pending)
                    .presentationDetents([.medium, .large])
                    .ignoresSafeArea()
            }
        }
    }

    private struct ShareActivityView: UIViewControllerRepresentable {
        let request: SharePostRequest

        func makeUIViewController(context: Context) -> UIActivityViewController {
            UIActivityViewController(activityItems: request.items, applicationActivities: nil)
        }

        func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
    }
#endif
