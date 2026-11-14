import SwiftUI

struct GitLabProjectDetailView: View {
    let route: GitLabProjectRoute
    let apiAccess: GitLabAPIAccess
    let onProjectStarChanged:
        (GitLabProjectStarChange) -> Void
    let issueLoader:
        any GitLabIssueLoading
    let mergeRequestLoader:
        any GitLabMergeRequestLoading
            & GitLabMergeRequestApprovalLoading
            & GitLabMergeRequestDiffLoading
            & GitLabMergeRequestDiffSummaryLoading
    let mergeRequestApprovalService:
        any GitLabMergeRequestApprovalServing
    let mergeRequestMergeService:
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
    let issueStatusService:
        any GitLabIssueStatusServing
    let issueCreationService:
        any GitLabIssueCreationServing
    let commitLoader:
        any GitLabCommitLoading
    let repositoryLoader:
        any GitLabRepositoryLoading
    let overviewLoader:
        any GitLabProjectOverviewLoading
    let accountID: GitLabAccountID
    let appSession: AppSession
    let onResourceEdited:
        (GitLabResourceEditResult) -> Void

    @State private var overviewModel:
        GitLabProjectOverviewModel?
    @State private var didCopyCloneURL = false
    @State private var model:
        GitLabProjectDetailModel
    @State private var starModel:
        GitLabProjectStarModel
    @State private var createdIssueRoute:
        GitLabIssueRoute?

    init(
        route: GitLabProjectRoute,
        loader: any GitLabProjectResolving,
        starringService:
            any GitLabProjectStarringServing,
        apiAccess: GitLabAPIAccess,
        issueLoader:
            any GitLabIssueLoading,
        mergeRequestLoader:
            any GitLabMergeRequestLoading
                & GitLabMergeRequestApprovalLoading
                & GitLabMergeRequestDiffLoading
                & GitLabMergeRequestDiffSummaryLoading,
        mergeRequestApprovalService:
            any GitLabMergeRequestApprovalServing,
        mergeRequestMergeService:
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
        issueStatusService:
            any GitLabIssueStatusServing,
        issueCreationService:
            any GitLabIssueCreationServing,
        commitLoader:
            any GitLabCommitLoading,
        repositoryLoader:
            any GitLabRepositoryLoading,
        overviewLoader:
            any GitLabProjectOverviewLoading,
        accountID: GitLabAccountID,
        appSession: AppSession,
        onResourceEdited:
            @escaping (
                GitLabResourceEditResult
            ) -> Void,
        onProjectStarChanged:
            @escaping (
                GitLabProjectStarChange
            ) -> Void
    ) {
        self.route = route
        self.apiAccess = apiAccess
        self.issueLoader = issueLoader
        self.mergeRequestLoader =
            mergeRequestLoader
        self.mergeRequestApprovalService =
            mergeRequestApprovalService
        self.mergeRequestMergeService =
            mergeRequestMergeService
        self.pipelineLoader =
            pipelineLoader
        self.discussionLoader =
            discussionLoader
        self.discussionMutator =
            discussionMutator
        self.reactionService =
            reactionService
        self.editService = editService
        self.issueStatusService =
            issueStatusService
        self.issueCreationService =
            issueCreationService
        self.commitLoader =
            commitLoader
        self.repositoryLoader =
            repositoryLoader
        self.overviewLoader = overviewLoader
        self.accountID = accountID
        self.appSession = appSession
        self.onResourceEdited =
            onResourceEdited
        self.onProjectStarChanged =
            onProjectStarChanged
        _model = State(
            initialValue:
                GitLabProjectDetailModel(
                    route: route,
                    loader: loader
                )
        )
        _starModel = State(
            initialValue:
                GitLabProjectStarModel(
                    accountID: accountID,
                    apiAccess: apiAccess,
                    projectPathWithNamespace:
                        route.pathWithNamespace,
                    initialIsStarred:
                        route.initialIsStarred,
                    service:
                        starringService,
                    stateStore:
                        appSession
                        .projectStarStateStore,
                    isAccountCurrent: {
                        appSession
                            .activeAccountID
                            == accountID
                    }
                )
        )
    }

    var body: some View {
        content
            .navigationTitle("Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(
                    placement: .topBarTrailing
                ) {
                    if let project = loadedProject {
                        projectMenu(project)
                    }
                }
            }
            .background(
                Color.glabCanvas
            )
            .task {
                await load()
            }
            .task(id: loadedProject?.id) {
                guard let loadedProject else {
                    return
                }
                await starModel.loadIfNeeded(
                    project: loadedProject
                )
                await handleAuthenticationFailure()
            }
            .task(id: loadedProject?.id) {
                guard let loadedProject else {
                    return
                }
                let overview =
                    overviewModel
                    ?? GitLabProjectOverviewModel(
                        project: loadedProject,
                        overviewLoader:
                            overviewLoader,
                        commitLoader: commitLoader,
                        isAccountCurrent:
                            isAccountCurrent
                    )
                overviewModel = overview
                await overview.loadIfNeeded()
                await handleAuthenticationFailure()
            }
            .alert(
                "Couldn’t update star",
                isPresented:
                    starFailureIsPresented
            ) {
                Button("OK") {
                    starModel.dismissFailure()
                }
            } message: {
                Text(
                    starModel.failure?
                        .localizedDescription
                        ?? ""
                )
            }
            .accessibilityIdentifier(
                "project.detail"
            )
            .navigationDestination(
                isPresented:
                    createdIssueIsPresented
            ) {
                if let createdIssueRoute {
                    issueDetail(
                        route:
                            createdIssueRoute
                    )
                }
            }
            .gitLabProjectIssueCreation(
                project: loadedProject,
                apiAccess: apiAccess,
                isAvailable:
                    projectIssueCreationIsAvailable,
                service:
                    issueCreationService,
                accountID: accountID,
                appSession: appSession,
                accessibilityIdentifier:
                    "project.newIssueButton"
            ) { issue in
                createdIssueRoute =
                    issue.route
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ScrollView {
                GitLabLoadingStateView(
                    message: "Loading project"
                )
                .padding(20)
            }
        case let .failed(error):
            GitLabContentStateScrollView {
                GitLabRetryStateView(
                    error: error
                ) {
                    Task {
                        await retry()
                    }
                }
            }
        case let .loaded(project):
            projectContent(project)
        }
    }

    private func projectContent(
        _ project: GitLabProject
    ) -> some View {
        ScrollView {
            VStack(
                alignment: .leading,
                spacing: 20
            ) {
                GitLabProjectSummaryCard(
                    project: project
                )

                if
                    case let .loaded(languages) =
                        overviewModel?.languages,
                    !languages.isEmpty
                {
                    GitLabProjectLanguageBar(
                        languages: languages
                    )
                }

                projectActions(project)

                projectTiles(project)

                projectCodeSection(project)

                GitLabProjectWorkSection(
                    project: project,
                    overviewModel: overviewModel,
                    repositoryLoader:
                        repositoryLoader,
                    issueLoader: issueLoader,
                    mergeRequestLoader:
                        mergeRequestLoader,
                    mergeRequestApprovalService:
                        mergeRequestApprovalService,
                    mergeRequestMergeService:
                        mergeRequestMergeService,
                    pipelineLoader: pipelineLoader,
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
                    overviewLoader: overviewLoader,
                    apiAccess: apiAccess,
                    accountID: accountID,
                    appSession: appSession,
                    onResourceEdited:
                        onResourceEdited,
                    isAccountCurrent:
                        isAccountCurrent
                )

                if
                    let readmeRoute =
                        GitLabRepositoryFileRoute(
                            readmeIn: project
                        )
                {
                    GitLabProjectReadmeView(
                        route: readmeRoute,
                        loader: repositoryLoader,
                        accountID: accountID,
                        appSession: appSession
                    )
                    .id(readmeRoute)
                }

                GitLabProjectToolsSection()
            }
            .padding(20)
        }
        .refreshable {
            await retry()
            if let loadedProject {
                await starModel.refresh(
                    project: loadedProject
                )
                await overviewModel?.refresh()
                await handleAuthenticationFailure()
            }
        }
    }

    private var loadedProject:
        GitLabProject?
    {
        guard
            case let .loaded(project) =
                model.state
        else {
            return nil
        }
        return project
    }

    private var projectIssueCreationIsAvailable:
        Bool
    {
        guard let loadedProject else {
            return false
        }
        return loadedProject
            .issuesAccessLevel?
            .isDisabled != true
    }

    private func projectActions(
        _ project: GitLabProject
    ) -> some View {
        GlassEffectContainer(spacing: 8) {
            HStack(spacing: 8) {
                projectStarAction(project)

                if let url = project.safeWebURL {
                    Button {
                        UIPasteboard.general.string =
                            url.appendingPathExtension(
                                "git"
                            ).absoluteString
                        didCopyCloneURL = true
                        Task {
                            try? await Task.sleep(
                                for: .seconds(1.5)
                            )
                            didCopyCloneURL = false
                        }
                    } label: {
                        GitLabProjectActionItem(
                            title:
                                didCopyCloneURL
                                ? "Copied"
                                : "Clone",
                            systemImage:
                                didCopyCloneURL
                                ? "checkmark"
                                : "arrow.down.circle",
                            tint: .teal
                        )
                    }
                    .accessibilityLabel(
                        "Copy clone URL"
                    )
                    .accessibilityIdentifier(
                        "project.clone"
                    )

                    ShareLink(item: url) {
                        GitLabProjectActionItem(
                            title: "Share",
                            systemImage:
                                "square.and.arrow.up",
                            tint: .indigo
                        )
                    }
                    .accessibilityIdentifier(
                        "project.share"
                    )

                    Link(destination: url) {
                        GitLabProjectActionItem(
                            title: "Browser",
                            systemImage: "safari",
                            tint: .orange
                        )
                    }
                    .accessibilityIdentifier(
                        "project.openInGitLab"
                    )
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func projectStarAction(
        _ project: GitLabProject
    ) -> some View {
        if apiAccess.canWrite {
            Button {
                Task {
                    if starModel.canRetry {
                        await retryStarStatus(
                            for: project
                        )
                    } else {
                        await toggleStar(
                            for: project
                        )
                    }
                }
            } label: {
                starActionItem
            }
            .disabled(
                !starModel.canToggle
                    && !starModel.canRetry
            )
            .accessibilityLabel(
                starAccessibilityLabel(
                    starModel.state
                )
            )
            .accessibilityValue(
                project.starCount == 1
                ? "1 star"
                : "\(project.starCount) stars"
            )
            .accessibilityHint(
                starAccessibilityHint(
                    starModel.state
                )
            )
            .accessibilityIdentifier(
                "project.starButton"
            )
        } else {
            GitLabProjectActionItem(
                title:
                    project.starCount.formatted(),
                systemImage: "star",
                tint: .secondary
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "\(project.starCount) stars"
            )
        }
    }

    private var starActionItem: some View {
        let isLoading =
            starModel.isMutating
            || {
                switch starModel.state {
                case .idle, .loading:
                    true
                default:
                    false
                }
            }()
        let isStarred = starModel.isStarred == true
        let didFail: Bool = {
            if case .failed = starModel.state {
                return true
            }
            return false
        }()

        return GitLabProjectActionItem(
            title:
                didFail
                ? "Retry"
                : (isStarred ? "Starred" : "Star"),
            systemImage:
                didFail
                ? "arrow.clockwise"
                : (isStarred
                    ? "star.fill"
                    : "star"),
            tint:
                isStarred
                ? Color.glabBrandWarm
                : Color.glabAccent,
            isLoading: isLoading
        )
    }

    private func starAccessibilityLabel(
        _ state: GitLabProjectStarState
    ) -> String {
        switch state {
        case .idle, .loading:
            "Loading star status"
        case .failed:
            "Retry star status"
        case .ready(isStarred: true):
            "Unstar project"
        case .ready(isStarred: false):
            "Star project"
        }
    }

    private func starAccessibilityHint(
        _ state: GitLabProjectStarState
    ) -> String {
        switch state {
        case .idle, .loading:
            "Checks whether this project is starred."
        case .failed:
            "Checks the current star status again."
        case .ready(isStarred: true):
            "Removes this project from your starred projects."
        case .ready(isStarred: false):
            "Adds this project to your starred projects."
        }
    }

    private func projectTiles(
        _ project: GitLabProject
    ) -> some View {
        GitLabStatTileRow {
            if
                project.issuesAccessLevel?
                    .isDisabled == true
            {
                GitLabStatTile(
                    title: "Issues",
                    tint: .secondary,
                    value: "Off"
                ) {
                    GitLabIconView(
                        .workItemIssue,
                        pointSize: 18
                    )
                }
                .opacity(0.6)
            } else {
                NavigationLink {
                    projectIssuesDestination(
                        project
                    )
                } label: {
                    GitLabStatTile(
                        title: "Issues",
                        tint: .glabAccent,
                        value:
                            project.openIssuesCount
                            .map { $0.formatted() }
                            ?? "–"
                    ) {
                        GitLabIconView(
                            .workItemIssue,
                            pointSize: 18
                        )
                    }
                }
                .accessibilityIdentifier(
                    "project.issues"
                )
            }

            if
                project.mergeRequestsAccessLevel?
                    .isDisabled == true
            {
                GitLabStatTile(
                    title: "MRs",
                    tint: .secondary,
                    value: "Off"
                ) {
                    GitLabIconView(
                        .mergeRequest,
                        pointSize: 18
                    )
                }
                .opacity(0.6)
            } else {
                NavigationLink {
                    projectMergeRequestsDestination(
                        project
                    )
                } label: {
                    GitLabStatTile(
                        title: "MRs",
                        tint: .pink,
                        value: mergeRequestCountText
                    ) {
                        GitLabIconView(
                            .mergeRequest,
                            pointSize: 18
                        )
                    }
                }
                .accessibilityIdentifier(
                    "project.mergeRequests"
                )
            }

            NavigationLink {
                projectPipelinesDestination(
                    project
                )
            } label: {
                GitLabStatTile(
                    title: "Pipelines",
                    tint: latestPipelineTint,
                    value: latestPipelineText
                ) {
                    GitLabIconView(
                        .pipeline,
                        pointSize: 18
                    )
                }
            }
            .accessibilityIdentifier(
                "project.pipelines"
            )

            GitLabStatTile(
                title: "Activity",
                tint: .orange,
                value:
                    GitLabRelativeTimeFormatter
                    .string(
                        from: project.lastActivityAt
                    )
            ) {
                Image(systemName: "clock")
            }
        }
        .buttonStyle(.plain)
    }

    private var mergeRequestCountText: String {
        if
            case let .loaded(count) =
                overviewModel?.openMergeRequestCount,
            let count
        {
            return count.formatted()
        }
        return "–"
    }

    private var latestPipelineText: String {
        if
            case let .loaded(pipeline) =
                overviewModel?.latestPipeline,
            let pipeline
        {
            return pipeline.status.title
        }
        return "–"
    }

    private var latestPipelineTint: Color {
        if
            case let .loaded(pipeline) =
                overviewModel?.latestPipeline,
            let pipeline
        {
            return pipeline.status.tint
        }
        return .secondary
    }

    private func projectCodeSection(
        _ project: GitLabProject
    ) -> some View {
        GitLabDetailSection(title: "Code") {
            VStack(
                alignment: .leading,
                spacing: 12
            ) {
                if
                    let branch =
                        project.defaultBranch?
                        .trimmingCharacters(
                            in:
                                .whitespacesAndNewlines
                        ),
                    !branch.isEmpty
                {
                    HStack(spacing: 8) {
                        GitLabProjectBranchChip(
                            branch: branch
                        )
                        Text("default")
                            .font(.glabCaption)
                            .foregroundStyle(
                                .secondary
                            )
                    }
                }

                projectRecentCommits(project)

                projectLatestPipelineRow(project)

                HStack(spacing: 10) {
                    NavigationLink {
                        GitLabRepositoryView(
                            project: project,
                            loader:
                                repositoryLoader,
                            accountID: accountID,
                            appSession: appSession
                        )
                    } label: {
                        codeButtonLabel(
                            "Files",
                            systemImage: "folder"
                        )
                    }
                    .accessibilityIdentifier(
                        "project.code"
                    )

                    NavigationLink {
                        GitLabProjectCommitsView(
                            project: project,
                            loader: commitLoader,
                            accountID: accountID,
                            appSession: appSession
                        )
                    } label: {
                        codeButtonLabel(
                            "History",
                            systemImage:
                                "clock.arrow.circlepath"
                        )
                    }
                    .accessibilityIdentifier(
                        "project.commits"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private func projectRecentCommits(
        _ project: GitLabProject
    ) -> some View {
        switch overviewModel?.commits {
        case let .loaded(commits)
        where !commits.isEmpty:
            VStack(spacing: 12) {
                ForEach(commits) { commit in
                    NavigationLink {
                        GitLabCommitDetailView(
                            project: project,
                            commit: commit,
                            loader: commitLoader,
                            accountID: accountID,
                            appSession: appSession
                        )
                    } label: {
                        GitLabProjectCommitRow(
                            commit: commit
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(
                        "project.commit.\(commit.shortID)"
                    )
                }
            }
        case .loaded:
            Text("No commits yet")
                .font(.glabSubheadline)
                .foregroundStyle(.secondary)
        case .failed:
            Text("Couldn’t load commits")
                .font(.glabSubheadline)
                .foregroundStyle(.secondary)
        case .loading, nil:
            ProgressView()
                .controlSize(.small)
        }
    }

    @ViewBuilder
    private func projectLatestPipelineRow(
        _ project: GitLabProject
    ) -> some View {
        if
            case let .loaded(pipeline?) =
                overviewModel?.latestPipeline,
            let route = GitLabPipelineRoute(
                projectID: project.id,
                pipelineID: pipeline.id
            )
        {
            NavigationLink {
                GitLabPipelineDetailView(
                    route: route,
                    cacheLifetime:
                        pipeline
                        .detailCacheLifetime,
                    loader: pipelineLoader,
                    accountID: accountID,
                    appSession: appSession,
                    apiAccess: apiAccess,
                    isAccountCurrent:
                        isAccountCurrent
                )
            } label: {
                GitLabPipelineHistoryRow(
                    pipeline: pipeline
                )
                .padding(10)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
                .background(
                    Color.secondary.opacity(0.075),
                    in: .rect(cornerRadius: 14)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(
                "project.latestPipeline"
            )
        }
    }

    private func codeButtonLabel(
        _ title: String,
        systemImage: String
    ) -> some View {
        Label(title, systemImage: systemImage)
            .font(
                .glabSubheadline.weight(.semibold)
            )
            .foregroundStyle(Color.glabAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .glassEffect(
                .regular
                    .tint(
                        Color.glabAccent.opacity(0.12)
                    )
                    .interactive(),
                in: .rect(cornerRadius: 14)
            )
            .contentShape(.rect(cornerRadius: 14))
    }

    private func projectMenu(
        _ project: GitLabProject
    ) -> some View {
        Menu {
            if let url = project.safeWebURL {
                Button {
                    UIPasteboard.general.string =
                        url.absoluteString
                } label: {
                    Label(
                        "Copy Link",
                        systemImage:
                            "link"
                    )
                }
            }

            Button {
                UIPasteboard.general.string =
                    String(project.id)
            } label: {
                Label(
                    "Copy Project ID",
                    systemImage:
                        "number"
                )
            }

            NavigationLink {
                GitLabProjectComingSoonView(
                    title: "Compare Branches"
                )
            } label: {
                Label(
                    "Compare Branches",
                    systemImage:
                        "arrow.left.arrow.right"
                )
            }
        } label: {
            Image(systemName: "ellipsis")
                .frame(
                    width: 30,
                    height: 30
                )
        }
        .buttonStyle(.glass(.clear))
        .buttonBorderShape(.circle)
        .accessibilityLabel("Project actions")
    }

    private func projectIssuesDestination(
        _ project: GitLabProject
    ) -> some View {
        GitLabProjectIssuesView(
            project: project,
            apiAccess: apiAccess,
            loader: issueLoader,
            discussionLoader: discussionLoader,
            discussionMutator: discussionMutator,
            reactionService: reactionService,
            editService: editService,
            issueStatusService: issueStatusService,
            issueCreationService:
                issueCreationService,
            accountID: accountID,
            appSession: appSession,
            onResourceEdited: onResourceEdited
        )
    }

    private func projectMergeRequestsDestination(
        _ project: GitLabProject
    ) -> some View {
        GitLabProjectMergeRequestsView(
            project: project,
            loader: mergeRequestLoader,
            approvalService:
                mergeRequestApprovalService,
            mergeService: mergeRequestMergeService,
            pipelineLoader: pipelineLoader,
            discussionLoader: discussionLoader,
            discussionMutator: discussionMutator,
            reactionService: reactionService,
            editService: editService,
            accountID: accountID,
            appSession: appSession,
            onResourceEdited: onResourceEdited
        )
    }

    private func projectPipelinesDestination(
        _ project: GitLabProject
    ) -> some View {
        GitLabProjectPipelinesView(
            project: project,
            overviewLoader: overviewLoader,
            pipelineLoader: pipelineLoader,
            accountID: accountID,
            appSession: appSession,
            apiAccess: apiAccess,
            isAccountCurrent: isAccountCurrent
        )
    }

    private var isAccountCurrent:
        @MainActor () -> Bool
    {
        { [appSession, accountID] in
            appSession.activeAccountID == accountID
        }
    }

    private var createdIssueIsPresented:
        Binding<Bool>
    {
        Binding {
            createdIssueRoute != nil
        } set: { isPresented in
            if !isPresented {
                createdIssueRoute = nil
            }
        }
    }

    private var starFailureIsPresented:
        Binding<Bool>
    {
        Binding {
            starModel.failure != nil
        } set: { isPresented in
            if !isPresented {
                starModel.dismissFailure()
            }
        }
    }

    private func issueDetail(
        route: GitLabIssueRoute
    ) -> some View {
        GitLabIssueDetailView(
            route: route,
            loader: issueLoader,
            discussionLoader:
                discussionLoader,
            discussionMutator:
                discussionMutator,
            reactionService:
                reactionService,
            editService:
                editService,
            issueStatusService:
                issueStatusService,
            accountID: accountID,
            appSession: appSession,
            onResourceEdited:
                onResourceEdited
        )
    }

    private func load() async {
        await model.loadIfNeeded()
        await handleAuthenticationFailure()
    }

    private func retry() async {
        await model.retry()
        await handleAuthenticationFailure()
    }

    private func toggleStar(
        for project: GitLabProject
    ) async {
        let previousIsStarred =
            starModel.isStarred
        let change = await starModel.toggle(
            project: project
        )

        if let change {
            _ = model.reconcileAuthoritative(
                change.project
            )
            onProjectStarChanged(change)
        } else if
            starModel.failure?
                .requiresProjectRefresh == true
        {
            await model.retry()
            if
                model.refreshError == nil,
                let refreshedProject =
                    loadedProject,
                let previousIsStarred,
                let isStarred =
                    starModel.isStarred,
                isStarred != previousIsStarred
            {
                onProjectStarChanged(
                    GitLabProjectStarChange(
                        project:
                            refreshedProject,
                        isStarred:
                            isStarred
                    )
                )
            }
        }
        await handleAuthenticationFailure()
    }

    private func retryStarStatus(
        for project: GitLabProject
    ) async {
        await starModel.refresh(
            project: project
        )
        await handleAuthenticationFailure()
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error =
                model.authenticationFailure
                ?? starModel
                    .authenticationFailure
                ?? overviewModel?
                    .authenticationFailure
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

private struct GitLabProjectReadmeView: View {
    let route: GitLabRepositoryFileRoute
    let loader: any GitLabRepositorySourceLoading
    let accountID: GitLabAccountID
    let appSession: AppSession

    @State private var isExpanded = false
    @State private var isCollapsible = false

    @Environment(\.gitLabReadOnlyMarkdownRenderer)
    private var readOnlyMarkdownRenderer
    @State private var model:
        GitLabRepositoryFileModel
    init(
        route: GitLabRepositoryFileRoute,
        loader: any GitLabRepositorySourceLoading,
        accountID: GitLabAccountID,
        appSession: AppSession
    ) {
        self.route = route
        self.loader = loader
        self.accountID = accountID
        self.appSession = appSession
        _model = State(
            initialValue:
                GitLabRepositoryFileModel(
                    route: route,
                    loader: loader
                )
        )
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 16
        ) {
            header

            Divider()

            content
        }
        .padding(16)
        .background(
            Color.secondary.opacity(0.06),
            in: .rect(cornerRadius: 16)
        )
        .task {
            await model.loadIfNeeded()
            await handleAuthenticationFailure()
        }
        .onChange(
            of: model.authenticationFailure
        ) { _, error in
            guard let error else {
                return
            }
            Task {
                await appSession
                    .handleAuthenticationFailure(
                        error,
                        for: accountID
                    )
            }
        }
        .accessibilityIdentifier(
            "project.readme"
        )
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label(
                route.fileName,
                systemImage: "info.circle"
            )
            .font(.glabHeadline)
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 8)

            if isCollapsible {
                Button {
                    isExpanded.toggle()
                } label: {
                    Text(
                        isExpanded
                            ? "Show Less"
                            : "Show All"
                    )
                    .font(
                        .glabCallout.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        Color.glabAccent
                    )
                }
                .accessibilityIdentifier(
                    isExpanded
                        ? "project.readme.showLess"
                        : "project.readme.showAll"
                )
            }

            Menu {
                NavigationLink {
                    fileView(
                        presentation: .rendered
                    )
                } label: {
                    Label(
                        "Open Full Screen",
                        systemImage:
                            "arrow.up.left.and.arrow.down.right"
                    )
                }

                NavigationLink {
                    fileView(
                        presentation: .raw
                    )
                } label: {
                    Label(
                        "View Raw",
                        systemImage: "text.page"
                    )
                }

                if let destination = route.safeWebURL {
                    Link(destination: destination) {
                        Label(
                            "Open in GitLab",
                            systemImage:
                                "arrow.up.right.square"
                        )
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass(.clear))
            .buttonBorderShape(.circle)
            .accessibilityLabel("README actions")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView()
                    .controlSize(.small)
                Text("Loading README…")
                    .foregroundStyle(.secondary)
            }
            .font(.glabCallout)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
        case let .loaded(document):
            if
                GitLabRepositoryFilePresentation
                    .supportsRenderedMarkdown(
                        document
                    )
            {
                readmePreview(document)
            } else {
                Text(
                    document.language == .markdown
                        ? "This README is too large to render. Open the raw file to read it."
                        : "This README format is available as a raw file."
                )
                .font(.glabCallout)
                .foregroundStyle(.secondary)
            }
        case let .failed(error):
            VStack(
                alignment: .leading,
                spacing: 8
            ) {
                Label(
                    "Couldn’t load README",
                    systemImage:
                        "exclamationmark.triangle"
                )
                .font(
                    .glabCallout.weight(
                        .semibold
                    )
                )

                Text(error.description)
                    .font(.glabCaption)
                    .foregroundStyle(.secondary)

                if error.canRetry {
                    Button("Try Again") {
                        Task {
                            await model.retry()
                            await handleAuthenticationFailure()
                        }
                    }
                    .font(
                        .glabCallout.weight(
                            .semibold
                        )
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func readmePreview(
        _ document: GitLabSourceDocument
    ) -> some View {
        GitLabRepositoryMarkdownContentView(
            route: route,
            document: document,
            accountID: accountID,
            renderer:
                readOnlyMarkdownRenderer
        )
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { full in
                Color.clear.preference(
                    key: GitLabReadmeHeightKey.self,
                    value: full.size.height
                )
            }
        )
        .frame(
            height: isExpanded ? nil : 220,
            alignment: .top
        )
        .clipped()
        .overlay(alignment: .bottom) {
            if !isExpanded && isCollapsible {
                LinearGradient(
                    colors: [
                        .clear,
                        Color.glabCanvas,
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 70)
                .allowsHitTesting(false)
            }
        }
        .onPreferenceChange(
            GitLabReadmeHeightKey.self
        ) { height in
            isCollapsible = height > 260
        }
    }

    private func fileView(
        presentation:
            GitLabRepositoryFilePresentation
    ) -> some View {
        GitLabRepositoryFileView(
            route: route,
            loader: loader,
            accountID: accountID,
            appSession: appSession,
            initialPresentation: presentation
        )
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error = model.authenticationFailure
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

private struct GitLabReadmeHeightKey:
    PreferenceKey
{
    static var defaultValue: CGFloat = 0

    static func reduce(
        value: inout CGFloat,
        nextValue: () -> CGFloat
    ) {
        value = max(value, nextValue())
    }
}
