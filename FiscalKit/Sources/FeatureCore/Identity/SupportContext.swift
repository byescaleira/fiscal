import FiscalDomain
import Observation

@MainActor @Observable
public final class SupportContext {
    public private(set) var saved: SupportChoice?
    public private(set) var hasLoaded = false
    public var error: FiscalError?
    @ObservationIgnored private let repository: any SupportRepository

    public init(repository: any SupportRepository) {
        self.repository = repository
    }

    public var choice: SupportChoice { saved ?? SupportChoice() }

    public func load() async {
        guard !hasLoaded else { return }
        do {
            saved = try await repository.support()
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = .onFetch
        }
    }

    @discardableResult
    public func save(_ support: SupportChoice) async -> Bool {
        do {
            try await repository.save(support)
            saved = support
            hasLoaded = true
            return true
        } catch {
            self.error = .onSave
            return false
        }
    }

    @discardableResult
    public func erase() async -> Bool {
        do {
            try await repository.reset()
            saved = nil
            return true
        } catch {
            self.error = .onRemove
            return false
        }
    }
}
