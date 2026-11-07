import Foundation
import SwiftUI

public enum ShareMedia: String, Hashable, Sendable {
    case image, video, either

    public var allowsImage: Bool { self != .video }
    public var allowsVideo: Bool { self != .image }
}

public enum ShareDeliveryRoute: Hashable, Sendable {
    case instagramStories
    case facebookStories
    case photosThenOpen(URL?)
    case shareSheet
}

public enum ShareNetwork: String, CaseIterable, Hashable, Sendable, Identifiable {
    case instagram, tiktok, facebook, whatsapp, other

    public var id: String { rawValue }

    public var title: LocalizedStringKey {
        switch self {
        case .instagram: "Instagram"
        case .tiktok: "TikTok"
        case .facebook: "Facebook"
        case .whatsapp: "WhatsApp"
        case .other: "Others"
        }
    }

    public var symbol: String {
        switch self {
        case .instagram: "camera"
        case .tiktok: "play.rectangle"
        case .facebook: "person.2"
        case .whatsapp: "bubble.left"
        case .other: "square.and.arrow.up"
        }
    }

    public var destinations: [ShareDestination] {
        ShareDestination.allCases.filter { $0.network == self }
    }
}

public enum ShareDestination: String, CaseIterable, Hashable, Sendable, Identifiable {
    case instagramStories
    case instagramReels
    case instagramFeed
    case tiktok
    case facebookStories
    case facebookFeed
    case whatsapp
    case whatsappStatus
    case other

    public static let tiktokApp = URL(string: "tiktok://")

    public var id: String { rawValue }

    public var network: ShareNetwork {
        switch self {
        case .instagramStories, .instagramReels, .instagramFeed: .instagram
        case .tiktok: .tiktok
        case .facebookStories, .facebookFeed: .facebook
        case .whatsapp, .whatsappStatus: .whatsapp
        case .other: .other
        }
    }

    public var format: ShareFormat {
        switch self {
        case .instagramStories, .instagramReels, .tiktok, .facebookStories, .whatsappStatus:
            .stories
        case .instagramFeed, .facebookFeed, .other: .feed
        case .whatsapp: .message
        }
    }

    public var media: ShareMedia {
        switch self {
        case .instagramReels: .video
        case .instagramStories, .tiktok, .facebookStories, .whatsappStatus: .either
        case .instagramFeed, .facebookFeed, .whatsapp, .other: .image
        }
    }

    public var acceptsCaption: Bool {
        switch self {
        case .instagramFeed, .facebookFeed, .whatsapp, .other: true
        case .instagramStories, .instagramReels, .tiktok, .facebookStories, .whatsappStatus:
            false
        }
    }

    public var delivery: ShareDeliveryRoute {
        switch self {
        case .instagramStories: .instagramStories
        case .facebookStories: .facebookStories
        case .tiktok: .photosThenOpen(Self.tiktokApp)
        case .instagramReels, .instagramFeed, .facebookFeed, .whatsapp, .whatsappStatus, .other:
            .shareSheet
        }
    }

    public var title: LocalizedStringKey {
        switch self {
        case .instagramStories, .facebookStories: "Stories"
        case .instagramReels: "Reels"
        case .instagramFeed, .facebookFeed: "Feed"
        case .tiktok: "Video"
        case .whatsapp: "Chat"
        case .whatsappStatus: "WhatsApp Status"
        case .other: "Other apps"
        }
    }

    public var postTitle: LocalizedStringKey {
        switch self {
        case .instagramStories: "Post to Instagram Stories"
        case .instagramReels: "Post to Instagram Reels"
        case .instagramFeed: "Post to Instagram Feed"
        case .tiktok: "Post to TikTok"
        case .facebookStories: "Post to Facebook Stories"
        case .facebookFeed: "Post to Facebook Feed"
        case .whatsapp: "Send on WhatsApp"
        case .whatsappStatus: "Post to WhatsApp Status"
        case .other: "Share"
        }
    }
}
