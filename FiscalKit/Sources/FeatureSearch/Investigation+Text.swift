import FiscalDomain
import Foundation

extension Investigation {
    public var updatedDay: String {
        updatedAt.formatted(.dateTime.day().month(.abbreviated).locale(.app))
    }
}

extension HighlightRef {
    public var dayText: String {
        date.date().formatted(.dateTime.day().month(.abbreviated).locale(.app))
    }
}

extension InvestigationLink.Visual {
    static func changeColumn(_ title: String, months: Int) -> String {
        String(appLocalized: "\(title) · \(months) months").uppercased(with: .app)
    }
}

extension Collection where Element == VoteDetail.Ballot {
    func namesText(limit: Int) -> String {
        let shown = prefix(limit).map { "\($0.name) (\($0.party)-\($0.uf.uppercased()))" }
        let rest = count - shown.count
        let list = shown.formatted(.list(type: .and).locale(.app))
        return rest > 0 ? String(appLocalized: "\(list) and \(rest) more") : list
    }
}
