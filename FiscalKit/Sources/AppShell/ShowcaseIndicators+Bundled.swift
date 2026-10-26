#if DEBUG
    import FiscalData
    import FiscalDomain
    import FiscalResource
    import Foundation

    extension ShowcaseIndicators {
        public static let bundled = ShowcaseIndicators(load: { Bundled.all })

        private enum Bundled {
            static let sources: [String: Source] = Dictionary(
                ShowcaseIndicatorsFile.sources.map { file in
                    (
                        file.id,
                        Source(
                            id: file.id, name: file.name, url: URL(string: file.url),
                            updatedAt: try? Date(file.updatedAt, strategy: .iso8601))
                    )
                }, uniquingKeysWith: { first, _ in first })

            static let all: [Indicator] = ShowcaseIndicatorsFile.series.compactMap(indicator)
        }

        static func indicator(_ series: ShowcaseIndicatorsFile.Series) -> Indicator? {
            guard let kind = IndicatorKind(rawValue: series.kind) else { return nil }
            let areas = series.areas.compactMap { area -> Indicator.Area? in
                guard let start = CalendarDay("\(area.start)-01") else { return nil }
                let points = area.values.enumerated().compactMap { offset, value in
                    value.map {
                        IndicatorPoint(date: IndicatorMath.month(start, adding: offset), value: $0)
                    }
                }
                return Indicator.Area(scope: area.scope, name: area.name, series: points)
            }
            return Indicator(
                id: series.id, name: series.name, unit: series.unit, kind: kind, areas: areas,
                sources: series.sources.compactMap { Bundled.sources[$0] })
        }
    }
#endif
