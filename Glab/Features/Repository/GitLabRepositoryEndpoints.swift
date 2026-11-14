import Foundation

nonisolated enum GitLabRepositoryEndpoints {
    static let treePageSize = 100
    static let branchPageSize = 100
    static let searchPageSize = 20

    static func tree(
        projectID: Int,
        ref: String,
        path: String
    ) -> GitLabAPIRequest<
        [GitLabRepositoryEntry]
    > {
        var query = [
            URLQueryItem(
                name: "ref",
                value: ref
            ),
            URLQueryItem(
                name: "per_page",
                value: String(treePageSize)
            ),
        ]
        if !path.isEmpty {
            query.insert(
                URLQueryItem(
                    name: "path",
                    value: path
                ),
                at: 0
            )
        }

        return .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "tree",
            ],
            query: query
        )
    }

    static func branches(
        projectID: Int,
        search: String? = nil
    ) -> GitLabAPIRequest<
        [GitLabRepositoryBranch]
    > {
        var query = [
            URLQueryItem(
                name: "per_page",
                value: String(branchPageSize)
            ),
        ]
        if
            let search = search?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            !search.isEmpty
        {
            query.insert(
                URLQueryItem(
                    name: "search",
                    value: search
                ),
                at: 0
            )
        }

        return .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "branches",
            ],
            query: query
        )
    }

    static func branch(
        projectID: Int,
        name: String
    ) -> GitLabAPIRequest<GitLabRepositoryBranch> {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "branches",
                name,
            ]
        )
    }

    static func search(
        projectID: Int,
        ref: String,
        query search: String
    ) -> GitLabAPIRequest<
        [GitLabRepositorySearchResult]
    > {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "search",
            ],
            query: [
                URLQueryItem(
                    name: "scope",
                    value: "blobs"
                ),
                URLQueryItem(
                    name: "search",
                    value: search
                ),
                URLQueryItem(
                    name: "ref",
                    value: ref
                ),
                URLQueryItem(
                    name: "per_page",
                    value: String(searchPageSize)
                ),
            ]
        )
    }

    static func rawFile(
        at route: GitLabRepositoryFileRoute
    ) -> GitLabRawAPIRequest {
        .get(
            path: [
                "projects",
                String(route.projectID),
                "repository",
                "files",
                route.path,
                "raw",
            ],
            query: [
                URLQueryItem(
                    name: "ref",
                    value: route.ref
                ),
            ]
        )
    }

    static func deleteFile(
        projectID: Int,
        ref: String,
        path: String,
        commitMessage: String
    ) -> GitLabAPIRequest<
        GitLabRepositoryFileCommitResponse
    > {
        .delete(
            requires: .write,
            path: [
                "projects",
                String(projectID),
                "repository",
                "files",
                path,
            ],
            query: [
                URLQueryItem(
                    name: "ref",
                    value: ref
                ),
                URLQueryItem(
                    name: "commit_message",
                    value: commitMessage
                ),
            ]
        )
    }
}

nonisolated extension GitLabRepositoryEndpoints {
    static func blame(
        projectID: Int,
        ref: String,
        path: String
    ) -> GitLabAPIRequest<[GitLabBlameRange]> {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "blame",
            ],
            query: [
                URLQueryItem(
                    name: "filepath",
                    value: path
                ),
                URLQueryItem(
                    name: "ref",
                    value: ref
                ),
            ]
        )
    }

    static func tags(
        projectID: Int
    ) -> GitLabAPIRequest<[GitLabRepositoryTag]> {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "tags",
            ],
            query: [
                URLQueryItem(
                    name: "per_page",
                    value: String(treePageSize)
                ),
            ]
        )
    }
}
