import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
public final class LensModel {
    public var editing: LensSetupModel.Step?
    public var isConfirmingErase = false
    public private(set) var isErasing = false
    public private(set) var recentVotes: [VoteSummary]?
    public private(set) var isLoadingVotes = false
    public private(set) var appIcon: AppIcon
    public var focusedTheme: Theme?
    public let catalog: ArtCatalog?
    @ObservationIgnored public let context: LensContext
    @ObservationIgnored private let service: (any PublicDataService)?
    @ObservationIgnored let icons: (any AppIconSwitching)?

    public init(
        context: LensContext, catalog: ArtCatalog? = try? ArtCatalog.bundled(),
        service: (any PublicDataService)? = nil, icons: (any AppIconSwitching)? = nil
    ) {
        self.context = context
        self.catalog = catalog
        self.service = service
        self.icons = icons
        appIcon = icons?.current ?? .standard
    }

    public var lens: Lens? { context.saved }

    public var stance: PoliticalStance? { lens?.stance }

    public var hasLens: Bool { stance != nil }

    public var stanceTitle: String { stance?.title ?? "—" }

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

    public var previewStance: PoliticalStance? { context.preview?.stance }

    public var otherStances: [PoliticalStance] {
        PoliticalStance.choices.filter { $0 != stance?.effective }
    }

    public var otherLensFooter: String {
        if let stance, stance.isImpartial {
            return String(
                appLocalized:
                    "With the impartial lens, every other lens stays one tap away. Nothing is saved and the numbers do not change."
            )
        }
        return String(
            appLocalized:
                "See the app through the topics of another side for a moment. Nothing is saved and the numbers do not change."
        )
    }

    public func isPreviewing(_ other: PoliticalStance) -> Bool { previewStance == other }

    public func preview(_ other: PoliticalStance) {
        context.show(LensPreset.suggested(for: other).lens(stance: other))
    }

    public func endPreview() {
        context.endPreview()
    }

    public func edit(_ step: LensSetupModel.Step) {
        editing = step
    }

    public func editor(for step: LensSetupModel.Step) -> LensSetupModel {
        LensSetupModel(context: context, catalog: catalog, editing: step, icons: icons)
    }

    public func loadVotes() async {
        guard let service, recentVotes == nil, !isLoadingVotes else { return }
        isLoadingVotes = true
        recentVotes = (try? await service.recentVotes()) ?? []
        isLoadingVotes = false
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
        if (try? await icons.set(icon)) == nil { appIcon = previous }
    }

    public func erase() async {
        guard !isErasing else { return }
        isErasing = true
        if await context.erase() { isConfirmingErase = false }
        isErasing = false
    }
}
