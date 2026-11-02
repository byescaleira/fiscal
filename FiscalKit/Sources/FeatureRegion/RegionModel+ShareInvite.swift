import FeatureCore
import Foundation

extension RegionModel {
    public nonisolated static let followingInviteKey = "fiscal.share.followingInviteDismissed"

    public var showsFollowingInvite: Bool { !followed.isEmpty && !isFollowingInviteDismissed }

    public var followingInviteRoute: Route { .share(.following) }

    public func dismissFollowingInvite() {
        isFollowingInviteDismissed = true
        inviteDefaults.set(true, forKey: Self.followingInviteKey)
    }
}
