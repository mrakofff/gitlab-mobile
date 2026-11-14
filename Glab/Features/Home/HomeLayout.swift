import Foundation

nonisolated enum HomeModule:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Sendable
{
    case activePipelines
    case failedPipelines
    case recentPipelines
    case recentProjects
    case assignedMergeRequests
    case myIssues
    case todos
    case starredProjects

    var title: String {
        switch self {
        case .activePipelines:
            "Active pipelines"
        case .failedPipelines:
            "Failed pipelines"
        case .recentPipelines:
            "Recent pipelines"
        case .recentProjects:
            "Recent projects"
        case .assignedMergeRequests:
            "Assigned merge requests"
        case .myIssues:
            "My issues"
        case .todos:
            "Todos"
        case .starredProjects:
            "Starred projects"
        }
    }

    var systemImage: String {
        switch self {
        case .activePipelines:
            "chart.line.uptrend.xyaxis"
        case .failedPipelines:
            "xmark.octagon.fill"
        case .recentPipelines:
            "clock.arrow.circlepath"
        case .recentProjects:
            "folder.fill"
        case .assignedMergeRequests:
            "arrow.triangle.branch"
        case .myIssues:
            "exclamationmark.circle.fill"
        case .todos:
            "checklist"
        case .starredProjects:
            "star.fill"
        }
    }
}

nonisolated enum HomeLayoutPreset:
    String,
    CaseIterable,
    Codable,
    Equatable,
    Sendable
{
    case developer
    case reviewer
    case lead

    var title: String {
        switch self {
        case .developer:
            "Developer"
        case .reviewer:
            "Reviewer"
        case .lead:
            "Lead / DevOps"
        }
    }

    var layout: HomeLayout {
        switch self {
        case .developer:
            HomeLayout(
                shown: [
                    .activePipelines,
                    .recentProjects,
                    .failedPipelines,
                    .recentPipelines,
                    .starredProjects,
                ],
                preset: self
            )
        case .reviewer:
            HomeLayout(
                shown: [
                    .assignedMergeRequests,
                    .activePipelines,
                    .failedPipelines,
                    .recentPipelines,
                ],
                preset: self
            )
        case .lead:
            HomeLayout(
                shown: [
                    .activePipelines,
                    .assignedMergeRequests,
                    .myIssues,
                    .recentProjects,
                ],
                preset: self
            )
        }
    }
}

nonisolated struct HomeLayout:
    Codable,
    Equatable,
    Sendable
{
    var shown: [HomeModule]
    var hidden: [HomeModule]
    var preset: HomeLayoutPreset?

    init(
        shown: [HomeModule],
        hidden: [HomeModule] = [],
        preset: HomeLayoutPreset? = nil
    ) {
        self.shown = shown
        self.hidden = hidden
        self.preset = preset
    }

    /// Layout used when nothing has been customized yet.
    static let initial =
        HomeLayoutPreset.developer.layout

    /// Rebuilds hidden so every module appears exactly once.
    func normalized() -> HomeLayout {
        var shown = shown
        var seen: Set<HomeModule> = []
        shown.removeAll {
            !seen.insert($0).inserted
        }
        var hidden = hidden.filter {
            !seen.contains($0)
        }
        for module in HomeModule.allCases
        where !seen.contains(module)
            && !hidden.contains(module)
        {
            hidden.append(module)
        }
        var layout = self
        layout.shown = shown
        layout.hidden = hidden
        return layout
    }
}

@MainActor
final class HomeLayoutStore {
    private let defaults: UserDefaults
    private let storageKey: String

    init(
        accountID: GitLabAccountID,
        defaults: UserDefaults = .standard
    ) {
        self.defaults = defaults
        storageKey = "homeLayout.\(accountID)"
    }

    func load() -> HomeLayout {
        guard
            let data = defaults.data(
                forKey: storageKey
            ),
            let layout = try? JSONDecoder()
            .decode(HomeLayout.self, from: data)
        else {
            return .initial
        }
        return layout.normalized()
    }

    func save(_ layout: HomeLayout) {
        guard
            let data = try? JSONEncoder().encode(
                layout.normalized()
            )
        else {
            return
        }
        defaults.set(data, forKey: storageKey)
    }
}

@MainActor
@Observable
final class HomeLayoutModel {
    private(set) var layout: HomeLayout

    private let store: HomeLayoutStore

    init(store: HomeLayoutStore) {
        self.store = store
        layout = store.load()
    }

    convenience init(
        accountID: GitLabAccountID,
        defaults: UserDefaults = .standard
    ) {
        self.init(
            store: HomeLayoutStore(
                accountID: accountID,
                defaults: defaults
            )
        )
    }

    func save(_ layout: HomeLayout) {
        self.layout = layout.normalized()
        store.save(self.layout)
    }

    func reset() {
        layout = store.load()
    }
}
