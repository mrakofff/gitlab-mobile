import Foundation
import Observation

@MainActor
@Observable
final class GitLabMergeRequestCreationModel {
    var title = ""
    var description = ""
    var sourceBranch = ""
    var targetBranch = ""
    var removeSourceBranch = false
    var squash = false
    private(set) var isSubmitting = false
    private(set) var failure: Error?

    let branchesModel:
        GitLabRepositoryBranchesModel

    @ObservationIgnored
    private let projectID: Int
    @ObservationIgnored
    private let service:
        any GitLabMergeRequestCreationServing
    @ObservationIgnored
    private let isAccountCurrent:
        () -> Bool
    @ObservationIgnored
    private let onCreated:
        (GitLabMergeRequest) -> Void

    var isValid: Bool {
        !title.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty
            && !sourceBranch.isEmpty
            && !targetBranch.isEmpty
            && sourceBranch != targetBranch
    }

    var failureText: String? {
        guard
            let sessionError =
                failure as? GitLabSessionClientError
        else {
            return failure?.localizedDescription
        }
        return GitLabRecoveryPresentation(
            error: sessionError
        ).message
    }

    init(
        projectID: Int,
        projectDefaultBranch: String?,
        branchLoader: any GitLabRepositoryBrowsing,
        service:
            any GitLabMergeRequestCreationServing,
        isAccountCurrent:
            @escaping () -> Bool,
        onCreated:
            @escaping (GitLabMergeRequest) -> Void
    ) {
        self.projectID = projectID
        self.sourceBranch =
            projectDefaultBranch ?? ""
        self.targetBranch =
            projectDefaultBranch ?? "main"
        self.branchesModel =
            GitLabRepositoryBranchesModel(
                projectID: projectID,
                defaultBranchName:
                    projectDefaultBranch,
                loader: branchLoader
            )
        self.service = service
        self.isAccountCurrent =
            isAccountCurrent
        self.onCreated = onCreated
    }

    func submit() async {
        guard isValid, !isSubmitting else {
            return
        }
        isSubmitting = true
        failure = nil
        defer { isSubmitting = false }
        let input = GitLabMergeRequestCreationInput(
            title: title,
            description: description,
            sourceBranch: sourceBranch,
            targetBranch: targetBranch,
            removeSourceBranch:
                removeSourceBranch,
            squash: squash
        )
        do {
            let mergeRequest =
                try await service.createMergeRequest(
                    projectID: projectID,
                    input: input
                )
            if isAccountCurrent() {
                onCreated(mergeRequest)
            }
        } catch {
            self.failure = error
        }
    }
}
