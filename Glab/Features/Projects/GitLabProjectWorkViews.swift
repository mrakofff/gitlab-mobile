import SwiftUI

// MARK: - Work section

struct GitLabProjectWorkSection: View {
    let project: GitLabProject
    let overviewModel: GitLabProjectOverviewModel?
    let repositoryLoader: any GitLabRepositoryBrowsing
    let issueLoader: any GitLabIssueLoading
    let mergeRequestLoader:
        any GitLabMergeRequestLoading
            & GitLabMergeRequestApprovalLoading
            & GitLabMergeRequestDiffLoading
            & GitLabMergeRequestDiffSummaryLoading
    let mergeRequestApprovalService:
        any GitLabMergeRequestApprovalServing
    let mergeRequestMergeService:
        any GitLabMergeRequestMergeServing
    let pipelineLoader: any GitLabPipelineLoading
    let discussionLoader: any GitLabDiscussionLoading
    let discussionMutator: any
        GitLabDiscussionMutating
    let reactionService:
        any GitLabEmojiReactionLoading
            & GitLabEmojiReactionMutating
    let editService: any GitLabResourceEditing
    let issueStatusService: any
        GitLabIssueStatusServing
    let issueCreationService: any
        GitLabIssueCreationServing
    let mergeRequestCreationService:
        any GitLabMergeRequestCreationServing
    let overviewLoader: any
        GitLabProjectOverviewLoading
    let apiAccess: GitLabAPIAccess
    let accountID: GitLabAccountID
    let appSession: AppSession
    let onResourceEdited:
        (GitLabResourceEditResult) -> Void
    let isAccountCurrent:
        @MainActor () -> Bool

    var body: some View {
        GitLabDetailSection(title: "Work") {
            VStack(spacing: 2) {
                if
                    project
                    .mergeRequestsAccessLevel?
                    .isDisabled == true
                {
                    GitLabProjectWorkRow(
                        title: "Merge requests",
                        systemImage: "arrow.triangle.pull",
                        tint: .pink,
                        value: "Off"
                    )
                    .opacity(0.6)
                } else {
                    NavigationLink {
                        GitLabProjectMergeRequestsView(
                            project: project,
                            loader: mergeRequestLoader,
                            approvalService:
                                mergeRequestApprovalService,
                            mergeService:
                                mergeRequestMergeService,
                            pipelineLoader:
                                pipelineLoader,
                            discussionLoader:
                                discussionLoader,
                            discussionMutator:
                                discussionMutator,
                            reactionService:
                                reactionService,
                            editService: editService,
                            apiAccess: apiAccess,
                            branchLoader:
                                repositoryLoader,
                            creationService:
                                mergeRequestCreationService,
                            accountID: accountID,
                            appSession: appSession,
                            onResourceEdited:
                                onResourceEdited
                        )
                    } label: {
                        GitLabProjectWorkRow(
                            title: "Merge requests",
                            systemImage:
                                "arrow.triangle.pull",
                            tint: .pink,
                            value:
                                openMergeRequestText
                        )
                    }
                    .accessibilityIdentifier(
                        "project.work.mergeRequests"
                    )
                }

                if
                    project.issuesAccessLevel?
                    .isDisabled == true
                {
                    GitLabProjectWorkRow(
                        title: "Issues",
                        systemImage: "sphere",
                        tint: .glabAccent,
                        value: "Off"
                    )
                    .opacity(0.6)
                } else {
                    NavigationLink {
                        GitLabProjectIssuesView(
                            project: project,
                            apiAccess: apiAccess,
                            loader: issueLoader,
                            discussionLoader:
                                discussionLoader,
                            discussionMutator:
                                discussionMutator,
                            reactionService:
                                reactionService,
                            editService: editService,
                            issueStatusService:
                                issueStatusService,
                            issueCreationService:
                                issueCreationService,
                            accountID: accountID,
                            appSession: appSession,
                            onResourceEdited:
                                onResourceEdited
                        )
                    } label: {
                        GitLabProjectWorkRow(
                            title: "Issues",
                            systemImage: "sphere",
                            tint: .glabAccent,
                            value: openIssuesText
                        )
                    }
                    .accessibilityIdentifier(
                        "project.work.issues"
                    )
                }

                NavigationLink {
                    GitLabProjectPipelinesView(
                        project: project,
                        overviewLoader: overviewLoader,
                        pipelineLoader: pipelineLoader,
                        accountID: accountID,
                        appSession: appSession,
                        apiAccess: apiAccess,
                        isAccountCurrent:
                            isAccountCurrent
                    )
                } label: {
                    GitLabProjectWorkRow(
                        title: "Pipelines",
                        systemImage: "dial.medium",
                        tint: .orange,
                        value: latestPipelineStatus
                    )
                }
                .accessibilityIdentifier(
                    "project.work.pipelines"
                )

                NavigationLink {
                    GitLabProjectBranchListView(
                        project: project,
                        loader: repositoryLoader,
                        accountID: accountID,
                        appSession: appSession
                    )
                } label: {
                    GitLabProjectWorkRow(
                        title: "Branches",
                        systemImage:
                            "arrow.triangle.branch",
                        tint: .teal,
                        value: branchText
                    )
                }
                .accessibilityIdentifier(
                    "project.work.branches"
                )

                NavigationLink {
                    GitLabProjectTagsView(
                        project: project,
                        loader: repositoryLoader,
                        accountID: accountID,
                        appSession: appSession
                    )
                } label: {
                    GitLabProjectWorkRow(
                        title: "Releases",
                        systemImage: "shippingbox",
                        tint: .indigo,
                        value: releaseText
                    )
                }
                .accessibilityIdentifier(
                    "project.work.releases"
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var openMergeRequestText: String {
        if
            case let .loaded(count) =
                overviewModel?
                .openMergeRequestCount,
            let count
        {
            return count.formatted()
        }
        return "–"
    }

    private var openIssuesText: String {
        project.openIssuesCount
            .map { $0.formatted() } ?? "–"
    }

    private var latestPipelineStatus: String {
        if
            case let .loaded(pipeline) =
                overviewModel?.latestPipeline,
            let pipeline
        {
            return pipeline.status.title
        }
        return "–"
    }

    private var branchText: String {
        if
            case let .loaded(count) =
                overviewModel?.branchCount,
            let count
        {
            return count.formatted()
        }
        return "–"
    }

    private var releaseText: String {
        if
            case let .loaded(count) =
                overviewModel?.releaseCount,
            let count
        {
            return count.formatted()
        }
        return "–"
    }
}

// MARK: - Work row

struct GitLabProjectWorkRow: View {
    let title: String
    let systemImage: String
    let tint: Color
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.glabSubheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(tint, in: .rect(cornerRadius: 8))
                .accessibilityHidden(true)

            Text(title)
                .font(.glabSubheadline)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Text(value)
                .font(.glabSubheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Image(systemName: "chevron.right")
                .font(.glabCaption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tools grid

private struct GitLabProjectTool: Identifiable {
    let title: String
    let systemImage: String
    let tint: Color
    let id: String

    static let all: [GitLabProjectTool] = [
        .init(
            title: "Boards",
            systemImage: "rectangle.split.3x1",
            tint: .purple,
            id: "boards"
        ),
        .init(
            title: "Labels",
            systemImage: "tag.circle.fill",
            tint: .indigo,
            id: "labels"
        ),
        .init(
            title: "Milestones",
            systemImage: "flag.fill",
            tint: .indigo,
            id: "milestones"
        ),
        .init(
            title: "Tags",
            systemImage: "ticket",
            tint: .pink,
            id: "tags"
        ),
        .init(
            title: "Wiki",
            systemImage: "book.fill",
            tint: .blue,
            id: "wiki"
        ),
        .init(
            title: "Activity",
            systemImage: "bolt.fill",
            tint: .blue,
            id: "activity"
        ),
        .init(
            title: "Members",
            systemImage: "person.2.fill",
            tint: .gray,
            id: "members"
        ),
        .init(
            title: "Registry",
            systemImage: "shippingbox.fill",
            tint: .orange,
            id: "registry"
        ),
        .init(
            title: "DevOps",
            systemImage: "wrench.and.screwdriver.fill",
            tint: .orange,
            id: "devops"
        ),
        .init(
            title: "Branch Graph",
            systemImage: "point.topleft.down.curvedto.point.bottomright.up",
            tint: .teal,
            id: "branch-graph"
        ),
        .init(
            title: "Compare",
            systemImage: "arrow.left.arrow.right",
            tint: .teal,
            id: "compare"
        ),
        .init(
            title: "Snippets",
            systemImage: "scissors",
            tint: .blue,
            id: "snippets"
        ),
    ]
}

struct GitLabProjectToolsSection: View {
    var body: some View {
        GitLabDetailSection(title: "Tools") {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(.flexible()),
                    count: 4
                ),
                spacing: 16
            ) {
                ForEach(
                    GitLabProjectTool.all
                ) { tool in
                    NavigationLink {
                        GitLabProjectComingSoonView(
                            title: tool.title
                        )
                    } label: {
                        VStack(spacing: 6) {
                            Image(
                                systemName: tool
                                    .systemImage
                            )
                            .font(
                                .glabHeadline.weight(
                                    .semibold
                                )
                            )
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(
                                tool.tint,
                                in: .rect(cornerRadius: 12)
                            )

                            Text(tool.title)
                                .font(.glabCaption)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "project.tool.\(tool.id)"
                    )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 10)
            .background(
                Color.secondary.opacity(0.06),
                in: .rect(cornerRadius: 16)
            )
        }
        .accessibilityIdentifier("project.tools")
    }
}

struct GitLabProjectComingSoonView: View {
    let title: String

    var body: some View {
        GitLabEmptyStateView(
            title: title,
            message: "This project tool isn’t available in this build yet.",
            systemImage: "hammer"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.glabCanvas)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Branches list

struct GitLabProjectBranchListView: View {
    let project: GitLabProject
    let loader: any GitLabRepositoryBrowsing
    let accountID: GitLabAccountID
    let appSession: AppSession

    @State private var model:
        GitLabRepositoryBranchesModel

    init(
        project: GitLabProject,
        loader: any GitLabRepositoryBrowsing,
        accountID: GitLabAccountID,
        appSession: AppSession
    ) {
        self.project = project
        self.loader = loader
        self.accountID = accountID
        self.appSession = appSession
        _model = State(
            initialValue:
                GitLabRepositoryBranchesModel(
                    projectID: project.id,
                    defaultBranchName:
                        project.defaultBranch,
                    loader: loader
                )
        )
    }

    var body: some View {
        content
            .background(Color.glabCanvas)
            .navigationTitle("Branches")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refresh()
            }
            .task(id: ObjectIdentifier(model)) {
                await model.loadIfNeeded()
                await handleAuthenticationFailure()
            }
            .accessibilityIdentifier(
                "project.branches"
            )
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingInitial {
            ScrollView {
                GitLabLoadingStateView(
                    message: "Loading branches"
                )
                .padding(20)
            }
        } else if
            model.items.isEmpty,
            let error = model.loadError
        {
            GitLabContentStateScrollView {
                GitLabRetryStateView(
                    error: error
                ) {
                    Task {
                        await refresh()
                    }
                }
            }
        } else if
            model.items.isEmpty,
            model.hasLoaded
        {
            GitLabContentStateScrollView {
                GitLabEmptyStateView(
                    title: "No branches",
                    message:
                        "This repository does not have any branches yet.",
                    systemImage:
                        "arrow.triangle.branch"
                )
            }
        } else {
            branchList
        }
    }

    private var branchList: some View {
        GlabList {
            ForEach(
                model
                    .sortedRepositoryBranches
            ) { branch in
                GitLabProjectBranchRow(branch: branch)
                    .task {
                        await model
                            .loadNextPageIfNeeded(
                                after: branch
                            )
                        await handleAuthenticationFailure()
                    }
            }

            if model.isLoadingNextPage {
                HStack {
                    Spacer()
                    ProgressView("Loading more…")
                        .font(.glabFootnote)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if
                model.didFailNextPage,
                let error = model.loadError
            {
                GitLabInlineRetryRow(
                    title:
                        "Couldn’t load more branches",
                    error: error,
                    accessibilityIdentifier:
                        "project.branchesNextPageError"
                ) {
                    Task {
                        await model.retryNextPage()
                        await handleAuthenticationFailure()
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refresh()
        }
    }

    private func refresh() async {
        await model.refresh()
        await handleAuthenticationFailure()
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error =
                model.authenticationFailure
        else {
            return
        }
        await appSession
            .handleAuthenticationFailure(
                error,
                for: accountID
            )
    }
}

private struct GitLabProjectBranchRow: View {
    let branch: GitLabRepositoryBranch

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.branch")
                .foregroundStyle(Color.glabAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(branch.name)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if branch.isDefault {
                    Text("Default")
                        .font(.glabCaption)
                        .foregroundStyle(.secondary)
                } else if branch.isProtected {
                    Text("Protected")
                        .font(.glabCaption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tags list

struct GitLabProjectTagsView: View {
    let project: GitLabProject
    let loader: any GitLabRepositoryBrowsing
    let accountID: GitLabAccountID
    let appSession: AppSession

    @State private var model:
        GitLabRepositoryTagsModel

    init(
        project: GitLabProject,
        loader: any GitLabRepositoryBrowsing,
        accountID: GitLabAccountID,
        appSession: AppSession
    ) {
        self.project = project
        self.loader = loader
        self.accountID = accountID
        self.appSession = appSession
        _model = State(
            initialValue:
                GitLabRepositoryTagsModel(
                    projectID: project.id,
                    loader: loader
                )
        )
    }

    var body: some View {
        content
            .background(Color.glabCanvas)
            .navigationTitle("Tags")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refresh()
            }
            .task(id: ObjectIdentifier(model)) {
                await model.loadIfNeeded()
                await handleAuthenticationFailure()
            }
            .accessibilityIdentifier("project.tags")
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoadingInitial {
            ScrollView {
                GitLabLoadingStateView(
                    message: "Loading tags"
                )
                .padding(20)
            }
        } else if
            model.items.isEmpty,
            let error = model.loadError
        {
            GitLabContentStateScrollView {
                GitLabRetryStateView(
                    error: error
                ) {
                    Task {
                        await refresh()
                    }
                }
            }
        } else if
            model.items.isEmpty,
            model.hasLoaded
        {
            GitLabContentStateScrollView {
                GitLabEmptyStateView(
                    title: "No tags",
                    message:
                        "This repository does not have any tags yet.",
                    systemImage: "ticket"
                )
            }
        } else {
            tagList
        }
    }

    private var tagList: some View {
        GlabList {
            ForEach(model.items) { tag in
                GitLabProjectTagRow(tag: tag)
                    .task {
                        await model
                            .loadNextPageIfNeeded(
                                after: tag
                            )
                        await handleAuthenticationFailure()
                    }
            }

            if model.isLoadingNextPage {
                HStack {
                    Spacer()
                    ProgressView("Loading more…")
                        .font(.glabFootnote)
                    Spacer()
                }
                .listRowBackground(Color.clear)
            } else if
                model.didFailNextPage,
                let error = model.loadError
            {
                GitLabInlineRetryRow(
                    title:
                        "Couldn’t load more tags",
                    error: error,
                    accessibilityIdentifier:
                        "project.tagsNextPageError"
                ) {
                    Task {
                        await model.retryNextPage()
                        await handleAuthenticationFailure()
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await refresh()
        }
    }

    private func refresh() async {
        await model.refresh()
        await handleAuthenticationFailure()
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error =
                model.authenticationFailure
        else {
            return
        }
        await appSession
            .handleAuthenticationFailure(
                error,
                for: accountID
            )
    }
}

private struct GitLabProjectTagRow: View {
    let tag: GitLabRepositoryTag

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "ticket")
                .foregroundStyle(Color.glabAccent)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(tag.name)
                    .font(.glabSubheadline.monospaced())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if
                    let message = tag.message?
                        .trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ),
                    !message.isEmpty
                {
                    Text(message)
                        .font(.glabCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            if let shortCommitID = tag.shortCommitID {
                Text(shortCommitID)
                    .font(.glabCaption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
