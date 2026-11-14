import Foundation
import Observation

nonisolated struct GitLabHomePipeline:
    Identifiable,
    Equatable,
    Sendable
{
    let pipeline: GitLabPipeline
    let project: GitLabHomeProject

    var id: Int { pipeline.id }
    var updatedAt: Date? {
        pipeline.updatedAt ?? pipeline.createdAt
    }

    var route: GitLabPipelineRoute? {
        GitLabPipelineRoute(
            projectID: project.id,
            pipelineID: pipeline.id
        )
    }
}

nonisolated protocol GitLabHomePipelinesLoading:
    Sendable
{
    func loadProjects() async throws(
        GitLabSessionClientError
    ) -> [GitLabHomeProject]

    func loadPipelines(
        _ endpoint: GitLabAPIRequest<[GitLabPipeline]>
    ) async throws(GitLabSessionClientError)
        -> [GitLabPipeline]
}

nonisolated struct LiveGitLabHomePipelinesLoader:
    GitLabHomePipelinesLoading,
    Sendable
{
    private let client:
        any GitLabSessionRequestSending

    init(
        client: any GitLabSessionRequestSending
    ) {
        self.client = client
    }

    @concurrent
    func loadProjects() async throws(
        GitLabSessionClientError
    ) -> [GitLabHomeProject] {
        let endpoint: GitLabAPIRequest<
            [GitLabHomeProject]
        > = .get(
            requires: .read,
            path: ["projects"],
            query: [
                .init(
                    name: "membership",
                    value: "true"
                ),
                .init(
                    name: "order_by",
                    value: "last_activity_at"
                ),
                .init(
                    name: "sort",
                    value: "desc"
                ),
                .init(
                    name: "simple",
                    value: "true"
                ),
                .init(
                    name: "per_page",
                    value: "10"
                ),
            ]
        )
        return try await client.send(endpoint)
    }

    @concurrent
    func loadPipelines(
        _ endpoint: GitLabAPIRequest<[GitLabPipeline]>
    ) async throws(GitLabSessionClientError)
        -> [GitLabPipeline]
    {
        try await client.send(endpoint)
    }
}

@MainActor
@Observable
final class HomePipelinesModel {
    enum Status: Equatable {
        case idle
        case loading
        case loaded
        case failed
    }

    private(set) var status: Status = .idle
    private(set) var pipelines:
        [GitLabHomePipeline] = []
    private(set) var loadError:
        GitLabSessionClientError?

    @ObservationIgnored
    private let loader:
        any GitLabHomePipelinesLoading
    private let accountScope:
        GitLabPipelineAccountScope

    private nonisolated static let projectLimit =
        10
    private nonisolated static let
        maxConcurrentProjects = 4
    private nonisolated static let
        perProjectPipelineCount = 3

    init(
        loader: any GitLabHomePipelinesLoading,
        isAccountCurrent:
            @escaping @MainActor () -> Bool
    ) {
        self.loader = loader
        accountScope = GitLabPipelineAccountScope(
            isCurrent: isAccountCurrent
        )
    }

    var activePipelines: [GitLabHomePipeline] {
        pipelines.filter {
            $0.pipeline.status.isActivelyChanging
        }
    }

    var failedPipelines: [GitLabHomePipeline] {
        pipelines.filter {
            $0.pipeline.status.rawValue == "failed"
        }
    }

    var loaderDescription:
        any GitLabHomePipelinesLoading {
        loader
    }

    func loadIfNeeded() async {
        guard status == .idle else {
            return
        }
        await load()
    }

    func refresh() async {
        await load()
    }

    private func load() async {
        guard accountScope.check() else {
            return
        }

        status = .loading
        loadError = nil

        do {
            let projects = try await loader
                .loadProjects()
            let candidates = projects
                .filter {
                    GitLabPipelineEndpoints
                        .projectPipelines(
                            projectID: $0.id,
                            perPage: Self
                                .perProjectPipelineCount
                        ) != nil
                }
                .prefix(Self.projectLimit)

            let collected = try await Self.load(
                candidates: Array(candidates),
                loader: loader,
                accountScope: accountScope
            )

            guard accountScope.check() else {
                return
            }

            pipelines = collected
                .sorted { lhs, rhs in
                    let lhsTime =
                        lhs.updatedAt
                        ?? .distantPast
                    let rhsTime =
                        rhs.updatedAt
                        ?? .distantPast
                    if lhsTime != rhsTime {
                        return lhsTime > rhsTime
                    }
                    return lhs.id > rhs.id
                }
            status = .loaded
        } catch {
            guard
                accountScope.check(),
                !Task.isCancelled
            else {
                return
            }
            loadError =
                error as? GitLabSessionClientError
                ?? .api(.invalidResponse)
            status = .failed
        }
    }

    private nonisolated static func load(
        candidates: [GitLabHomeProject],
        loader: any GitLabHomePipelinesLoading,
        accountScope: GitLabPipelineAccountScope
    ) async throws -> [GitLabHomePipeline] {
        try await withThrowingTaskGroup(
            of: [GitLabHomePipeline].self,
            body: { (group: inout ThrowingTaskGroup<
                [GitLabHomePipeline],
                any Error
            >) -> [GitLabHomePipeline] in
            var nextIndex =
                candidates.startIndex
            var inFlight = 0
            var results:
                [GitLabHomePipeline] = []
            let maxConcurrent =
                HomePipelinesModel
                .maxConcurrentProjects
            let perProjectCount =
                HomePipelinesModel
                .perProjectPipelineCount

            func fill() {
                while inFlight < maxConcurrent,
                    nextIndex
                        < candidates.endIndex
                {
                    let project =
                        candidates[nextIndex]
                    guard
                        let endpoint =
                            GitLabPipelineEndpoints
                            .projectPipelines(
                                projectID:
                                    project.id,
                                perPage:
                                    perProjectCount
                            )
                    else {
                        nextIndex += 1
                        continue
                    }
                    inFlight += 1
                    nextIndex += 1
                    group.addTask {
                        guard
                            await accountScope
                            .check()
                        else {
                            throw
                                GitLabSessionClientError
                                .api(
                                    .cancelled
                                )
                        }
                        let fetched =
                            try await loader
                            .loadPipelines(
                                endpoint
                            )
                        return fetched
                            .filter {
                                $0.projectID
                                    == nil
                                    || $0
                                    .projectID
                                    == project
                                    .id
                            }
                            .map {
                                GitLabHomePipeline(
                                    pipeline: $0,
                                    project:
                                        project
                                )
                            }
                    }
                }
            }

            fill()
            for try await fetched in group {
                inFlight -= 1
                results.append(
                    contentsOf: fetched
                )
                fill()
            }
            return results
        })
    }
}
