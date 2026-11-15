import Foundation

nonisolated enum GitLabInboxFilter:
    String,
    CaseIterable,
    Equatable,
    Hashable,
    Sendable
{
    case all
    case assigned
    case mentioned
    case reviewRequested
    case buildFailed

    var title: String {
        switch self {
        case .all:
            "All"
        case .assigned:
            "Assigned"
        case .mentioned:
            "Mentioned"
        case .reviewRequested:
            "Review requested"
        case .buildFailed:
            "Build failed"
        }
    }

    var gitLabIcon: GitLabIcon {
        switch self {
        case .all:
            .todoAdd
        case .assigned:
            .mergeRequestOpen
        case .mentioned:
            .group
        case .reviewRequested:
            .todoDone
        case .buildFailed:
            .pipelineFailed
        }
    }

    var emptyTitle: String {
        switch self {
        case .all:
            "Nothing here yet"
        case .assigned:
            "No assigned work"
        case .mentioned:
            "No mentions"
        case .reviewRequested:
            "No review requests"
        case .buildFailed:
            "No failed builds"
        }
    }

    var emptyMessage: String {
        switch self {
        case .all:
            "Your open merge requests and issues will appear here."
        case .assigned:
            "Merge requests and issues assigned to you will appear here."
        case .mentioned:
            "Work items where you were mentioned will appear here."
        case .reviewRequested:
            "Merge requests awaiting your review will appear here."
        case .buildFailed:
            "Open merge requests with a failed last pipeline will appear here."
        }
    }
}

nonisolated enum GitLabInboxItemKind:
    Equatable,
    Hashable,
    Sendable
{
    case mergeRequest(GitLabMergeRequestRoute)
    case issue(GitLabIssueRoute)
}

nonisolated struct GitLabInboxItem:
    Identifiable,
    Equatable,
    Sendable
{
    let kind: GitLabInboxItemKind
    let projectID: Int
    let iid: Int
    let title: String
    let detail: String?
    let state: String
    let isDraft: Bool
    let authorUsername: String?
    let labels: [String]
    let updatedAt: Date?
    let hasFailedPipeline: Bool

    var id: GitLabInboxItemKind { kind }

    var isMergeRequest: Bool {
        if case .mergeRequest = kind {
            return true
        }
        return false
    }

    var nativeRoute: GitLabNativeRoute {
        switch kind {
        case let .mergeRequest(route):
            .mergeRequest(route)
        case let .issue(route):
            .issue(route)
        }
    }

    var reference: String {
        switch kind {
        case .mergeRequest:
            "!\(iid)"
        case .issue:
            "#\(iid)"
        }
    }

    var stateTitle: String {
        state.isEmpty
            ? "Unknown"
            : state.capitalized
    }
}

nonisolated extension GitLabInboxItem {
    init(
        mergeRequest: GitLabMergeRequest
    ) {
        kind = .mergeRequest(
            mergeRequest.route
        )
        projectID = mergeRequest.projectID
        iid = mergeRequest.iid
        title = mergeRequest.title
        detail = mergeRequest.references.short
        state = mergeRequest.state
        isDraft = mergeRequest.isDraft
        authorUsername =
            mergeRequest.author.username
        labels = mergeRequest.labels
        updatedAt = mergeRequest.updatedAt
        hasFailedPipeline =
            mergeRequest.headPipeline?
            .status == "failed"
    }

    init(issue: GitLabIssue) {
        kind = .issue(issue.route)
        projectID = issue.projectID
        iid = issue.iid
        title = issue.title
        detail = issue.references.short
        state = issue.state
        isDraft = false
        authorUsername = issue.author.username
        labels = issue.labels
        updatedAt = issue.updatedAt
        hasFailedPipeline = false
    }

    init?(todo: GitLabTodo) {
        switch todo.targetType {
        case .mergeRequest:
            guard
                case let .mergeRequest(route) =
                todo.nativeRoute
            else {
                return nil
            }
            kind = .mergeRequest(route)
        case .issue:
            guard
                case let .issue(route) =
                todo.nativeRoute
            else {
                return nil
            }
            kind = .issue(route)
        case
            .commit,
            .epic,
            .design,
            .alert,
            .project,
            .namespace,
            .vulnerability,
            .wikiPage,
            .unknown:
            return nil
        }

        projectID = todo.target?.projectID
            ?? todo.project?.id ?? 0
        iid = todo.target?.iid ?? 0
        title = todo.title
        detail = nil
        state = todo.target?.state ?? ""
        isDraft = false
        authorUsername = todo.author?.username
        labels = []
        updatedAt = todo.updatedAt
        hasFailedPipeline = false
    }

    static func mergedSortedByUpdatedAt(
        _ groups: [[GitLabInboxItem]]
    ) -> [GitLabInboxItem] {
        var seen = Set<GitLabInboxItemKind>()
        var result: [GitLabInboxItem] = []
        for item in groups.joined()
        where seen.insert(item.id).inserted {
            result.append(item)
        }
        return result.sorted { lhs, rhs in
            guard
                let lhsDate = lhs.updatedAt
            else {
                return false
            }
            guard
                let rhsDate = rhs.updatedAt
            else {
                return true
            }
            return lhsDate > rhsDate
        }
    }

    static func mentionedItems(
        client: any GitLabSessionRequestSending
    ) async throws(GitLabSessionClientError)
        -> [GitLabInboxItem]
    {
        let todos = try await client.send(
            GitLabInboxEndpoints.mentionedTodos()
        )
        return todos.compactMap(GitLabInboxItem.init)
    }

    static func reviewRequestedItems(
        client: any GitLabSessionRequestSending
    ) async throws(GitLabSessionClientError)
        -> [GitLabInboxItem]
    {
        let mergeRequests = try await client.send(
            GitLabInboxEndpoints.mergeRequests(
                scope: "reviews_for_me"
            )
        )
        return mergeRequests
            .map(GitLabInboxItem.init)
    }
}
