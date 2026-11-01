import Foundation

public enum ShareDeliveryRoute: Hashable, Sendable {
    case instagramStories
    case facebookStories
    case photosThenOpen(URL?)
    case shareSheet
}
