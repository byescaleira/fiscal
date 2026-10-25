import SwiftUI

enum GroupedMetrics {
    static let margin: CGFloat = .spaceInset
    static let columnSpacing: CGFloat = .spaceInset
    static let sectionSpacing: CGFloat = .spaceXL
    static let rowInset: CGFloat = .spaceInset
    static let rowHeight: CGFloat = .rowHeight
    static let cornerRadius: CGFloat = .radiusGroup
}

struct GroupedSection: View {
    let section: SectionConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceS) {
            if !section.header.isEmpty {
                VStack(alignment: .leading) { section.header }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, GroupedMetrics.rowInset)
            }
            if !section.content.isEmpty {
                VStack(spacing: 0) {
                    ForEach(section.content) { row in
                        row
                            .padding(.horizontal, GroupedMetrics.rowInset)
                            .padding(.vertical, .spaceM - 1)
                            .frame(
                                maxWidth: .infinity, minHeight: GroupedMetrics.rowHeight,
                                alignment: .leading)
                        if row.id != section.content.last?.id {
                            Divider().padding(.leading, GroupedMetrics.rowInset)
                        }
                    }
                }
                .background(.groupedRow, in: .rect(cornerRadius: GroupedMetrics.cornerRadius))
            }
            if !section.footer.isEmpty {
                VStack(alignment: .leading) { section.footer }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, GroupedMetrics.rowInset)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
