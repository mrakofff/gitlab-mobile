import Foundation

nonisolated enum GitLabInboxEndpoints {
    static let pageSize = 20

    static func mergeRequests(
        scope: String
    ) -> GitLabAPIRequest<[GitLabMergeRequest]> {
        .get(
            requires: .read,
            path: ["merge_requests"],
            query: workQuery(
                [
                    .init(name: "scope", value: scope),
                ]
            )
        )
    }

    static func issues(
        scope: String
    ) -> GitLabAPIRequest<[GitLabIssue]> {
        .get(
            requires: .read,
            path: ["issues"],
            query: workQuery(
                [
                    .init(name: "scope", value: scope),
                ]
            )
        )
    }

    static func mentionedTodos(
        perPage: Int = 100
    ) -> GitLabAPIRequest<[GitLabTodo]> {
        .get(
            requires: .read,
            path: ["todos"],
            query: [
                .init(name: "state", value: "pending"),
                .init(name: "action", value: "mentioned"),
                .init(
                    name: "per_page",
                    value: String(perPage)
                ),
            ]
        )
    }

    private static func workQuery(
        _ scopeItems: [URLQueryItem]
    ) -> [URLQueryItem] {
        scopeItems
            + [
                .init(name: "state", value: "opened"),
                .init(
                    name: "order_by",
                    value: "updated_at"
                ),
                .init(name: "sort", value: "desc"),
                .init(
                    name: "per_page",
                    value: String(pageSize)
                ),
            ]
    }
}
