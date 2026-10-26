import AppIntents
import FeatureCore
import FiscalDomain
import Foundation

public struct FiscalIntentsPackage: AppIntentsPackage {}

public struct RepresentativesVoteIntent: AppIntent {
    public static var title: LocalizedStringResource { "How Did My Representatives Vote?" }
    public static var description: IntentDescription {
        IntentDescription(
            "Opens the latest roll-call vote and tells how the representatives from your state voted."
        )
    }
    public static var supportedModes: IntentModes { .foreground }

    @Parameter(
        title: "State",
        description: "Leave it empty to use the state picked in Fiscal.")
    public var state: StateOption?

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("See how the representatives from \(\.$state) voted")
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let uf = state?.rawValue ?? HomePlace.chosenUF(in: .standard) else {
            throw $state.needsValueError("Which state?")
        }
        let actions = try IntentWorkspace.actions()
        let ballots: RepresentativeBallots?
        do {
            ballots = try await actions.latestVote(uf: uf)
        } catch {
            throw IntegrationError.unavailable
        }
        guard let ballots else {
            FiscalServices.shared.pendingURL = IntegrationLink.votes
            return .result(dialog: "No roll-call vote has been published yet.")
        }
        FiscalServices.shared.pendingURL = ballots.vote.url
        return .result(dialog: "\(ballots.dialog)")
    }
}

public struct OpenPersonIntent: OpenIntent {
    public static var title: LocalizedStringResource { "Open Profile" }
    public static var description: IntentDescription {
        IntentDescription("Opens the profile of a politician in Fiscal.")
    }
    public static var supportedModes: IntentModes { .foreground }

    @Parameter(title: "Politician")
    public var target: PersonEntity

    public init() {}

    public static var parameterSummary: some ParameterSummary {
        Summary("Open the profile of \(\.$target)")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        FiscalServices.shared.pendingURL = IntegrationLink.person(target.id)
        return .result()
    }
}

public struct ShowRacesIntent: AppIntent {
    public static var title: LocalizedStringResource { "Show the Vote Count" }
    public static var description: IntentDescription {
        IntentDescription("Opens the live vote count of the elections in Fiscal.")
    }
    public static var supportedModes: IntentModes { .foreground }

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        FiscalServices.shared.pendingURL = IntegrationLink.races
        return .result()
    }
}
