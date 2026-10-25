#if DEBUG
    import FiscalDomain
    import Foundation

    public struct ShowcaseIndicators: Sendable {
        let load: @Sendable () -> [Indicator]

        public init(load: @escaping @Sendable () -> [Indicator]) {
            self.load = load
        }

        public static let none = ShowcaseIndicators(load: { [] })

        func catalog() -> IndicatorCatalog? {
            let all = load()
            guard !all.isEmpty else { return nil }
            return IndicatorCatalog(items: all.map(IndicatorSummary.init), sources: sources(all))
        }

        func indicator(id: String) -> Indicator? {
            load().first { $0.id == id }
        }

        func context(for card: PersonCard) -> PersonContext? {
            guard card.status != .electedAwaiting,
                let start = ShowcaseProfiles.mandate(for: card).start
            else { return nil }
            return PersonContext.calculate(load(), mandateStart: start, uf: card.uf)
        }

        private func sources(_ all: [Indicator]) -> [Source] {
            var out: [Source] = []
            for source in all.flatMap(\.sources) where !out.contains(where: { $0.id == source.id })
            {
                out.append(source)
            }
            return out
        }
    }
#endif
