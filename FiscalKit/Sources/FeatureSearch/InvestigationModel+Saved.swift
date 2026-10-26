import FiscalDomain
import Foundation

extension InvestigationModel {
    public func rename(_ text: String) {
        guard let investigation = current else { return }
        rename(investigation, to: text)
    }

    public func rename(_ investigation: Investigation, to text: String) {
        let name = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var renamed = saved.first { $0.id == investigation.id } ?? investigation
        guard renamed.question != name else { return }
        renamed.question = name
        renamed.updatedAt = now()
        if current?.id == renamed.id {
            current?.question = name
            current?.updatedAt = renamed.updatedAt
        }
        persist(renamed)
    }

    public func togglePin() {
        guard let current else { return }
        togglePin(current)
    }

    public func togglePin(_ investigation: Investigation) {
        var pinned = saved.first { $0.id == investigation.id } ?? investigation
        pinned.isPinned.toggle()
        if current?.id == pinned.id { current?.isPinned = pinned.isPinned }
        persist(pinned)
    }

    public func delete(_ investigation: Investigation) {
        saved.removeAll { $0.id == investigation.id }
        let id = investigation.id
        enqueue { try await $0.delete(id: id) }
    }

    public func delete(at offsets: IndexSet) {
        let list = offsets.compactMap { saved.indices.contains($0) ? saved[$0] : nil }
        for investigation in list { delete(investigation) }
    }

    public func loadSaved() async {
        guard let repository else { return }
        await saving?.value
        await importLegacy(into: repository)
        if let list = try? await repository.investigations() {
            saved = Investigation.ordered(list.compactMap(Investigation.init(saved:)))
        }
        let syncs = await repository.syncsWithCloud()
        isOnDevice = !syncs
    }

    private func importLegacy(into repository: any InvestigationRepository) async {
        guard let legacy else { return }
        let list = legacy.load()
        guard !list.isEmpty else { return }
        var imported = true
        for investigation in list {
            guard let record = investigation.saved else { continue }
            do {
                try await repository.save(record)
            } catch {
                imported = false
            }
        }
        if imported { legacy.clear() }
    }

    func persist(_ investigation: Investigation) {
        saved.removeAll { $0.id == investigation.id }
        guard investigation.isWorthKeeping else {
            let id = investigation.id
            enqueue { try await $0.delete(id: id) }
            return
        }
        saved = Investigation.ordered(saved + [investigation])
        guard let record = investigation.saved else { return }
        enqueue { try await $0.save(record) }
    }

    private func enqueue(
        _ write: @escaping @Sendable (any InvestigationRepository) async throws -> Void
    ) {
        guard let repository else { return }
        let previous = saving
        saving = Task {
            await previous?.value
            try? await write(repository)
        }
    }
}
