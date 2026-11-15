import Foundation

nonisolated enum
    GitLabMergeRequestCreationEndpointError:
    Error,
    Equatable,
    Sendable
{
    case emptyTitle
    case sameSourceAndTarget
}

nonisolated struct GitLabMergeRequestCreationInput:
    Equatable,
    Sendable
{
    var title: String
    var description: String
    var sourceBranch: String
    var targetBranch: String
    var removeSourceBranch: Bool
    var squash: Bool
}

nonisolated enum GitLabMergeRequestCreationEndpoints {
    static func create(
        projectID: Int,
        input: GitLabMergeRequestCreationInput
    ) throws -> GitLabAPIRequest<GitLabMergeRequest> {
        let trimmedTitle =
            input.title
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        guard !trimmedTitle.isEmpty else {
            throw GitLabMergeRequestCreationEndpointError
                .emptyTitle
        }
        guard
            input.sourceBranch
                != input.targetBranch
        else {
            throw GitLabMergeRequestCreationEndpointError
                .sameSourceAndTarget
        }
        return try .post(
            requires: .write,
            path: [
                "projects",
                String(projectID),
                "merge_requests",
            ],
            body: GitLabMergeRequestCreationBody(
                title: trimmedTitle,
                description: emptyToNil(
                    input.description
                ),
                sourceBranch:
                    input.sourceBranch,
                targetBranch:
                    input.targetBranch,
                removeSourceBranch:
                    input.removeSourceBranch
                    ? true : nil,
                squash: input.squash
                    ? true : nil
            )
        )
    }

    private static func emptyToNil(
        _ value: String
    ) -> String? {
        let trimmed = value
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        return trimmed.isEmpty ? nil : trimmed
    }
}

private nonisolated struct
    GitLabMergeRequestCreationBody:
    Encodable,
    Sendable
{
    let title: String
    let description: String?
    let sourceBranch: String
    let targetBranch: String
    let removeSourceBranch: Bool?
    let squash: Bool?

    private enum CodingKeys: String, CodingKey {
        case title
        case description
        case sourceBranch = "source_branch"
        case targetBranch = "target_branch"
        case removeSourceBranch =
            "remove_source_branch"
        case squash
    }
}
