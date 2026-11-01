import FiscalDomain
import WidgetKit

public enum FollowingWidget {
    public static let kind = "fiscal.representatives"

    @MainActor
    public static func refresh(unfollowed slug: String?) {
        if let slug { FollowingSnapshot.forget(slug) }
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
