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
    public let catalog: ArtCatalog?
    @ObservationIgnored public let context: LensContext

    public init(context: LensContext, catalog: ArtCatalog? = try? ArtCatalog.bundled()) {
        self.context = context
        self.catalog = catalog
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
        LensSetupModel(context: context, catalog: catalog, editing: step)
    }

    public func erase() async {
        guard !isErasing else { return }
        isErasing = true
        if await context.erase() { isConfirmingErase = false }
        isErasing = false
    }
}
