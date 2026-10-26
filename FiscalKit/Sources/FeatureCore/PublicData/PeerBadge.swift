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
    private let items: [PeerMethodItem]

    public init(items: [PeerMethodItem]) {
        self.items = items
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(
                        "Each number of the term is compared with peers in the same office and house in the same year. The number and the house median always show next to it."
                    )
                    Text(
                        "Above the third quartile (p75), between the first and third quartile, or below the first quartile (p25) of the house, with the direction of each number."
                    )
                    .font(.headline)
                } header: {
                    Text("Classification").sectionTitle()
                }
                ForEach(items) { person in
                    PeerMethodPersonSections(item: person)
                }
                Section {
                    Text(
                        "Peers without published data are left out of the count; a missing number never counts as zero. With fewer than 5 peers with data, the number gets no classification."
                    )
                    Text(
                        "Attendance doesn't measure committee work. Spending below average doesn't mean spending well. Bills and votes are never called good or bad: that is opinion."
                    )
                } header: {
                    Text("Limits").sectionTitle()
                }
            }
            .scrollContentBackground(.hidden)
            .background(.sheetBackground)
            .navigationTitle("How We Measure")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .tint(Color.primary)
                }
            }
        }
        .foregroundStyle(Color.primary)
        .fontDesign(.rounded)
        .presentationDetents([.medium, .large])
    }
}

private struct PeerMethodPersonSections: View {
    let item: PeerMethodItem

    var body: some View {
        let classification = item.classification
        ForEach(classification.entries, id: \.metric) { entry in
            Section {
                HStack {
                    PeerBadge(band: entry.entry.band)
                    Spacer(minLength: .spaceS)
                }
                if let detail = classification.detailText(entry.metric) {
                    Text(verbatim: detail)
                }
                if let range = classification.rangeText(entry.metric) {
                    Text(verbatim: range)
                        .foregroundStyle(.secondary)
                }
                Text(verbatim: entry.metric.direction)
                    .foregroundStyle(.secondary)
            } header: {
                Text(
                    verbatim: [item.name, entry.metric.title].compactMap(\.self).joined(
                        separator: " · ")
                )
                .sectionTitle()
            }
        }
    }
}
