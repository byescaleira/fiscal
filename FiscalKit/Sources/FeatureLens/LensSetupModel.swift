import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import FiscalResource
import Foundation
import Observation

@MainActor @Observable
public final class LensSetupModel {
    public enum Step: Int, CaseIterable, Identifiable, Sendable {
        case welcome, stance, themes, look

        public var id: Int { rawValue }

        static var counted: [Step] { [.stance, .themes, .look] }
    }

    public private(set) var step: Step
    public private(set) var draft: Lens
    public private(set) var isFinished = false
    public private(set) var isSaving = false
    public private(set) var movesForward = true
    public var showsMoreThemes: Bool
    public let catalog: ArtCatalog?
    public let editing: Step?
    @ObservationIgnored private let context: LensContext
    @ObservationIgnored private var themesTouched: Bool
    @ObservationIgnored private var lookTouched: Bool

    public init(context: LensContext, catalog: ArtCatalog?, editing: Step? = nil) {
        let start = context.saved ?? Lens()
        self.context = context
        self.catalog = catalog
        self.editing = editing
        draft = start
        step = editing ?? .welcome
        themesTouched = editing != nil || !start.themes.isEmpty
        lookTouched = editing != nil || start.palette != nil
        showsMoreThemes = start.themes.contains { Theme.moreChoices.contains($0) }
    }

    public var isEditing: Bool { editing != nil }

    public var stanceChoices: [PoliticalStance] { PoliticalStance.choices }

    public var themeChoices: [Theme] {
        showsMoreThemes ? Theme.setupChoices + Theme.moreChoices : Theme.setupChoices
    }

    public var palettePairs: [[LensPaletteSwatch]] {
        LensPaletteSwatch.leading.map { [$0, $0.mirror] }
    }

    public var collections: [ArtCollection] { catalog?.collections ?? [] }

    public var stepIndex: Int { (Step.counted.firstIndex(of: step) ?? -1) + 1 }

    public var progress: Double { Double(stepIndex) / Double(Step.counted.count) }

    public var stepText: String {
        String(appLocalized: "Step \(stepIndex) of \(Step.counted.count)")
    }

    public var themeCountText: String {
        String(
            appLocalized:
                "\(draft.themes.count) of \(Lens.themeRange.upperBound) topics chosen")
    }

    public var suggestionText: String? {
        guard let stance = draft.stance, !isEditing else { return nil }
        return String(appLocalized: "Pre-marked for \(stance.effective.title). Change as you like.")
    }

    public var canContinue: Bool {
        switch step {
        case .welcome: true
        case .stance: draft.stance != nil
        case .themes: draft.isComplete
        case .look: palette != nil && draft.artCollection != nil
        }
    }

    public var primaryTitle: String {
        if isEditing { return String(appLocalized: "Save") }
        return switch step {
        case .welcome: String(appLocalized: "Start · 1 min")
        case .stance, .themes: String(appLocalized: "Continue")
        case .look: String(appLocalized: "Done")
        }
    }

    public var canGoBack: Bool { !isEditing && step != .welcome }

    public var isLastStep: Bool { isEditing || step == .look }

    public var palette: LensPaletteSwatch? { LensPaletteSwatch.named(draft.palette) }

    public var collection: ArtCollection? {
        draft.artCollection.flatMap { catalog?.collection(id: $0) }
    }

    public var backdrop: ArtWork? {
        if let collection, let work = catalog?.leadWork(of: collection) { return work }
        return welcomeWorks.first
    }

    public var welcomeWorks: [ArtWork] {
        guard let catalog else { return [] }
        let leads = catalog.collections.compactMap { catalog.leadWork(of: $0) }
        let others = catalog.works.filter { !leads.contains($0) }
        return Array((leads + others).prefix(7))
    }

    public func works(in collection: ArtCollection) -> [ArtWork] {
        guard let catalog else { return [] }
        let lead = catalog.leadWork(of: collection)
        let rest = catalog.works(in: collection.id).filter { $0 != lead }
        return [lead].compactMap { $0 } + rest
    }

    public func isChosen(_ stance: PoliticalStance) -> Bool { draft.stance == stance }

    public func isChosen(_ theme: Theme) -> Bool { draft.contains(theme) }

    public func canToggle(_ theme: Theme) -> Bool { draft.contains(theme) || draft.canAddTheme }

    public func isChosen(_ swatch: LensPaletteSwatch) -> Bool { palette == swatch }

    public func isChosen(_ collection: ArtCollection) -> Bool {
        draft.artCollection == collection.id
    }

    public func choose(_ stance: PoliticalStance) {
        let preset = LensPreset.suggested(for: stance)
        draft = Lens(
            themes: themesTouched ? draft.themes : preset.themes, stance: stance,
            artCollection: lookTouched ? draft.artCollection : preset.artCollection,
            palette: lookTouched ? draft.palette : preset.palette)
    }

    public func toggle(_ theme: Theme) {
        draft.toggle(theme)
        themesTouched = true
    }

    public func choose(_ swatch: LensPaletteSwatch) {
        draft.palette = swatch.rawValue
        lookTouched = true
    }

    public func choose(_ collection: ArtCollection) {
        draft.artCollection = collection.id
        lookTouched = true
    }

    public func advance() async {
        guard canContinue else { return }
        if isLastStep {
            await finish()
        } else if let next = Step(rawValue: step.rawValue + 1) {
            movesForward = true
            step = next
        }
    }

    public func goBack() {
        guard canGoBack, let previous = Step(rawValue: step.rawValue - 1) else { return }
        movesForward = false
        step = previous
    }

    public func finish() async {
        guard !isSaving else { return }
        isSaving = true
        isFinished = await context.save(draft)
        isSaving = false
    }
}
