import Foundation

nonisolated protocol GitLabMergeRequestCreationServing:
    Sendable
{
    func createMergeRequest(
        projectID: Int,
        input: GitLabMergeRequestCreationInput
    ) async throws(
        GitLabSessionClientError
    ) -> GitLabMergeRequest

    func invalidateAffectedReads(
        projectID: Int
    ) async
}

nonisolated struct LiveGitLabMergeRequestCreationService:
    GitLabMergeRequestCreationServing,
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

    func createMergeRequest(
        projectID: Int,
        input: GitLabMergeRequestCreationInput
    ) async throws(
        GitLabSessionClientError
    ) -> GitLabMergeRequest {
        do {
            let endpoint:
                GitLabAPIRequest<GitLabMergeRequest>
            do {
                endpoint =
                    try GitLabMergeRequestCreationEndpoints
                        .create(
                            projectID: projectID,
                            input: input
                        )
            } catch {
                throw GitLabSessionClientError
                    .api(.invalidResponse)
            }
            return try await client.send(endpoint)
        } catch {
            let sessionError =
                error as? GitLabSessionClientError
                ?? .api(.transport)
            if
                sessionError
                    .mutationDeliveryCertainty
                    == .deliveryUnknown
            {
                await invalidateAffectedReads(
                    projectID: projectID
                )
            }
            throw sessionError
        }
    }

    func invalidateAffectedReads(
        projectID: Int
    ) async {
        // The fresh merge request is opened right
        // after creation; list and dashboard reads
        // must not return stale caches without it.
        for state
            in GitLabProjectMergeRequestState
                .allCases {
            await client
                .invalidateCachedResponse(
                    GitLabMergeRequestEndpoints
                        .projectMergeRequests(
                            projectID: projectID,
                            state: state
                        )
                )
        }
        for endpoint in [
            HomeDashboardEndpoints
                .assignedMergeRequests,
            HomeDashboardEndpoints
                .createdMergeRequests,
            HomeDashboardEndpoints
                .reviewRequests,
        ] {
            await client
                .invalidateCachedResponse(
                    endpoint
                )
        }
        await client.invalidateCachedResponse(
            GitLabProjectEndpoints
                .projects(for: .recent)
        )
    }
}
