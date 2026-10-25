import FeatureCore
import FiscalDomain
import Foundation
import Observation

@MainActor @Observable
public final class LensModel {
    public private(set) var lens = Lens()
    public private(set) var hasLoaded = false
    public private(set) var isSaved = false
    public var error: FiscalError?
    @ObservationIgnored private let repository: (any LensRepository)?

    public init(repository: (any LensRepository)?) {
        self.repository = repository
    }

    public var themes: [Theme] { Theme.allCases }

    public var canSave: Bool { repository != nil && lens.isComplete }

    public var countText: String {
        String(
            appLocalized:
                "\(lens.themes.count) of \(Lens.themeRange.upperBound) topics chosen")
    }

    public func isChosen(_ theme: Theme) -> Bool { lens.contains(theme) }

    public func canToggle(_ theme: Theme) -> Bool { lens.contains(theme) || lens.canAddTheme }

    public func toggle(_ theme: Theme) {
        lens.toggle(theme)
        isSaved = false
    }

    public func load() async {
        guard !hasLoaded else { return }
        do {
            lens = try await repository?.lens() ?? Lens()
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = .onFetch
        }
    }

    public func save() async {
        guard let repository, canSave else { return }
        do {
            try await repository.save(lens)
            isSaved = true
        } catch {
            self.error = .onSave
        }
    }
}
