import SwiftUI

struct GitLabProjectMergeRequestsView: View {
    let project: GitLabProject
    let loader:
        any GitLabMergeRequestLoading
            & GitLabMergeRequestApprovalLoading
            & GitLabMergeRequestDiffLoading
            & GitLabMergeRequestDiffSummaryLoading
    let approvalService:
        any GitLabMergeRequestApprovalServing
    let mergeService:
        any GitLabMergeRequestMergeServing
    let pipelineLoader:
        any GitLabPipelineLoading
    let discussionLoader:
        any GitLabDiscussionLoading
    let discussionMutator:
        any GitLabDiscussionMutating
    let reactionService:
        any GitLabEmojiReactionLoading
            & GitLabEmojiReactionMutating
    let editService:
        any GitLabResourceEditing
    let apiAccess: GitLabAPIAccess
    let branchLoader: any GitLabRepositoryBrowsing
    let creationService:
        any GitLabMergeRequestCreationServing
    let accountID: GitLabAccountID
    let appSession: AppSession
    let onResourceEdited:
        (GitLabResourceEditResult) -> Void

    @State private var model:
        ProjectMergeRequestsModel
    @State private var createdMergeRequest:
        GitLabMergeRequestRoute?

    init(
        project: GitLabProject,
        loader:
            any GitLabMergeRequestLoading
                & GitLabMergeRequestApprovalLoading
                & GitLabMergeRequestDiffLoading
                & GitLabMergeRequestDiffSummaryLoading,
        approvalService:
            any GitLabMergeRequestApprovalServing,
        mergeService:
            any GitLabMergeRequestMergeServing,
        pipelineLoader:
            any GitLabPipelineLoading,
        discussionLoader:
            any GitLabDiscussionLoading,
        discussionMutator:
            any GitLabDiscussionMutating,
        reactionService:
            any GitLabEmojiReactionLoading
                & GitLabEmojiReactionMutating,
        editService:
            any GitLabResourceEditing,
        apiAccess: GitLabAPIAccess,
        branchLoader: any GitLabRepositoryBrowsing,
        creationService:
            any GitLabMergeRequestCreationServing,
        accountID: GitLabAccountID,
        appSession: AppSession,
        onResourceEdited:
            @escaping (
                GitLabResourceEditResult
            ) -> Void
    ) {
        self.project = project
        self.loader = loader
        self.approvalService =
            approvalService
        self.mergeService =
            mergeService
        self.pipelineLoader =
            pipelineLoader
        self.discussionLoader =
            discussionLoader
        self.discussionMutator =
            discussionMutator
        self.reactionService =
            reactionService
        self.editService = editService
        self.apiAccess = apiAccess
        self.branchLoader = branchLoader
        self.creationService =
            creationService
        self.accountID = accountID
        self.appSession = appSession
        self.onResourceEdited =
            onResourceEdited
        _model = State(
            initialValue:
                ProjectMergeRequestsModel(
                    projectID: project.id,
                    loader: loader
                )
        )
    }

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            statePicker(model: $model)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 12)

            Divider()

            mergeRequestList
        }
        .gitLabProjectMergeRequestCreation(
            project: project,
            apiAccess: apiAccess,
            branchLoader: branchLoader,
            creationService: creationService,
            accountID: accountID,
            appSession: appSession,
            onCreated: didCreate
        )
        .navigationDestination(
            item: $createdMergeRequest
        ) { route in
            GitLabMergeRequestDetailView(
                route: route,
                loader: loader,
                approvalService:
                    approvalService,
                mergeService: mergeService,
                pipelineLoader:
                    pipelineLoader,
                discussionLoader:
                    discussionLoader,
                discussionMutator:
                    discussionMutator,
                reactionService:
                    reactionService,
                editService: editService,
                accountID: accountID,
                appSession: appSession,
                onResourceEdited:
                    reconcileEditedResource
            )
        }
    }

    private func didCreate(
        _ mergeRequest: GitLabMergeRequest
    ) {
        model.reconcileCreatedMergeRequest(
            mergeRequest
        )
        createdMergeRequest =
            mergeRequest.route
    }

    private var mergeRequestList: some View {
        GitLabMergeRequestListView(
            model: model.activeModel,
            configuration:
                GitLabMergeRequestListConfiguration(
                    title: "Merge Requests",
                    loadingMessage:
                        "Loading \(model.selectedState.title.lowercased()) merge requests",
                    emptyTitle:
                        "No \(model.selectedState.title.lowercased()) merge requests",
                    emptyMessage:
                        emptyMessage,
                    emptyGitLabIcon:
                        model.selectedState
                            .gitLabIcon,
                    accessibilityIdentifier:
                        "projectMergeRequests.list"
                ),
            loader: loader,
            approvalService:
                approvalService,
            mergeService:
                mergeService,
            pipelineLoader:
                pipelineLoader,
            discussionLoader:
                discussionLoader,
            discussionMutator:
                discussionMutator,
            reactionService:
                reactionService,
            editService: editService,
            accountID: accountID,
            appSession: appSession,
            onResourceEdited:
                reconcileEditedResource
        )
    }

    private func statePicker(
        model:
            Bindable<ProjectMergeRequestsModel>
    ) -> some View {
        GitLabLifecycleStatePicker(
            states:
                GitLabProjectMergeRequestState
                    .allCases,
            selection: model.selectedState,
            title: \.title,
            gitLabIcon: \.gitLabIcon,
            accessibilityValue: \.rawValue,
            accessibilityIdentifier:
                "projectMergeRequests.state"
        )
    }

    private var emptyMessage: String {
        switch model.selectedState {
        case .opened:
            "Open merge requests in \(project.name) will appear here."
        case .merged:
            "Merged merge requests in \(project.name) will appear here."
        case .closed:
            "Closed merge requests in \(project.name) will appear here."
        }
    }

    private func reconcileEditedResource(
        _ result: GitLabResourceEditResult
    ) {
        if
            case let .mergeRequest(
                mergeRequest
            ) = result,
            mergeRequest.projectID
                == project.id
        {
            model.reconcileEditedMergeRequest(
                mergeRequest
            )
        }
        onResourceEdited(result)
    }
}
