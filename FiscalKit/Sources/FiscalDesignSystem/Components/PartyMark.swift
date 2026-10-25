import SwiftUI

public struct PartyMark: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.partyMarksAreStill) private var partyMarksAreStill
    private let party: String

    public init(_ party: String) {
        self.party = party
    }

    public var body: some View {
        Group {
            if isStill {
                PartyMarkChip(party: party, phase: .rest)
            } else {
                PhaseAnimator(PartyMarkPhase.allCases) { phase in
                    PartyMarkChip(party: party, phase: phase)
                } animation: { phase in
                    phase.animation
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Party \(party)"))
    }

    var isStill: Bool {
        reduceMotion || partyMarksAreStill
    }
}

enum PartyMarkPhase: CaseIterable {
    case rest
    case wave
    case ring

    var sheenOffset: CGFloat {
        switch self {
        case .rest: -1
        case .wave, .ring: 1
        }
    }

    var sheenOpacity: Double {
        self == .wave ? 1 : 0
    }

    var ringScale: CGFloat {
        self == .ring ? 1.3 : 1
    }

    var ringOpacity: Double {
        switch self {
        case .rest: 0
        case .wave: .opacitySoft
        case .ring: 0
        }
    }

    var animation: Animation {
        switch self {
        case .rest: .easeInOut(duration: 2.8)
        case .wave: .easeInOut(duration: 0.9)
        case .ring: .easeOut(duration: 0.8)
        }
    }
}

struct PartyMarkChip: View {
    let party: String
    let phase: PartyMarkPhase

    var body: some View {
        let palette = PartyPalette.of(party: party)
        Text(party.uppercased())
            .font(.chipLabel)
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, .spaceS)
            .padding(.vertical, .space2XS)
            .background {
                Capsule()
                    .fill(palette.gradient)
                    .overlay { sheen.clipShape(.capsule) }
            }
            .background {
                Capsule()
                    .stroke(palette.primary, lineWidth: .spaceHairline)
                    .scaleEffect(x: 1 + (phase.ringScale - 1) / 2, y: phase.ringScale)
                    .opacity(phase.ringOpacity)
            }
    }

    private var sheen: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, .white.opacity(.opacitySoft), .clear], startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: proxy.size.width / 2)
            .offset(x: proxy.size.width / 4 + phase.sheenOffset * proxy.size.width * 3 / 4)
            .opacity(phase.sheenOpacity)
        }
    }
}

extension EnvironmentValues {
    @Entry public var partyMarksAreStill = false
}

extension View {
    public func partyMarksStill(_ isStill: Bool = true) -> some View {
        environment(\.partyMarksAreStill, isStill)
    }
}
