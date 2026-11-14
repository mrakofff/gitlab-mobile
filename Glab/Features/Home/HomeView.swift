import SwiftUI

private enum HomeNavigationRoute: Hashable {
    case catchUp
    case search
    case reviews
}

enum HomeSheetDestination: Identifiable {
    enum ID: Hashable {
        case account
        case issueCreation(
            ObjectIdentifier
        )
    }

    case account
    case issueCreation(
        GitLabIssueCreationPresentation
    )

    var id: ID {
        switch self {
        case .account:
            .account
        case let .issueCreation(
            presentation
        ):
            .issueCreation(
                presentation.id
            )
        }
    }
}

typealias HomeSheetPresentationState =
    GitLabPreparedSheetPresentationState<
        HomeSheetDestination
    >

struct HomeView: View {
    let session: GitLabStoredSession
    let accountID: GitLabAccountID
    let appSession: AppSession
    let model: HomeDashboardModel
    let todoCatchUpModel: TodoCatchUpModel
    let assignedIssuesModel: AssignedIssuesModel
    let createdIssuesModel: IssuesModel
    let assignedMergeRequestsModel:
        MergeRequestsModel
    let createdMergeRequestsModel:
        MergeRequestsModel
    let reviewRequestsModel:
        MergeRequestsModel
    let todosModel: TodosModel
    let projectsModel: ProjectsModel
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
    let issueCreationService:
        any GitLabIssueCreationServing
    let projectLoader:
        any GitLabProjectLoading
            & GitLabProjectResolving
    let projectStarringService:
        any GitLabProjectStarringServing
    let userService:
        any GitLabUserServing
    let commitLoader:
        any GitLabCommitLoading
    let projectOverviewLoader:
        any GitLabProjectOverviewLoading
    let repositoryLoader:
        any GitLabRepositoryLoading
    let searchModel: GitLabGlobalSearchModel
    let incomingRoute: GitLabNativeRoute?
    let onResourceEdited:
        (GitLabResourceEditResult) -> Void
    let didOpenIncomingRoute: () -> Void
    let onShowTodos: () -> Void

    @State private var path = NavigationPath()
    @State private var
        sheetPresentation =
        HomeSheetPresentationState()
    @State private var
        createdIssueRoute:
        GitLabIssueRoute?
    @State private var projectStarChange:
        GitLabProjectStarChange?

    var body: some View {
        NavigationStack(path: $path) {
            GlabList {
                if !model.hasTotalWorkFailure {
                    overviewSection
                }

                if session.apiAccess == .readOnly {
                    Section {
                        readOnlyCallout
                    }
                }

                if
                    todoCatchUpModel
                        .shouldShowHomeShortcut
                {
                    Section {
                        NavigationLink(
                            value:
                                HomeNavigationRoute
                                .catchUp
                        ) {
                            HomeCatchUpShortcutRow(
                                count:
                                    todoCatchUpModel
                                    .homeShortcutCount
                            )
                        }
                        .accessibilityIdentifier(
                            "home.catchUp"
                        )
                    }
                }

                if model.hasTotalWorkFailure {
                    Section {
                        GitLabRetryStateView(
                            message:
                                "Your GitLab work could not be loaded. "
                                + "Check your connection and try again."
                        ) {
                            Task {
                                await refreshDashboard()
                            }
                        }
                        .frame(minHeight: 280)
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init())
                    }
                } else {
                    mergeRequestsSection
                    issuesSection
                    projectsSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(
                session.host.siteURL.host() ?? "Home"
            )
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: HomeDashboardSection.self) {
                section in
                destination(for: section)
            }
            .navigationDestination(
                for: GitLabNativeRoute.self
            ) {
                nativeDestination(for: $0)
            }
            .navigationDestination(
                for: HomeNavigationRoute.self
            ) { route in
                switch route {
                case .catchUp:
                    TodoCatchUpView(
                        model: todoCatchUpModel,
                        accountID: accountID
                    ) { error in
                        await appSession
                            .handleAuthenticationFailure(
                                error,
                                for: accountID
                            )
                    }
                case .search:
                    GitLabGlobalSearchView(
                        model: searchModel,
                        accountID: accountID,
                        appSession: appSession
                    )
                case .reviews:
                    mergeRequestsDestination(
                        initialMode: .reviewRequested
                    )
                }
            }
            .refreshable {
                await refreshDashboard()
            }
            .task {
                await loadDashboard()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        sheetPresentation
                            .prepare(
                                .account
                            )
                    } label: {
                        GitLabUserAvatar(
                            user: displayedUser,
                            size: 44
                        )
                    }
                    .buttonStyle(.plain)
                    .contentShape(.circle)
                    .accessibilityLabel(
                        "Account for \(displayedUser.displayName)"
                    )
                    .accessibilityHint("Opens account settings.")
                    .accessibilityIdentifier("home.accountButton")
                }

                ToolbarItemGroup(
                    placement: .topBarTrailing
                ) {
                    Button {
                        path.append(
                            HomeNavigationRoute
                                .search
                        )
                    } label: {
                        Image(
                            systemName:
                                "magnifyingglass"
                        )
                    }
                    .accessibilityLabel(
                        "Search GitLab"
                    )
                    .accessibilityHint(
                        "Searches projects, issues, "
                            + "and merge requests."
                    )
                    .accessibilityIdentifier(
                        "home.searchButton"
                    )

                    Button {
                        launchIssueCreation()
                    } label: {
                        Image(
                            systemName:
                                "square.and.pencil"
                        )
                    }
                    .accessibilityLabel(
                        "New issue"
                    )
                    .accessibilityHint(
                        "Opens the issue composer."
                    )
                    .accessibilityIdentifier(
                        "home.newIssueButton"
                    )
                }
            }
        }
        .onChange(
            of: incomingRoute,
            initial: true
        ) { _, route in
            guard let route else {
                return
            }
            path.append(route)
            didOpenIncomingRoute()
        }
        .environment(
            \.gitLabNativeNavigationAction,
            {
                route in
                path.append(route)
            }
        )
        .sheet(
            isPresented:
                sheetIsPresented,
            onDismiss: {
                sheetPresentation
                    .didDismiss()
            }
        ) {
            if
                let destination =
                    sheetPresentation
                    .destination
            {
                sheetContent(
                    for: destination
                )
                .presentationDragIndicator(
                    .visible
                )
            }
        }
        .onChange(
            of:
                sheetPresentation
                .preparedID
        ) { _, preparedID in
            sheetPresentation
                .presentPrepared(
                    id: preparedID
                )
        }
        .onChange(of: createdIssueRoute) {
            _, route in
            guard let route else {
                return
            }
            sheetPresentation.dismiss()
            path.append(
                GitLabNativeRoute.issue(
                    route
                )
            )
            createdIssueRoute = nil
        }
    }

    @MainActor
    private func launchIssueCreation() {
        let model =
            GitLabIssueCreationModel(
                accountID: accountID,
                apiAccess:
                    session.apiAccess,
                service:
                    issueCreationService,
                draftStore:
                    appSession
                    .issueCreationDraftStore,
                isAccountCurrent: {
                    appSession
                        .activeAccountID
                        == accountID
                }
            ) { issue in
                createdIssueRoute =
                    issue.route
            }
        sheetPresentation.prepare(
            .issueCreation(
                GitLabIssueCreationPresentation(
                    model: model
                )
            )
        )
    }

    private var sheetIsPresented:
        Binding<Bool>
    {
        Binding {
            sheetPresentation
                .isPresented
        } set: { isPresented in
            guard !isPresented else {
                return
            }
            sheetPresentation.dismiss()
        }
    }

    @ViewBuilder
    private func sheetContent(
        for destination:
            HomeSheetDestination
    ) -> some View {
        switch destination {
        case .account:
            AccountView(
                session: session,
                appSession: appSession,
                userService: userService
            )
        case let .issueCreation(
            presentation
        ):
            GitLabIssueCreationView(
                model: presentation.model,
                accountID: accountID,
                appSession: appSession
            )
        }
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
                commitLoader:
                    commitLoader,
                repositoryLoader:
                    repositoryLoader,
                overviewLoader:
                    projectOverviewLoader,
                accountID: accountID,
                appSession: appSession,
                onResourceEdited:
                    onResourceEdited,
                onProjectStarChanged: {
                    change in
                    projectStarChange = change
                    Task {
                        await model.refresh()
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

    private var overviewSection: some View {
        Section {
            HomeNeedsAttentionHeader(
                count: attentionCount,
                reviews: reviewRequestsModel.statCount,
                todos: todosModel.pendingBadgeCount
            )
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                .init(
                    top: 8,
                    leading: 4,
                    bottom: 0,
                    trailing: 4
                )
            )

            GitLabStatTileRow {
                Button {
                    path.append(
                        HomeDashboardSection
                            .assignedMergeRequests
                    )
                } label: {
                    GitLabStatTile(
                        title: "MRs",
                        tint: Color.glabAccent,
                        value:
                            assignedMergeRequestsModel
                            .statCountText,
                        icon: {
                            GitLabIconView(
                                .mergeRequest,
                                pointSize: 18
                            )
                        }
                    )
                }
                .accessibilityIdentifier(
                    "home.tile.mergeRequests"
                )

                Button {
                    path.append(
                        HomeNavigationRoute.reviews
                    )
                } label: {
                    GitLabStatTile(
                        title: "Review",
                        tint: Color.pink,
                        value:
                            reviewRequestsModel
                            .statCountText,
                        icon: {
                            Image(systemName: "eye")
                        }
                    )
                }
                .accessibilityIdentifier(
                    "home.tile.review"
                )

                Button {
                    onShowTodos()
                } label: {
                    GitLabStatTile(
                        title: "Todos",
                        tint: Color.orange,
                        value:
                            todosModel
                            .pendingBadgeCount
                            .map(String.init)
                            ?? "–",
                        icon: {
                            Image(systemName: "checklist")
                        }
                    )
                }
                .accessibilityIdentifier(
                    "home.tile.todos"
                )

                Button {
                    path.append(
                        HomeDashboardSection
                            .recentProjects
                    )
                } label: {
                    GitLabStatTile(
                        title: "Projects",
                        tint: Color.indigo,
                        value:
                            projectsModel
                            .statCountText,
                        icon: {
                            Image(systemName: "folder")
                        }
                    )
                }
                .accessibilityIdentifier(
                    "home.tile.projects"
                )
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(
                .init(
                    top: 4,
                    leading: 4,
                    bottom: 4,
                    trailing: 4
                )
            )
        }
    }

    private var attentionCount: Int? {
        let reviews = reviewRequestsModel.statCount
        let todos = todosModel.pendingBadgeCount
        guard reviews != nil || todos != nil else {
            return nil
        }
        return (reviews ?? 0) + (todos ?? 0)
    }

    private var mergeRequestsSection: some View {
        Section {
            if
                assignedMergeRequestsModel
                    .items.isEmpty
            {
                workPlaceholder(
                    for: assignedMergeRequestsModel,
                    emptyMessage:
                        HomeDashboardSection
                        .assignedMergeRequests
                        .emptyMessage
                )
            } else {
                ForEach(
                    assignedMergeRequestsModel
                        .items.prefix(3)
                ) { mergeRequest in
                    NavigationLink(
                        value:
                            GitLabNativeRoute
                            .mergeRequest(
                                mergeRequest.route
                            )
                    ) {
                        HomeMergeRequestRow(
                            mergeRequest:
                                mergeRequest
                        )
                    }
                    .accessibilityIdentifier(
                        "home.mergeRequest.row"
                    )
                }
            }
        } header: {
            HomeSectionHeader(
                title: "Assigned merge requests",
                count:
                    assignedMergeRequestsModel
                    .statCount
                    .map(String.init),
                identifier:
                    "home.mergeRequests.seeAll"
            ) {
                path.append(
                    HomeDashboardSection
                        .assignedMergeRequests
                )
            }
        }
    }

    private var issuesSection: some View {
        Section {
            if assignedIssuesModel.items.isEmpty {
                workPlaceholder(
                    for: assignedIssuesModel,
                    emptyMessage:
                        HomeDashboardSection
                        .assignedIssues
                        .emptyMessage
                )
            } else {
                ForEach(
                    assignedIssuesModel
                        .items.prefix(3)
                ) { issue in
                    NavigationLink(
                        value:
                            GitLabNativeRoute.issue(
                                issue.route
                            )
                    ) {
                        HomeIssueRow(issue: issue)
                    }
                    .accessibilityIdentifier(
                        "home.issue.row"
                    )
                }
            }
        } header: {
            HomeSectionHeader(
                title: "My issues",
                count:
                    assignedIssuesModel
                    .statCount
                    .map(String.init),
                identifier:
                    "home.issues.seeAll"
            ) {
                path.append(
                    HomeDashboardSection
                        .assignedIssues
                )
            }
        }
    }

    private var projectsSection: some View {
        Section {
            ForEach(
                [
                    HomeDashboardSection
                        .recentProjects,
                    .starredProjects,
                ],
                id: \.self
            ) { section in
                NavigationLink(value: section) {
                    HomeWorkShortcutRow(
                        section: section,
                        presentation:
                            model.presentation(
                                for: section
                            )
                    )
                }
                .accessibilityIdentifier(
                    "home.shortcut.\(section.rawValue)"
                )
            }
        } header: {
            Text("Projects")
                .font(.glabHeadline)
                .foregroundStyle(.primary)
                .textCase(nil)
        }
    }

    @ViewBuilder
    private func workPlaceholder<
        Item: Sendable,
        Identity: Hashable & Sendable
    >(
        for list:
            GitLabPaginatedResourceModel<
                Item,
                Identity
            >,
        emptyMessage: String
    ) -> some View {
        if list.loadError != nil {
            HomeDashboardSectionPlaceholder(
                message: "Could not load.",
                retry: {
                    Task {
                        await list.refresh()
                    }
                }
            )
        } else if list.hasLoaded {
            HomeDashboardSectionPlaceholder(
                message: emptyMessage
            )
        } else {
            HomeDashboardSectionPlaceholder(
                message: "Loading…",
                isLoading: true
            )
        }
    }

    private func mergeRequestsDestination(
        initialMode: GitLabMergeRequestListMode
    ) -> some View {
        YourMergeRequestsView(
            assignedModel:
                assignedMergeRequestsModel,
            createdModel:
                createdMergeRequestsModel,
            reviewsModel:
                reviewRequestsModel,
            loader: mergeRequestLoader,
            approvalService:
                mergeRequestApprovalService,
            mergeService:
                mergeRequestMergeService,
            pipelineLoader:
                pipelineLoader,
            discussionLoader: discussionLoader,
            discussionMutator:
                discussionMutator,
            reactionService:
                reactionService,
            editService:
                editService,
            accountID: accountID,
            appSession: appSession,
            onResourceEdited:
                onResourceEdited,
            initialMode: initialMode
        )
    }

    private var readOnlyCallout: some View {
        Label(
            "Read-only · Changes disabled",
            systemImage: "eye.fill"
        )
        .font(.glabFootnote.weight(.medium))
        .foregroundStyle(Color.glabAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color.glabAccent.opacity(0.1),
            in: .rect(cornerRadius: 12)
        )
        .accessibilityLabel(
            "This token is read-only. Actions such as completing "
                + "Todos will be disabled."
        )
        .listRowInsets(
            .init(
                top: 4,
                leading: 20,
                bottom: 4,
                trailing: 20
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    private var displayedUser: GitLabUserSummary {
        guard let user = model.user else {
            return session.user
        }

        return GitLabUserSummary(
            id: user.id,
            username: user.username,
            name: user.name,
            avatarURL: user.avatarURL
        )
    }

    @ViewBuilder
    private func destination(
        for section: HomeDashboardSection
    ) -> some View {
        switch section {
        case .assignedIssues:
            YourIssuesView(
                assignedModel:
                    assignedIssuesModel,
                createdModel:
                    createdIssuesModel,
                loader: issueLoader,
                discussionLoader: discussionLoader,
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
        case .assignedMergeRequests:
            mergeRequestsDestination(
                initialMode: .assigned
            )
        case .recentProjects:
            ProjectsView(
                mode: .recent,
                loader: projectLoader,
                accountID: accountID,
                appSession: appSession,
                projectStarChange:
                    projectStarChange
            )
        case .starredProjects:
            ProjectsView(
                mode: .starred,
                loader: projectLoader,
                accountID: accountID,
                appSession: appSession,
                projectStarChange:
                    projectStarChange
            )
        }
    }

    private func loadDashboard() async {
        async let home: Void = model.loadIfNeeded()
        async let mergeRequests: Void =
            assignedMergeRequestsModel.loadIfNeeded()
        async let reviews: Void =
            reviewRequestsModel.loadIfNeeded()
        async let issues: Void =
            assignedIssuesModel.loadIfNeeded()
        async let projects: Void =
            projectsModel.loadIfNeeded()
        _ = await (
            home,
            mergeRequests,
            reviews,
            issues,
            projects
        )
        await handleAuthenticationFailure()
    }

    private func refreshDashboard() async {
        async let home: Void = model.refresh()
        async let mergeRequests: Void =
            assignedMergeRequestsModel.refresh()
        async let reviews: Void =
            reviewRequestsModel.refresh()
        async let issues: Void =
            assignedIssuesModel.refresh()
        async let projects: Void =
            projectsModel.refresh()
        _ = await (
            home,
            mergeRequests,
            reviews,
            issues,
            projects
        )
        await handleAuthenticationFailure()
    }

    private func handleAuthenticationFailure() async {
        guard
            let error =
                model.authenticationFailure
                ?? assignedMergeRequestsModel
                .authenticationFailure
                ?? reviewRequestsModel
                .authenticationFailure
                ?? assignedIssuesModel
                .authenticationFailure
                ?? projectsModel.authenticationFailure
        else {
            return
        }

        await appSession.handleAuthenticationFailure(
            error,
            for: accountID
        )
    }
}
