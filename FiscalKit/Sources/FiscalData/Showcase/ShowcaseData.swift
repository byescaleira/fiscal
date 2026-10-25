#if DEBUG
    import Foundation
    import FiscalDomain

    public enum ShowcaseData {
        public static let titles = [
            "Plan the week", "Morning walk", "Read twenty pages", "Call the family",
            "Water the plants",
        ]

        public static func seed(_ repositories: Repositories, today: Date = .now) async throws {
            guard try await repositories.items.items().isEmpty else { return }
            for (index, title) in titles.enumerated() {
                let date = today.addingTimeInterval(-Double(index) * 86_400)
                try await repositories.items.save(
                    Item(id: "showcase-\(index)", title: title, createdAt: date))
            }
        }
    }
#endif
