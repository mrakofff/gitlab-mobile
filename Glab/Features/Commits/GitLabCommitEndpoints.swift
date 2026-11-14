import Foundation

nonisolated enum GitLabCommitEndpoints {
    static func commits(
        projectID: Int,
        refName: String?,
        path: String? = nil,
        all: Bool = false
    ) -> GitLabAPIRequest<[GitLabCommit]> {
        var query = [
            URLQueryItem(
                name: "per_page",
                value: "20"
            ),
        ]
        if
            let refName =
                refName?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            !refName.isEmpty
        {
            query.append(
                URLQueryItem(
                    name: "ref_name",
                    value: refName
                )
            )
        }
        if
            let path =
                path?.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
            !path.isEmpty
        {
            query.append(
                URLQueryItem(
                    name: "path",
                    value: path
                )
            )
        }
        if all {
            query.append(
                URLQueryItem(
                    name: "all",
                    value: "true"
                )
            )
        }

        return .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "commits",
            ],
            query: query
        )
    }

    static func diff(
        projectID: Int,
        commitSHA: String
    ) -> GitLabAPIRequest<[GitLabDiffFile]> {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "repository",
                "commits",
                commitSHA,
                "diff",
            ]
        )
    }
}
