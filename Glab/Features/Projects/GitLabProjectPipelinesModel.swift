import Foundation
import Observation

@MainActor
@Observable
final class GitLabProjectPipelinesModel {
    let accountID: GitLabAccountID
    let projectID: Int
    let pipelines:
        GitLabPaginatedResourceModel<
            GitLabPipeline,
            Int
        >

    @ObservationIgnored
    private let accountScope:
        GitLabPipelineAccountScope

    init(
        accountID: GitLabAccountID,
        projectID: Int,
        loader: any GitLabProjectOverviewLoading,
        isAccountCurrent:
            @escaping @MainActor () -> Bool
    ) {
        let accountScope =
            GitLabPipelineAccountScope(
                isCurrent: isAccountCurrent
            )
        self.accountID = accountID
        self.projectID = projectID
        self.accountScope = accountScope
        pipelines = GitLabPaginatedResourceModel(
            loadPage: {
                nextPageURL async throws(
                    GitLabSessionClientError
                ) in
                guard
                    await accountScope.check()
                else {
                    throw .api(.cancelled)
                }
                let page =
                    try await loader
                    .loadPipelinesPage(
                        projectID: projectID,
                        after: nextPageURL
                    )
                guard
                    await accountScope.check()
                else {
                    throw .api(.cancelled)
                }
                return page
            },
            identity: \.id,
            searchValues: {
                [
                    $0.name ?? "",
                    $0.ref,
                    $0.sha,
                    String($0.iid ?? $0.id),
                    $0.status.title,
                ]
            }
        )
    }

    var authenticationFailure:
        GitLabSessionClientError?
    {
        pipelines.authenticationFailure
    }

    func loadIfNeeded() async {
        guard accountScope.check() else {
            return
        }
        await pipelines.loadIfNeeded()
    }

    func refresh() async {
        guard accountScope.check() else {
            return
        }
        await pipelines.refresh()
    }

    func loadNextPageIfNeeded(
        after pipeline: GitLabPipeline
    ) async {
        guard accountScope.check() else {
            return
        }
        await pipelines.loadNextPageIfNeeded(
            after: pipeline
        )
    }

    func retryNextPage() async {
        guard accountScope.check() else {
            return
        }
        await pipelines.retryNextPage()
    }
}
