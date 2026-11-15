import SwiftUI

/// Search tab from the reference design (r20): a large inline search
/// field, scope chips, recent projects, and quick links to the full
/// project/group listings.
struct GitLabSearchTabView: View {    let session: GitLabStoredSession
    let accountID: GitLabAccountID
    let appSession: AppSession
    let searchModel: GitLabGlobalSearchModel
    let searchLoader: any GitLabSearchLoading
    let projectLoader:
        any GitLabProjectLoading
            & GitLabProjectResolving
    let projectStarringService:
        any GitLabProjectStarringServing
    let userService: any GitLabUserServing
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
    let mergeRequestCreationService:
        any GitLabMergeRequestCreationServing
    let commitLoader: any GitLabCommitLoading
    let repositoryLoader: any GitLabRepositoryLoading
    let overviewLoader:
        any GitLabProjectOverviewLoading
    let issueCreationService:
        any GitLabIssueCreationServing
    let onResourceEdited:
        (GitLabResourceEditResult) -> Void

    @State private var recentProjectsModel:
        ProjectsModel
    @State private var path = NavigationPath()
    @State private var selectedScope:
        GitLabSearchScope = .projects

    init(
        session: GitLabStoredSession,
        accountID: GitLabAccountID,
        appSession: AppSession,
        searchModel: GitLabGlobalSearchModel,
        searchLoader: any GitLabSearchLoading,
        projectLoader:
            any GitLabProjectLoading
                & GitLabProjectResolving,
        projectStarringService:
            any GitLabProjectStarringServing,
        userService: any GitLabUserServing,
        issueLoader: any GitLabIssueLoading,
        mergeRequestLoader:
            any GitLabMergeRequestLoading
                & GitLabMergeRequestApprovalLoading
                & GitLabMergeRequestDiffLoading
                & GitLabMergeRequestDiffSummaryLoading,
        mergeRequestApprovalService:
            any GitLabMergeRequestApprovalServing,
        mergeRequestMergeService:
            any GitLabMergeRequestMergeServing,
        pipelineLoader: any GitLabPipelineLoading,
        discussionLoader: any GitLabDiscussionLoading,
        discussionMutator: any GitLabDiscussionMutating,
        reactionService:
            any GitLabEmojiReactionLoading
                & GitLabEmojiReactionMutating,
        editService: any GitLabResourceEditing,
        issueStatusService: any GitLabIssueStatusServing,
        mergeRequestCreationService:
            any GitLabMergeRequestCreationServing,
        commitLoader: any GitLabCommitLoading,
        repositoryLoader: any GitLabRepositoryLoading,
        overviewLoader:
            any GitLabProjectOverviewLoading,
        issueCreationService:
            any GitLabIssueCreationServing,
        onResourceEdited:
            @escaping (GitLabResourceEditResult) -> Void
    ) {
        self.session = session
        self.accountID = accountID
        self.appSession = appSession
        self.searchModel = searchModel
        self.searchLoader = searchLoader
        self.projectLoader = projectLoader
        self.projectStarringService =
            projectStarringService
        self.userService = userService
        self.issueLoader = issueLoader
        self.mergeRequestLoader = mergeRequestLoader
        self.mergeRequestApprovalService =
            mergeRequestApprovalService
        self.mergeRequestMergeService =
            mergeRequestMergeService
        self.pipelineLoader = pipelineLoader
        self.discussionLoader = discussionLoader
        self.discussionMutator = discussionMutator
        self.reactionService = reactionService
        self.editService = editService
        self.issueStatusService = issueStatusService
        self.mergeRequestCreationService =
            mergeRequestCreationService
        self.commitLoader = commitLoader
        self.repositoryLoader = repositoryLoader
        self.overviewLoader = overviewLoader
        self.issueCreationService =
            issueCreationService
        self.onResourceEdited = onResourceEdited
        _recentProjectsModel = State(
            initialValue: ProjectsModel(
                mode: .recent,
                loader: projectLoader
            )
        )
    }

    var body: some View {
        @Bindable var searchModel = searchModel

        NavigationStack(path: $path) {
            GlabList {
                if searchModel.normalizedQuery.isEmpty {
                    recentProjectsSection
                    quickLinksSection
                } else {
                    ForEach(
                        [selectedScope],
                        id: \.self
                    ) { scope in
                        searchSection(scope)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .background(Color.glabCanvas)
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(
                for: GitLabNativeRoute.self
            ) {
                nativeDestination(for: $0)
            }
            .navigationDestination(
                for: SearchQuickLink.self
            ) { link in
                quickLinkDestination(for: link)
            }
            .safeAreaInset(
                edge: .top,
                spacing: 0
            ) {
                VStack(spacing: 8) {
                    GitLabSearchField(
                        text: $searchModel.query,
                        prompt: "Search projects",
                        accessibilityIdentifier:
                            "searchTab.field"
                    )
                    scopeChips
                }
                .background(Color.glabCanvas)
            }
            .ignoresSafeArea(
                .keyboard,
                edges: .bottom
            )
            .task(id: searchModel.query) {
                await searchModel.search(
                    searchModel.query
                )
                await handleAuthenticationFailure()
            }
            .refreshable {
                if searchModel.normalizedQuery.isEmpty {
                    await recentProjectsModel
                        .refresh()
                    await handleAuthenticationFailure()
                } else {
                    await searchModel.refresh()
                    await handleAuthenticationFailure()
                }
            }
            .task {
                await recentProjectsModel
                    .loadIfNeeded()
                await handleAuthenticationFailure()
            }
        }
        .accessibilityIdentifier("searchTab.screen")
    }

    private var scopeChips: some View {
        Picker(
            "Category",
            selection: $selectedScope
        ) {
            ForEach(
                GitLabSearchScope.allCases,
                id: \.self
            ) { scope in
                Text(scope.tabTitle)
                    .tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityIdentifier(
            "searchTab.scopePicker"
        )
    }

    private var recentProjectsSection: some View {
        Section("Recent Projects") {
            if recentProjectsModel.isLoadingInitial {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier(
                    "searchTab.recentProjects.loading"
                )
            } else if
                recentProjectsModel.items.isEmpty
            {
                Text("No recent projects.")
                    .font(.glabFootnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)
                    .accessibilityIdentifier(
                        "searchTab.recentProjects.empty"
                    )
            } else {
                ForEach(
                    recentProjectsModel.items
                ) { project in
                    NavigationLink(
                        value: GitLabNativeRoute
                            .project(
                                GitLabProjectRoute(
                                    pathWithNamespace:
                                        project
                                        .pathWithNamespace
                                )
                            )
                    ) {
                        SearchTabProjectRow(
                            project: project
                        )
                    }
                    .accessibilityIdentifier(
                        "searchTab.recentProject.\(project.id)"
                    )
                }
            }
        }
    }

    private var quickLinksSection: some View {
        Section {
            NavigationLink(
                value: SearchQuickLink.allProjects
            ) {
                Label {
                    Text("All Projects")
                } icon: {
                    Image(systemName: "folder")
                }
            }
            .accessibilityIdentifier(
                "searchTab.quickLink.allProjects"
            )

            NavigationLink(
                value: SearchQuickLink.groups
            ) {
                Label {
                    Text("Groups")
                } icon: {
                    Image(systemName: "person.2")
                }
            }
            .accessibilityIdentifier(
                "searchTab.quickLink.groups"
            )
        }
    }

    @ViewBuilder
    private func quickLinkDestination(
        for link: SearchQuickLink
    ) -> some View {
        switch link {
        case .allProjects:
            ProjectsView(
                mode: .recent,
                loader: projectLoader,
                accountID: accountID,
                appSession: appSession,
                projectStarChange: nil
            )
        case .groups:
            GroupsPlaceholderView()
        }
    }

    @ViewBuilder
    private func searchSection(
        _ scope: GitLabSearchScope
    ) -> some View {
        let state = searchModel.state(
            for: scope
        )

        Section {
            scopeContent(
                scope,
                state: state
            )
        } header: {
            HStack {
                Text(scope.tabTitle)

                Spacer()

                if
                    let count =
                        state.totalCount,
                    state.status == .loaded
                {
                    Text(
                        count.formatted()
                    )
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                }
            }
            .textCase(nil)
            .accessibilityIdentifier(
                "searchTab.section.\(scope.rawValue)"
            )
        }
    }

    @ViewBuilder
    private func scopeContent(
        _ scope: GitLabSearchScope,
        state: GitLabSearchScopeState
    ) -> some View {
        switch state.status {
        case .idle, .loading:
            HStack(spacing: 10) {
                ProgressView()
                Text(
                    "Searching "
                        + scope.tabTitle
                            .lowercased()
                        + "…"
                )
                .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier(
                "searchTab.loading.\(scope.rawValue)"
            )
        case .loaded:
            if state.results.isEmpty {
                Text(
                    "GitLab returned no matching "
                        + scope.tabTitle.lowercased()
                        + "."
                )
                .foregroundStyle(.secondary)
                .accessibilityIdentifier(
                    "searchTab.empty.\(scope.rawValue)"
                )
            } else {
                ForEach(
                    Array(
                        state.results.enumerated()
                    ),
                    id: \.element.resourceID
                ) { index, result in
                    NavigationLink(
                        value: result.nativeRoute
                    ) {
                        searchResultRow(
                            result
                        )
                    }
                    .accessibilityIdentifier(
                        "searchTab.result."
                            + "\(scope.rawValue).\(index)"
                    )
                }
            }

            paginationControl(
                scope,
                state: state
            )
        case let .unavailable(error):
            Label {
                VStack(
                    alignment: .leading,
                    spacing: 3
                ) {
                    Text(
                        scope.tabTitle
                            + " aren’t available"
                    )
                    .font(
                        .glabCallout.weight(
                            .semibold
                        )
                    )
                    Text(
                        GitLabRecoveryPresentation(
                            error: error
                        ).message
                    )
                    .font(.glabCaption)
                }
            } icon: {
                Image(
                    systemName:
                        "lock.trianglebadge.exclamationmark"
                )
            }
            .foregroundStyle(.secondary)
            .accessibilityIdentifier(
                "searchTab.unavailable."
                    + scope.rawValue
            )
        case let .failed(error):
            GitLabInlineRetryRow(
                title:
                    "Couldn’t search "
                    + scope.tabTitle.lowercased(),
                error: error,
                accessibilityIdentifier:
                    "searchTab.retry."
                    + scope.rawValue
            ) {
                Task {
                    await searchModel.retry(
                        scope
                    )
                    await handleAuthenticationFailure()
                }
            }
        }
    }

    /// Mirrors the row presentation from the global search screen;
    /// users additionally show their avatar.
    @ViewBuilder
    private func searchResultRow(
        _ result: GitLabSearchResult
    ) -> some View {
        switch result {
        case let .user(user):
            HStack(spacing: 12) {
                GitLabUserAvatar(
                    user: user.summary,
                    size: 34
                )

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(user.displayName)
                        .font(
                            .glabBody.weight(
                                .semibold
                            )
                        )
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text("@" + user.username)
                        .font(.glabCaption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 3)
            .accessibilityElement(
                children: .ignore
            )
            .accessibilityLabel(
                user.displayName
                    + ", @"
                    + user.username
            )
            .accessibilityHint(
                "Opens the GitLab profile"
            )
        default:
            SearchTabResultRow(
                result: result
            )
        }
    }

    @ViewBuilder
    private func paginationControl(
        _ scope: GitLabSearchScope,
        state: GitLabSearchScopeState
    ) -> some View {
        if state.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView("Loading more…")
                    .font(.glabFootnote)
                Spacer()
            }
            .accessibilityIdentifier(
                "searchTab.loadMore.loading."
                    + scope.rawValue
            )
        } else if
            let error = state.nextPageError
        {
            GitLabInlineRetryRow(
                title: "Couldn’t load more",
                error: error,
                accessibilityIdentifier:
                    "searchTab.loadMore.retry."
                    + scope.rawValue
            ) {
                Task {
                    await searchModel
                        .loadNextPage(for: scope)
                    await handleAuthenticationFailure()
                }
            }
        } else if state.nextPageURL != nil {
            Button {
                Task {
                    await searchModel
                        .loadNextPage(for: scope)
                    await handleAuthenticationFailure()
                }
            } label: {
                Label(
                    "Load more",
                    systemImage:
                        "arrow.down.circle"
                )
                .frame(
                    maxWidth: .infinity,
                    alignment: .center
                )
            }
            .accessibilityIdentifier(
                "searchTab.loadMore."
                    + scope.rawValue
            )
        }
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error = searchModel
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

    @ViewBuilder
    private func nativeDestination(
        for route: GitLabNativeRoute
    ) -> some View {
        switch route {
        case let .project(projectRoute):
            GitLabProjectDetailView(
                route: projectRoute,
                loader: projectLoader,
                starringService:
                    projectStarringService,
                apiAccess:
                    session.apiAccess,
                issueLoader:
                    issueLoader,
                mergeRequestLoader:
                    mergeRequestLoader,
                mergeRequestApprovalService:
                    mergeRequestApprovalService,
                mergeRequestMergeService:
                    mergeRequestMergeService,
                pipelineLoader:
                    pipelineLoader,
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
                issueCreationService:
                    issueCreationService,
                mergeRequestCreationService:
                    mergeRequestCreationService,
                commitLoader:
                    commitLoader,
                repositoryLoader:
                    repositoryLoader,
                overviewLoader:
                    overviewLoader,
                accountID: accountID,
                appSession: appSession,
                onResourceEdited:
                    onResourceEdited,
                onProjectStarChanged: {
                    change in
                    Task {
                        await recentProjectsModel
                            .refresh()
                    }
                }
            )
        case let .issue(issueRoute):
            GitLabIssueDetailView(
                route: issueRoute,
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
        case let .mergeRequest(
            mergeRequestRoute
        ):
            GitLabMergeRequestDetailView(
                route: mergeRequestRoute,
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
                editService:
                    editService,
                accountID: accountID,
                appSession: appSession,
                onResourceEdited:
                    onResourceEdited
            )
        case let .repositoryFile(
            fileRoute
        ):
            GitLabRepositoryFileView(
                route: fileRoute,
                loader: repositoryLoader,
                commitLoader: commitLoader,
                apiAccess: session.apiAccess,
                accountID: accountID,
                appSession: appSession
            )
        case let .user(userRoute):
            GitLabUserProfileView(
                route: userRoute,
                service: userService,
                session: session,
                accountID: accountID,
                appSession: appSession
            )
        }
    }
}

private enum SearchQuickLink: Hashable {
    case allProjects
    case groups
}

private struct SearchTabProjectRow: View {
    let project: GitLabProject

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            HStack(spacing: 8) {
                HomeProjectAvatarBadge(
                    name: project.name
                )
                .accessibilityHidden(true)

                Text(project.name)
                    .font(
                        .glabBody.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer(minLength: 8)

                Text(
                    GitLabRelativeTimeFormatter
                        .string(
                            from:
                                project
                                .lastActivityAt
                        )
                )
                .font(.glabFootnote)
                .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(project.pathWithNamespace)
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            project.nameWithNamespace
        )
        .accessibilityHint(
            "Opens the project"
        )
    }
}

private struct SearchTabResultRow: View {
    let result: GitLabSearchResult

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            GitLabIconView(result.gitLabIcon)
            .foregroundStyle(Color.glabAccent)
            .frame(width: 34, height: 34)
            .background(
                Color.glabAccent.opacity(0.12),
                in: .rect(cornerRadius: 9)
            )
            .accessibilityHidden(true)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(result.title)
                    .font(
                        .glabBody.weight(.semibold)
                    )
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Text(result.subtitle)
                    .font(.glabCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                if
                    let description =
                        result.summaryPreview
                {
                    Text(description)
                        .font(.glabCaption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            result.title
                + ", "
                + result.subtitle
        )
        .accessibilityHint(
            "Opens the native GitLab detail"
        )
    }
}

private struct GroupsPlaceholderView: View {
    var body: some View {
        GitLabEmptyStateView(
            title: "Groups",
            message:
                "Group browsing isn’t available yet. "
                + "Use Search to find projects instead.",
            systemImage: "person.2"
        )
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(Color.glabCanvas)
        .navigationTitle("Groups")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private extension GitLabSearchResult {
    var gitLabIcon: GitLabIcon {
        switch self {
        case .project:
            .project
        case .issue:
            .workItemIssue
        case .mergeRequest:
            .mergeRequest
        case .user:
            .group
        }
    }

    var title: String {
        switch self {
        case let .project(project):
            project.nameWithNamespace
                ?? project.name
        case let .issue(issue):
            issue.title
        case let .mergeRequest(
            mergeRequest
        ):
            mergeRequest.title
        case let .user(user):
            user.displayName
        }
    }

    var subtitle: String {
        switch self {
        case let .project(project):
            project.pathWithNamespace
        case let .issue(issue):
            [
                "#\(issue.iid)",
                issue.state.capitalized,
                issue.author.map {
                    "@\($0.username)"
                },
            ]
            .compactMap(\.self)
            .joined(separator: "  •  ")
        case let .mergeRequest(
            mergeRequest
        ):
            [
                "!\(mergeRequest.iid)",
                mergeRequest.isDraft
                    ? "Draft"
                    : mergeRequest.state
                        .capitalized,
                mergeRequest.author.map {
                    "@\($0.username)"
                },
            ]
            .compactMap(\.self)
            .joined(separator: "  •  ")
        case let .user(user):
            "@" + user.username
        }
    }
}

private extension GitLabSearchScope {
    var tabTitle: String {
        switch self {
        case .projects:
            "Projects"
        case .issues:
            "Issues"
        case .mergeRequests:
            "MRs"
        case .users:
            "Users"
        }
    }
}
