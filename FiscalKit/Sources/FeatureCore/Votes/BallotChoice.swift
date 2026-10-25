import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public enum BallotChoice: String, CaseIterable, Identifiable, Sendable {
    case yes, no, abstain, absent

    public var id: String { rawValue }

    public init?(vote: String) {
        let key = vote.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        switch key {
        case "": return nil
        case "sim": self = .yes
        case "nao": self = .no
        case "ausente", "nao votou": self = .absent
        case "liberado": return nil
        default: self = .abstain
        }
    }

    public var title: String {
        switch self {
        case .yes: String(appLocalized: "Yes")
        case .no: String(appLocalized: "No")
        case .abstain: String(appLocalized: "Abstention")
        case .absent: String(appLocalized: "Absent")
        }
    }

    public var groupTitle: String {
        switch self {
        case .abstain: String(appLocalized: "Abstention and other")
        case .yes, .no, .absent: title
        }
    }

    public var symbol: String {
        switch self {
        case .yes: "checkmark"
        case .no: "xmark"
        case .abstain: "minus"
        case .absent: "circle.dashed"
        }
    }

    public var color: Color {
        switch self {
        case .yes: .voteYes
        case .no: .voteNo
        case .abstain: .voteAbstain
        case .absent: .voteAbsent
        }
    }
}

public struct BallotChip: View {
    private let text: String
    private let choice: BallotChoice?

    public init(_ text: String, choice: BallotChoice?) {
        self.text = text
        self.choice = choice
    }

    public init(_ choice: BallotChoice) {
        self.init(choice.title, choice: choice)
    }

    public var body: some View {
        let color = choice?.color ?? .secondary
        Label {
            Text(verbatim: text)
        } icon: {
            Image(systemName: choice?.symbol ?? "circle.dotted")
        }
        .font(.chipLabel)
        .foregroundStyle(color)
        .padding(.horizontal, .spaceS)
        .padding(.vertical, .space2XS)
        .background(color.opacity(.opacityTint), in: .rect(cornerRadius: .radiusS))
        .overlay {
            if choice == .absent {
                RoundedRectangle(cornerRadius: .radiusS)
                    .strokeBorder(color, style: .dashed)
            }
        }
        .lineLimit(1)
        .fixedSize()
    }
}
