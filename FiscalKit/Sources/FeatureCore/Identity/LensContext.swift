import FiscalDomain
import Observation

@MainActor @Observable
public final class LensContext {
    public private(set) var saved: Lens?
    public private(set) var preview: Lens?
    public private(set) var hasLoaded = false
    public var error: FiscalError?
    @ObservationIgnored private let repository: any LensRepository

    public init(repository: any LensRepository) {
        self.repository = repository
    }

    public var active: Lens? { preview ?? saved }

    public var isPreviewing: Bool { preview != nil }

    public var needsSetup: Bool { hasLoaded && saved?.hasChoice != true }

    public var supported: [String] { active?.supported ?? [] }

    public func load() async {
        guard !hasLoaded else { return }
        do {
            saved = try await repository.lens()
            hasLoaded = true
        } catch is CancellationError {} catch {
            self.error = .onFetch
        }
    }

    @discardableResult
    public func save(_ lens: Lens) async -> Bool {
        do {
            try await repository.save(lens)
            saved = lens
            preview = nil
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
            preview = nil
            return true
        } catch {
            self.error = .onRemove
            return false
        }
    }

    public func show(_ lens: Lens) {
        preview = lens
    }

    public func endPreview() {
        preview = nil
    }
}
