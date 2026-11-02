import FiscalDesignSystem

public enum ProfilePortraitChoreography {
    public static func gesture(for chapter: ProfileChapter) -> PortraitGesture {
        switch chapter {
        case .votes: .tilt
        case .proposals: .browRaise
        case .money: .lookAround
        case .origin: .settle
        case .term: .lookAround
        case .checks: .doubleBlink
        case .about: .tilt
        }
    }
}
