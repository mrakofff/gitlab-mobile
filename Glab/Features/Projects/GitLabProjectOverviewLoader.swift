import Foundation

nonisolated struct GitLabProjectLanguage:
    Equatable,
    Identifiable,
    Sendable
{
    let name: String
    let percentage: Double

    var id: String { name }
}

nonisolated struct GitLabProjectLanguages:
    Decodable,
    Equatable,
    Sendable
{
    let items: [GitLabProjectLanguage]

    init(items: [GitLabProjectLanguage]) {
        self.items = items
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(
            keyedBy: DynamicKey.self
        )
        items = container.allKeys
            .compactMap { key in
                guard
                    let value = try? container.decode(
                        Double.self,
                        forKey: key
                    ),
                    value.isFinite,
                    value > 0
                else {
                    return nil
                }
                return GitLabProjectLanguage(
                    name: key.stringValue,
                    percentage: value
                )
            }
            .sorted {
                $0.percentage == $1.percentage
                    ? $0.name < $1.name
                    : $0.percentage > $1.percentage
            }
    }

    private struct DynamicKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil

        init?(stringValue: String) {
            self.stringValue = stringValue
        }

        init?(intValue: Int) {
            nil
        }
    }
}

private nonisolated struct GitLabProjectCountedItem:
    Decodable,
    Sendable
{}

nonisolated enum GitLabProjectOverviewEndpoints {
    static func languages(
        projectID: Int
    ) -> GitLabAPIRequest<GitLabProjectLanguages> {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "languages",
            ]
        )
    }

    fileprivate static func openMergeRequests(
        projectID: Int
    ) -> GitLabAPIRequest<
        [GitLabProjectCountedItem]
    > {
        .get(
            requires: .read,
            path: [
                "projects",
                String(projectID),
                "merge_requests",
            ],
            query: [
                .init(
                    name: "state",
                    value: "opened"
                ),
                .init(
                    name: "per_page",
                    value: "1"
                ),
            ]
        )
    }
}

nonisolated protocol GitLabProjectOverviewLoading:
    Sendable
{
    func loadLanguages(
        projectID: Int
    ) async throws(GitLabSessionClientError)
        -> [GitLabProjectLanguage]

    func loadOpenMergeRequestCount(
        projectID: Int
    ) async throws(GitLabSessionClientError)
        -> Int?

    func loadLatestPipeline(
        projectID: Int
    ) async throws(GitLabSessionClientError)
        -> GitLabPipeline?

    func loadPipelinesPage(
        projectID: Int,
        after nextPageURL: URL?
    ) async throws(GitLabSessionClientError)
        -> GitLabResourcePage<GitLabPipeline>
}

nonisolated struct LiveGitLabProjectOverviewLoader:
    GitLabProjectOverviewLoading,
    Sendable
{
    private let client:
        any GitLabPaginatedSessionRequestSending

    init(
        client:
            any GitLabPaginatedSessionRequestSending
    ) {
        self.client = client
    }

    @concurrent
    func loadLanguages(
        projectID: Int
    ) async throws(GitLabSessionClientError)
        -> [GitLabProjectLanguage]
    {
        try await client.send(
            GitLabProjectOverviewEndpoints.languages(
                projectID: projectID
            )
        ).items
    }

    @concurrent
    func loadOpenMergeRequestCount(
        projectID: Int
    ) async throws(GitLabSessionClientError)
        -> Int?
    {
        let response = try await client.sendPage(
            .initial(
                GitLabProjectOverviewEndpoints
                    .openMergeRequests(
                        projectID: projectID
                    )
            )
        )
        if let total = response.metadata.totalCount {
            return total
        }
        return response.metadata.nextPageURL == nil
            ? response.value.count
            : nil
    }

    @concurrent
    func loadLatestPipeline(
        projectID: Int
    ) async throws(GitLabSessionClientError)
        -> GitLabPipeline?
    {
        guard
            let endpoint =
                GitLabPipelineEndpoints
                .projectPipelines(
                    projectID: projectID,
                    perPage: 1
                )
        else {
            throw .api(.invalidResponse)
        }
        return try await client.send(endpoint).first
    }

    @concurrent
    func loadPipelinesPage(
        projectID: Int,
        after nextPageURL: URL?
    ) async throws(GitLabSessionClientError)
        -> GitLabResourcePage<GitLabPipeline>
    {
        let request:
            GitLabAPIPageRequest<[GitLabPipeline]>
        if let nextPageURL {
            request = .next(nextPageURL)
        } else {
            guard
                let endpoint =
                    GitLabPipelineEndpoints
                    .projectPipelines(
                        projectID: projectID
                    )
            else {
                throw .api(.invalidResponse)
            }
            request = .initial(endpoint)
        }

        let response = try await client.sendPage(
            request
        )
        guard
            response.value.allSatisfy({
                $0.projectID == nil
                    || $0.projectID == projectID
            })
        else {
            throw .api(.invalidResponse)
        }
        return GitLabResourcePage(
            items: response.value,
            nextPageURL:
                response.metadata.nextPageURL,
            totalCount:
                response.metadata.totalCount
        )
    }
}
