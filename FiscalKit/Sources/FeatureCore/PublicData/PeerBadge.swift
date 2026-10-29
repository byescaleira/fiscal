import FiscalDesignSystem
import FiscalDomain
import SwiftUI

extension PeerClassification.Band {
    public var color: Color {
        switch self {
        case .better: .retroOlive
        case .worse: .retroRust
        case .more, .less: .retroDenim
        case .average: .secondary
        }
    }
}

public struct PeerBadge: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private let band: PeerClassification.Band

    public init(band: PeerClassification.Band) {
        self.band = band
    }

    public var body: some View {
        Label {
            Text(verbatim: band.title)
        } icon: {
            Image(systemName: band.symbol)
        }
        .font(.chipLabel)
        .foregroundStyle(band.color)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .space2XS)
        .background(band.color.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS))
    }
}

public struct RelevanceBadge: View {
    private let relevance: Relevance
    private let color: Color

    public init(weight: Int, color: Color = .retroTeal) {
        relevance = Relevance(weight: weight)
        self.color = color
    }

    public var body: some View {
        Chip(relevance.title, color: color)
            .accessibilityLabel(Text(verbatim: relevance.title))
    }
}

public struct PeerMethodItem: Identifiable, Sendable {
    public let name: String?
    public let classification: PeerClassification

    public init(name: String?, classification: PeerClassification) {
        self.name = name
        self.classification = classification
    }

    public var id: String { name ?? "" }
}

public struct PeerMethodButton: View {
    @State private var isPresented = false
    private let items: [PeerMethodItem]

    public init(classification: PeerClassification?) {
        items = classification.map { [PeerMethodItem(name: nil, classification: $0)] } ?? []
    }

    public init(items: [PeerMethodItem]) {
        self.items = items
    }

    public var body: some View {
        if !items.isEmpty {
            Button {
                isPresented = true
            } label: {
                Label("How We Measure", systemImage: "info.circle")
                    .font(.footnote.weight(.semibold))
            }
            .buttonStyle(.borderless)
            .accessibilityHint(Text("Explains how each number is compared with peers"))
            .sheet(isPresented: $isPresented) {
                PeerMethodSheet(items: items)
            }
        }
    }
}

public struct PeerMethodSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var index = 0
    private let items: [PeerMethodItem]

    public init(items: [PeerMethodItem]) {
        self.items = items
    }

    public var body: some View {
        let count = items.count + 2
        let isLast = index == count - 1
        GuideSheet(
            index: index, count: count, back: index > 0 ? { index -= 1 } : nil,
            primary: GuideAction(isLast ? "Done" : "Continue") {
                if isLast { dismiss() } else { index += 1 }
            }
        ) {
            page
        }
    }

    @ViewBuilder private var page: some View {
        if index == 0 {
            GuidePage(
                title: "How We Measure",
                message:
                    "Each number is compared with peers in the same office and house in the same year, next to the house median."
            ) {
                EmptyView()
            } content: {
                GuideValueList(PeerClassification.Band.guideRows)
            }
        } else if items.indices.contains(index - 1) {
            PeerMethodPersonPage(item: items[index - 1])
        } else {
            GuidePage(
                title: "Limits",
                message:
                    "Peers without published data are left out. A missing number never counts as zero."
            ) {
                EmptyView()
            } content: {
                GuideFeatureList {
                    GuideFeature(
                        title: String(appLocalized: "Fewer than 5 peers with data"),
                        detail: String(appLocalized: "The number gets no classification."))
                    GuideFeature(
                        title: String(appLocalized: "Attendance"),
                        detail: String(appLocalized: "It doesn't measure committee work."))
                    GuideFeature(
                        title: String(appLocalized: "Spending below average"),
                        detail: String(appLocalized: "It doesn't mean spending well."))
                    GuideFeature(
                        title: String(appLocalized: "Bills and votes"),
                        detail: String(appLocalized: "Never called good or bad: that is opinion."))
                }
            }
        }
    }
}

private struct PeerMethodPersonPage: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let item: PeerMethodItem

    var body: some View {
        let classification = item.classification
        GuidePage(
            verbatim: item.name ?? String(appLocalized: "Numbers of the Term"),
            message: String(appLocalized: "Where each number falls among peers.")
        ) {
            EmptyView()
        } content: {
            ScrollView {
                GuideFeatureList {
                    ForEach(classification.entries, id: \.metric) { entry in
                        GuideFeature(
                            title: "\(entry.metric.title): \(entry.entry.band.title)",
                            detail: [
                                classification.detailText(entry.metric),
                                classification.rangeText(entry.metric), entry.metric.direction,
                            ]
                            .compactMap(\.self).joined(separator: "\n"),
                            color: entry.entry.band.color)
                    }
                }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .guideScrollMax)
        }
    }
}

extension PeerClassification.Band {
    @MainActor static var guideRows: [GuideValue] {
        [Self.better, .average, .worse, .more, .less].map {
            GuideValue($0.title, value: $0.position, color: $0.color)
        }
    }

    var position: String {
        switch self {
        case .better: String(appLocalized: "Past p25 or p75, on the good side")
        case .average: String(appLocalized: "Between p25 and p75")
        case .worse: String(appLocalized: "Past p25 or p75, on the other side")
        case .more: String(appLocalized: "Above p75, no direction")
        case .less: String(appLocalized: "Below p25, no direction")
        }
    }
}
