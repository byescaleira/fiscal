import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
public final class LensModel {
    public static let othersLimit = 4

    public var editing: LensSetupModel.Step?
    public var isConfirmingErase = false
    public private(set) var isErasing = false
    public private(set) var recentVotes: [VoteSummary]?
    public private(set) var isLoadingVotes = false
    public private(set) var appIcon: AppIcon
    public private(set) var supportedCards: [PersonCard] = []
    public private(set) var others: [PersonCard] = []
    public private(set) var loadingOther: String?
    public var focusedTheme: Theme?
    public let catalog: ArtCatalog?
    @ObservationIgnored public let context: LensContext
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored private let follows: (any FollowRepository)?
    @ObservationIgnored let icons: (any AppIconSwitching)?

    public init(
        context: LensContext, catalog: ArtCatalog? = try? ArtCatalog.bundled(),
        service: (any PublicDataService)? = nil, icons: (any AppIconSwitching)? = nil,
        follows: (any FollowRepository)? = nil
    ) {
        self.context = context
        self.catalog = catalog
        self.service = service
        self.icons = icons
        self.follows = follows
        appIcon = icons?.current ?? .standard
    }

    public var lens: Lens? { context.saved }

    public var hasLens: Bool { lens?.hasChoice == true }

    public var supported: [String] { lens?.supported ?? [] }

    public var prefersNotToSay: Bool { lens?.prefersNotToSay == true }

    public var heroTitle: String {
        if !supportedCards.isEmpty { return SupportedPeople.names(supportedCards) }
        if prefersNotToSay { return String(appLocalized: "Prefer not to say") }
        return "—"
    }

    public var supportSummary: String {
        if prefersNotToSay {
            return String(appLocalized: "Neutral: topics in the order the data comes.")
        }
        let count = PublicFormat.number(supported.count)
        return String(appLocalized: "You support: \(count) of \(Lens.supportLimit)")
    }

    public var themes: [Theme] { lens?.themes ?? [] }

    public var palette: LensPaletteSwatch? { LensPaletteSwatch.named(lens?.palette) }

    public var paletteTitle: String { palette?.title ?? "—" }

    public var collection: ArtCollection? {
        lens?.artCollection.flatMap { catalog?.collection(id: $0) }
    }

    public var leadWork: ArtWork? {
        collection.flatMap { catalog?.leadWork(of: $0) }
    }

    public var isPreviewing: Bool { context.isPreviewing }

    public var isPreviewingNeutral: Bool { context.preview?.isNeutral == true }

    public func isPreviewing(_ card: PersonCard) -> Bool {
        context.preview?.supported == [card.slug]
    }

    public var otherLensFooter: String {
        String(
            appLocalized:
                "For a moment, see what stands out in the neutral order or for those who support someone else. Nothing is saved and the numbers do not change."
        )
    }

    public func previewNeutral() {
        context.show(
            Lens(
                themes: SupportThemes.suggested([], prefersNotToSay: true), prefersNotToSay: true,
                artCollection: lens?.artCollection, palette: lens?.palette))
    }

    public func preview(_ card: PersonCard) async {
        guard loadingOther == nil else { return }
        loadingOther = card.slug
        let activity = await SupportedPeople.activity(for: [card], service: service)
        context.show(
            Lens(
                themes: SupportThemes.suggested(activity), supported: [card.slug],
                artCollection: lens?.artCollection, palette: lens?.palette))
        loadingOther = nil
    }

    public func endPreview() {
        context.endPreview()
    }

    public func edit(_ step: LensSetupModel.Step) {
        editing = step
    }

    public func editor(for step: LensSetupModel.Step) -> LensSetupModel {
        LensSetupModel(
            context: context, catalog: catalog, editing: step, icons: icons, service: service,
            follows: follows)
    }

    public func loadVotes() async {
        guard let service, recentVotes == nil, !isLoadingVotes else { return }
        isLoadingVotes = true
        recentVotes = (try? await service.recentVotes()) ?? []
        isLoadingVotes = false
    }

    public func loadSupport() async {
        supportedCards = await SupportedPeople.cards(
            for: supported, service: service, follows: follows)
        guard others.isEmpty, let highlights = try? await service?.highlights() else { return }
        var seen: Set<String> = Set(supported)
        others = Array(
            highlights.items.compactMap(\.person)
                .filter { seen.insert($0.slug).inserted }
                .prefix(Self.othersLimit))
    }

    public func update(_ change: (inout Lens) -> Void) async {
        guard var next = lens else { return }
        change(&next)
        guard next != lens else { return }
        await context.save(next)
    }

    public func setIcon(_ icon: AppIcon) async {
        guard let icons, icon != appIcon else { return }
        let previous = appIcon
        appIcon = icon
        if (try? await icons.set(icon)) == nil {
            appIcon = previous
        } else {
            await update { $0.icon = icon.rawValue }
        }
    }

    public func erase() async {
        guard !isErasing else { return }
        isErasing = true
        if await context.erase() { isConfirmingErase = false }
        isErasing = false
    }
}
