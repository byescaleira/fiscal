import FeatureCore
import FiscalDesignSystem
import FiscalDomain
import SwiftUI

public struct StudyGuideScreen: View {
    @Environment(StudyGuideModel.self) private var model

    public init() {}

    public var body: some View {
        PublicDataContent(
            phase: model.phase, isEmpty: model.guide == nil, retry: { await model.load() }
        ) {
            if let guide = model.guide {
                switch guide.kind {
                case .guide: GuideContent(guide: guide)
                case .glossary: GlossaryContent(guide: guide)
                }
            }
        } empty: {
            EmptyStateView(
                title: "Guide not found",
                description: "The study guides aren't published by Fiscal yet."
            ) {
                IconRow("Swipe through the cards", symbol: "rectangle.stack", color: .retroDenim)
                IconRow("Test yourself", symbol: "checkmark.circle", color: .retroOlive)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.plainBackground)
        }
        .navigationTitle(Text(verbatim: model.guide?.title ?? ""))
        .task { await model.load() }
    }
}

private struct GuideContent: View {
    let guide: StudyGuide

    var body: some View {
        AdaptiveList {
            GuideHeroSection(guide: guide)
            Section {
                EdgeToEdgeRail(lazy: true) {
                    ForEach(Array(guide.cards.enumerated()), id: \.element.id) { index, card in
                        StudyCardView(
                            card: card, position: guide.cardPosition(index),
                            color: ChartPalette.color(
                                at: index % ChartPalette.categorical.count)
                        )
                        .containerRelativeFrame(.horizontal) { width, _ in
                            .railCard(
                                in: width, share: .studyCardShare,
                                columnShare: .studyCardColumnShare)
                        }
                    }
                }
            } header: {
                Text("Swipe through the cards").sectionTitle().railHeader()
            }
            .railSection()
            if !guide.quiz.isEmpty {
                QuizSections(guide: guide)
            }
            Section {
                SourceLinks(refs: guide.sources)
            } header: {
                Text("Official sources").sectionTitle()
            }
        }
    }
}

private struct GuideHeroSection: View {
    @Environment(StudyGuideModel.self) private var model
    @Environment(\.appTint) private var tint
    let guide: StudyGuide

    var body: some View {
        Section {
        } header: {
            VStack(spacing: .spaceS) {
                SymbolBadge(guide.symbol, color: tint, size: .badgeXL)
                Chip(model.heroChip, color: tint, shape: .capsule)
                Text(verbatim: guide.summary)
                    .font(.emphasis(.title3, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .textCase(nil)
            .padding(.vertical, .spaceL)
        }
    }
}

private struct StudyCardView: View {
    let card: StudyCard
    let position: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: .spaceM) {
            HStack {
                Chip(position, color: .white, shape: .capsule)
                    .monospacedDigit()
                    .environment(\.colorScheme, .dark)
                Spacer(minLength: .spaceS)
            }
            Text(verbatim: card.title)
                .font(.emphasis(.title2, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: card.text)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: .spaceS)
            Text(verbatim: card.sourceLine)
                .font(.caption.weight(.medium))
                .opacity(.opacityStrong)
        }
        .foregroundStyle(.white)
        .padding(.spaceInset)
        .frame(maxWidth: .infinity, minHeight: .studyCardMinHeight, alignment: .topLeading)
        .background {
            ZStack {
                color
                Color.scoreboard.opacity(.opacitySoft)
            }
        }
        .clipShape(.rect(cornerRadius: .radiusGroup))
        .accessibilityElement(children: .combine)
    }
}

private struct QuizSections: View {
    @Environment(StudyGuideModel.self) private var model
    let guide: StudyGuide

    var body: some View {
        ForEach(Array(guide.quiz.enumerated()), id: \.element.id) { index, question in
            Section {
                QuestionOptions(question: question, index: index)
            } header: {
                VStack(alignment: .leading, spacing: .space2XS) {
                    if index == 0 {
                        HStack {
                            Text("Test yourself").sectionTitle()
                            Spacer(minLength: .spaceS)
                            Text(verbatim: model.progressLine)
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(verbatim: guide.questionTitle(index))
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .textCase(nil)
            } footer: {
                if index == guide.quiz.count - 1, model.answered > 0 {
                    Button("Start Over", systemImage: "arrow.counterclockwise") { model.restart() }
                        .font(.buttonLabel)
                        .buttonStyle(.borderless)
                }
            }
        }
    }
}

private struct QuestionOptions: View {
    @Environment(StudyGuideModel.self) private var model
    let question: StudyQuestion
    let index: Int

    var body: some View {
        let chosen = model.answers[index]
        ForEach(Array(question.options.enumerated()), id: \.offset) { option, text in
            Button {
                model.choose(option, for: index)
            } label: {
                HStack(spacing: .spaceM) {
                    OptionMark(state: state(option, chosen: chosen))
                    Text(verbatim: text)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(chosen != nil)
            .sensoryFeedback(trigger: chosen) { _, new in
                guard new != nil else { return nil }
                return new == question.answer ? .success : .error
            }
        }
        if chosen != nil {
            VStack(alignment: .leading, spacing: .space2XS) {
                Text(verbatim: question.explanation)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                SourceLinks(refs: question.sources)
            }
            .padding(.vertical, .space2XS)
        }
    }

    private func state(_ option: Int, chosen: Int?) -> OptionMark.State {
        guard let chosen else { return .open }
        if option == question.answer { return .right }
        return option == chosen ? .wrong : .idle
    }
}

private struct OptionMark: View {
    enum State {
        case open, right, wrong, idle
    }

    let state: State

    var body: some View {
        switch state {
        case .open:
            StatusCircle(
                String(appLocalized: "Not answered"), symbol: "circle", color: .secondary,
                isDashed: true)
        case .right:
            StatusCircle(
                String(appLocalized: "Right answer"), symbol: "checkmark", color: .retroOlive)
        case .wrong:
            StatusCircle(String(appLocalized: "Your answer"), symbol: "xmark", color: .retroRust)
        case .idle:
            StatusCircle(String(appLocalized: "Other option"), symbol: "minus", color: .secondary)
        }
    }
}

private struct GlossaryContent: View {
    @Environment(StudyGuideModel.self) private var model
    let guide: StudyGuide

    var body: some View {
        @Bindable var model = model
        List {
            Group {
                Section {
                    ForEach(model.terms) { term in
                        VStack(alignment: .leading, spacing: .space2XS) {
                            Text(verbatim: term.term).font(.rowTitle)
                            Text(verbatim: term.definition)
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            SourceLinks(refs: term.sources)
                        }
                        .padding(.vertical, .space2XS)
                    }
                } header: {
                    Text(verbatim: guide.summary)
                        .font(.subheadline)
                        .textCase(nil)
                } footer: {
                    Text("Alphabetical order. Each definition follows the official source cited.")
                }
            }
            .surfaceRows()
        }
        .listSurface()
        .searchable(text: $model.query, prompt: Text("Search a term"))
        .overlay {
            if model.terms.isEmpty {
                ContentUnavailableView.search(text: model.query)
            }
        }
    }
}
