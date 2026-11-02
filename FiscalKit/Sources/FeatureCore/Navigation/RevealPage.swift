import FiscalDesignSystem
import SwiftUI

@MainActor @Observable
final class RevealPageState {
    private(set) var showsBar = false
    private(set) var current: AnyHashable?
    var headerHeight = CGFloat.revealBarEstimate
    @ObservationIgnored var order: [AnyHashable] = []
    @ObservationIgnored var offset: CGFloat = 0
    @ObservationIgnored private var tops: [AnyHashable: CGFloat] = [:]
    @ObservationIgnored private var pageTop: CGFloat = 0
    @ObservationIgnored private var heroBottom = CGFloat.infinity

    private var line: CGFloat { pageTop + headerHeight + .spaceL }

    func move(pageTop: CGFloat) {
        self.pageTop = pageTop
        refresh()
    }

    func move(heroBottom: CGFloat) {
        self.heroBottom = heroBottom
        refresh()
    }

    func move(chapter: AnyHashable, top: CGFloat) {
        tops[chapter] = top
        refresh()
    }

    func refresh() {
        let shows = heroBottom - pageTop < headerHeight
        if shows != showsBar { showsBar = shows }
        let next = Self.chapter(in: order, tops: tops, line: line + .spaceHairline)
        if next != current { current = next }
    }

    func target(of chapter: AnyHashable) -> CGFloat? {
        tops[chapter].map { offset + $0 - line }
    }

    static func chapter(
        in order: [AnyHashable], tops: [AnyHashable: CGFloat], line: CGFloat
    ) -> AnyHashable? {
        order.last { chapter in tops[chapter].map { $0 <= line } ?? false }
    }
}

public struct RevealPage<Chapter: Hashable & SendableMetatype, Content: View, Bar: View>: View {
    @ReducesMotion private var reduceMotion
    @State private var state = RevealPageState()
    @State private var position = ScrollPosition()
    private let chapters: [Chapter]
    private let maxWidth: CGFloat
    private let onChapter: (Chapter?) -> Void
    private let refresh: () async -> Void
    private let content: (@escaping (Chapter) -> Void) -> Content
    private let bar: (@escaping (Chapter) -> Void, Bool) -> Bar

    public init(
        chapters: [Chapter], maxWidth: CGFloat = .readableColumn,
        onChapter: @escaping (Chapter?) -> Void = { _ in },
        refresh: @escaping () async -> Void,
        @ViewBuilder content: @escaping (@escaping (Chapter) -> Void) -> Content,
        @ViewBuilder bar: @escaping (@escaping (Chapter) -> Void, Bool) -> Bar
    ) {
        self.chapters = chapters
        self.maxWidth = maxWidth
        self.onChapter = onChapter
        self.refresh = refresh
        self.content = content
        self.bar = bar
    }

    public var body: some View {
        @Bindable var state = state
        ScrollView {
            VStack(alignment: .leading, spacing: .space2XL) {
                content(jump)
            }
            .padding(.horizontal, .spaceL)
            .padding(.bottom, .space2XL)
            .frame(maxWidth: maxWidth)
            .frame(maxWidth: .infinity)
        }
        .refreshable { await refresh() }
        .scrollPosition($position)
        .onScrollGeometryChange(for: CGFloat.self) {
            $0.contentOffset.y + $0.contentInsets.top
        } action: { _, value in
            state.offset = value
        }
        .background(.plainBackground)
        .onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .global).minY
        } action: {
            state.move(pageTop: $0)
        }
        .revealBar(isShown: state.showsBar, height: $state.headerHeight) {
            bar(jump, state.showsBar)
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
        }
        .environment(state)
        .onChange(of: chapters, initial: true) {
            state.order = chapters.map(AnyHashable.init)
            state.refresh()
        }
        .onChange(of: state.headerHeight) { state.refresh() }
        .onChange(of: state.current) { _, chapter in
            onChapter(chapter?.base as? Chapter)
        }
    }

    private func jump(to chapter: Chapter) {
        guard let target = state.target(of: chapter) else { return }
        withAnimation(reduceMotion ? nil : .snappy) {
            position.scrollTo(y: target)
        }
    }
}

extension CGFloat {
    fileprivate static let revealBarEstimate: CGFloat = 112
}

private struct RevealHero: ViewModifier {
    @Environment(RevealPageState.self) private var state

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .global).maxY
        } action: {
            state.move(heroBottom: $0)
        }
    }
}

private struct RevealChapter: ViewModifier {
    @Environment(RevealPageState.self) private var state
    let chapter: AnyHashable

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat.self) {
            $0.frame(in: .global).minY
        } action: {
            state.move(chapter: chapter, top: $0)
        }
    }
}

extension View {
    public func revealHero() -> some View {
        modifier(RevealHero())
    }

    @ViewBuilder public func revealChapter<Chapter: Hashable>(
        _ chapter: Chapter, isActive: Bool = true
    ) -> some View {
        if isActive {
            modifier(RevealChapter(chapter: AnyHashable(chapter)))
        } else {
            self
        }
    }
}
