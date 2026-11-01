import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct FollowButton: View {
    @Environment(FollowController.self) private var follow: FollowController?
    private let target: FollowTarget

    public init(_ card: PersonCard) {
        target = .card(card)
    }

    public init(slug: String, name: String) {
        target = .slug(slug, name: name)
    }

    public var body: some View {
        if let follow {
            let isFollowing = follow.isFollowing(target.slug)
            Button {
                Task { await target.toggle(with: follow) }
            } label: {
                Image(systemName: isFollowing ? "person.fill.checkmark" : "person.badge.plus")
                    .foregroundStyle(isFollowing ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .quietBounce(value: isFollowing)
                    .platformHitTarget()
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(target.label(isFollowing: isFollowing))
            .sensoryFeedback(.success, trigger: isFollowing)
        }
    }
}

extension View {
    public func followActions(_ card: PersonCard) -> some View {
        modifier(FollowActions(target: .card(card)))
    }

    public func followActions(slug: String, name: String) -> some View {
        modifier(FollowActions(target: .slug(slug, name: name)))
    }
}

private struct FollowActions: ViewModifier {
    @Environment(FollowController.self) private var follow: FollowController?
    let target: FollowTarget

    func body(content: Content) -> some View {
        if let follow {
            content.contextMenu {
                let isFollowing = follow.isFollowing(target.slug)
                Button(
                    isFollowing ? "Unfollow" : "Follow",
                    systemImage: isFollowing ? "person.badge.minus" : "person.badge.plus"
                ) {
                    Task { await target.toggle(with: follow) }
                }
            }
        } else {
            content
        }
    }
}

enum FollowTarget: Sendable {
    case card(PersonCard)
    case slug(String, name: String)

    var slug: String {
        switch self {
        case .card(let card): card.slug
        case .slug(let slug, _): slug
        }
    }

    var name: String {
        switch self {
        case .card(let card): card.name
        case .slug(_, let name): name
        }
    }

    func label(isFollowing: Bool) -> String {
        isFollowing
            ? String(appLocalized: "Unfollow \(name)") : String(appLocalized: "Follow \(name)")
    }

    @MainActor func toggle(with follow: FollowController) async {
        let isFollowing =
            switch self {
            case .card(let card): await follow.toggle(card)
            case .slug(let slug, _): await follow.toggle(slug: slug)
            }
        FollowController.announce(name: name, isFollowing: isFollowing)
    }
}

extension FollowController {
    public static func announce(name: String, isFollowing: Bool) {
        let message =
            isFollowing
            ? String(appLocalized: "Following \(name)")
            : String(appLocalized: "Stopped following \(name)")
        AccessibilityNotification.Announcement(message).post()
    }
}
