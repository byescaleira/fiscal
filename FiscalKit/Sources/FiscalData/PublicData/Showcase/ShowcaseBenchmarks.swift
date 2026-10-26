#if DEBUG
    import FiscalDomain
    import Foundation

    enum ShowcaseBenchmarks {
        static let minimumPeers = 5

        struct Values {
            let presence: Double?
            let quota: Double?
            let proposals: Double?
            let speeches: Double?
        }

        static func classification(
            for card: PersonCard, peers: [PersonCard], year: Int, month: Int
        ) -> PeerClassification? {
            guard eligible(card) else { return nil }
            let group = peers.filter { $0.office == card.office && eligible($0) }
            var seen = Set<String>()
            let values = group.compactMap { peer -> (String, Values)? in
                guard seen.insert(peer.slug).inserted else { return nil }
                return values(for: peer, year: year, month: month).map { (peer.slug, $0) }
            }
            guard let own = values.first(where: { $0.0 == card.slug })?.1 else { return nil }
            let all = values.map(\.1)
            let presence = entry(.presence, own.presence, all.compactMap(\.presence), digits: 1)
            let quota = entry(.quota, own.quota, all.compactMap(\.quota), digits: 0)
            let proposals = entry(
                .proposals, own.proposals, all.compactMap(\.proposals), digits: 1)
            let speeches = entry(.speeches, own.speeches, all.compactMap(\.speeches), digits: 1)
            guard presence != nil || quota != nil || proposals != nil || speeches != nil else {
                return nil
            }
            return PeerClassification(
                year: year, office: card.office.rawValue,
                house: card.office == .senator ? "senado" : "camara", uf: nil,
                presence: presence, quota: quota, proposals: proposals, speeches: speeches)
        }

        private static func eligible(_ card: PersonCard) -> Bool {
            ShowcaseProfiles.isFederalLegislator(card.office) && card.status == .inOffice
        }

        private static func values(for card: PersonCard, year: Int, month: Int) -> Values? {
            let seed = ShowcasePeople.seed(card.slug)
            guard
                let summary = ShowcaseProfiles.years(seed: seed, through: year)
                    .first(where: { $0.year == year })
            else { return nil }
            let presence: Double? =
                if let present = summary.present, let eligible = summary.eligible, eligible > 0 {
                    100 * Double(present) / Double(eligible)
                } else {
                    nil
                }
            return Values(
                presence: presence,
                quota: summary.quotaCents.map { Double($0) / Double(max(month, 1)) },
                proposals: summary.proposals.map(Double.init),
                speeches: summary.speeches.map(Double.init))
        }

        private static func entry(
            _ metric: PeerClassification.Metric, _ own: Double?, _ values: [Double], digits: Int
        ) -> PeerClassification.Entry? {
            guard let own, values.count >= minimumPeers else { return nil }
            let sorted = values.map { round($0, digits) }.sorted()
            let p25 = round(percentile(sorted, 0.25), digits)
            let median = round(percentile(sorted, 0.5), digits)
            let p75 = round(percentile(sorted, 0.75), digits)
            let value = round(own, digits)
            return PeerClassification.Entry(
                value: value, band: band(metric, value, p25: p25, p75: p75), median: median,
                p25: p25, p75: p75, n: sorted.count)
        }

        private static func band(
            _ metric: PeerClassification.Metric, _ value: Double, p25: Double, p75: Double
        ) -> PeerClassification.Band {
            let above = value > p75
            let below = value < p25
            switch metric {
            case .presence: return above ? .better : below ? .worse : .average
            case .quota: return above ? .worse : below ? .better : .average
            case .proposals, .speeches: return above ? .more : below ? .less : .average
            }
        }

        private static func percentile(_ sorted: [Double], _ quantile: Double) -> Double {
            let position = quantile * Double(sorted.count - 1)
            let low = Int(position.rounded(.down))
            let high = Int(position.rounded(.up))
            return sorted[low] + (sorted[high] - sorted[low]) * (position - Double(low))
        }

        private static func round(_ value: Double, _ digits: Int) -> Double {
            let factor = pow(10, Double(digits))
            return (value * factor).rounded() / factor
        }
    }
#endif
