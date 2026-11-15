import SwiftUI

private enum HomeNavigationRoute: Hashable {
    case catchUp
    case search
    case reviews
    case pipelines
    case editHome
    case inbox
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
    let homePipelinesModel: HomePipelinesModel
    let homeLayoutModel: HomeLayoutModel
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
    let mergeRequestCreationService:
        any GitLabMergeRequestCreationServing
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
    let inboxModel: GitLabInboxModel
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
    @State private var isEditingHome = false
    @State private var homeEditDraftLayout =
        HomeLayout.initial

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
                    overviewModulesSection
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
                case .inbox:
                    inboxView
                case .reviews:
                    mergeRequestsDestination(
                        initialMode: .reviewRequested
                    )
                case .pipelines:
                    HomePipelinesView(
                        model: homePipelinesModel,
                        loader: homePipelinesModel
                            .loaderDescription,
                        pipelineLoader:
                            pipelineLoader,
                        accountID: accountID,
                        appSession: appSession,
                        apiAccess:
                            session.apiAccess
                    )
                case .editHome:
                    HomeEditSheet(
                        layout: homeEditDraftLayout,
                        onCancel: {
                            path.removeLast()
                        },
                        onSave: { layout in
                            homeLayoutModel.save(
                                layout
                            )
                            path.removeLast()
                        }
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
                    editHomeToolbarButton
                    searchToolbarButton
                    newIssueToolbarButton
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
        .onAppear {
            homeEditDraftLayout =
                homeLayoutModel.layout
        }
        .sheet(isPresented: $isEditingHome) {
            HomeEditSheet(
                layout: homeEditDraftLayout,
                onCancel: {
                    isEditingHome = false
                },
                onSave: { layout in
                    homeLayoutModel.save(layout)
                    isEditingHome = false
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var editHomeToolbarButton: some View {
        Button {
            homeEditDraftLayout =
                homeLayoutModel.layout
            isEditingHome = true
        } label: {
            Image(systemName: "slider.horizontal.3")
        }
        .accessibilityLabel("Edit Home")
        .accessibilityHint(
            "Rearrange or hide Home modules."
        )
        .accessibilityIdentifier(
            "home.editHomeButton"
        )
    }

    private var searchToolbarButton: some View {
        Button {
            openSearch()
        } label: {
            Image(systemName: "magnifyingglass")
        }
        .accessibilityLabel("Search GitLab")
        .accessibilityHint(
            "Searches projects, issues, "
                + "and merge requests."
        )
        .accessibilityIdentifier(
            "home.searchButton"
        )
    }

    private var newIssueToolbarButton: some View {
        Button {
            launchIssueCreation()
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel("New issue")
        .accessibilityHint(
            "Opens the issue composer."
        )
        .accessibilityIdentifier(
            "home.newIssueButton"
        )
    }

    @MainActor
    private func openSearch() {
        path.append(HomeNavigationRoute.search)
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
                mergeRequestCreationService:
                    mergeRequestCreationService,
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

    /// Horizontally scrolling row of stat tiles; the last tile peeks past
    /// the trailing edge to hint at scroll, like the reference dashboard.
    /// The scroll view is expanded past the row inset so tile glow clips
    /// at the screen edge instead of at the row boundary.
    @ViewBuilder
    private func homeStatTiles(
        @ViewBuilder content: () -> some View
    ) -> some View {
        let rowInset: CGFloat = 4
        GlassEffectContainer(spacing: 8) {
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    content()
                }
                .padding(.horizontal, rowInset)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, -rowInset)
            .scrollIndicators(.hidden)
            .scrollBounceBehavior(.basedOnSize)
        }
    }

    /// Fixed-width tile slightly narrower than one column of the former
    /// 4-column grid so four tiles plus a sliver of the fifth fit in the
    /// row — the sliver peeks past the trailing edge to hint at scroll.
    private struct HomeStatTileButton<Label: View>: View {
        let action: () -> Void
        @ViewBuilder let label: () -> Label

        @Environment(\.dynamicTypeSize) private var dynamicTypeSize

        var body: some View {
            Button(action: action) {
                label()
                    .frame(
                        width: dynamicTypeSize.isAccessibilitySize
                            ? 220
                            : (UIScreen.main.bounds.width - 32) / 4
                            - 12
                    )
            }
            .buttonStyle(.plain)
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

            homeStatTiles {
                HomeStatTileButton(
                    action: {
                        path.append(
                            HomeDashboardSection
                                .assignedMergeRequests
                        )
                    },
                    label: {
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
                )
                .accessibilityIdentifier(
                    "home.tile.mergeRequests"
                )

                HomeStatTileButton(
                    action: {
                        path.append(
                            HomeNavigationRoute.reviews
                        )
                    },
                    label: {
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
                )
                .accessibilityIdentifier(
                    "home.tile.review"
                )

                HomeStatTileButton(
                    action: { onShowTodos() },
                    label: {
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
                )
                .accessibilityIdentifier(
                    "home.tile.todos"
                )

                HomeStatTileButton(
                    action: {
                        path.append(
                            HomeDashboardSection
                                .recentProjects
                        )
                    },
                    label: {
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
                )
                .accessibilityIdentifier(
                    "home.tile.projects"
                )

                HomeStatTileButton(
                    action: {
                        path.append(
                            HomeNavigationRoute
                                .pipelines
                        )
                    },
                    label: {
                        GitLabStatTile(
                            title: "CI",
                            tint: Color.red,
                            value: ciTileValue,
                            icon: {
                                Image(
                                    systemName:
                                        "chart.line.uptrend.xyaxis"
                                )
                            }
                        )
                    }
                )
                .accessibilityIdentifier(
                    "home.tile.ci"
                )
            }
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

    private var recentProjectItems:
        [GitLabHomeProject] {
        projectsModel.recentHomeProjects
    }

    private var starredProjectItems:
        [GitLabHomeProject] {
        projectsModel.starredHomeProjects
    }

    private var ciTileValue: String {
        let active =
            homePipelinesModel.activePipelines
            .count
        let failed =
            homePipelinesModel.failedPipelines.count
        let total = active + failed
        guard total > 0 else {
            return "0"
        }
        if failed > 0, active > 0 {
            return "\(total)"
        }
        return "\(failed > 0 ? failed : total)"
    }

    @ViewBuilder
    private var overviewModulesSection: some View {
        ForEach(
            homeLayoutModel.layout.shown,
            id: \.self
        ) { module in
            homeModuleSection(module)
        }
    }

    @ViewBuilder
    private func homeModuleSection(
        _ module: HomeModule
    ) -> some View {
        switch module {
        case .activePipelines:
            homePipelinesModule(
                .activePipelines,
                items:
                    homePipelinesModel
                    .activePipelines
            )
        case .failedPipelines:
            homePipelinesModule(
                .failedPipelines,
                items:
                    homePipelinesModel
                    .failedPipelines
            )
        case .recentPipelines:
            homePipelinesModule(
                .recentPipelines,
                items: homePipelinesModel.pipelines
            )
        case .recentProjects:
            recentProjectsModule
        case .starredProjects:
            starredProjectsModule
        case .assignedMergeRequests:
            assignedMergeRequestsModule
        case .myIssues:
            Section {
                if
                    assignedIssuesModel
                    .items.isEmpty
                {
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
                                GitLabNativeRoute
                                .issue(
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
                issuesModuleHeader
            }
        case .todos:
            Section {
                NavigationLink(
                    value:
                        HomeDashboardSection
                        .assignedMergeRequests
                ) {
                    HomeModuleEmptyCard(
                        title:
                            "\(todosModel.pendingBadgeCount ?? 0) pending"
                    )
                }
                .accessibilityIdentifier(
                    "home.module.todos"
                )
            } header: {
                HomeModuleHeader(
                    module: .todos,
                    countText: todosModel
                        .pendingBadgeCount
                        .map(String.init),
                    onSeeAll: onShowTodos
                )
            }
        }
    }

    private func homePipelinesModule(
        _ module: HomeModule,
        items: [GitLabHomePipeline]
    ) -> some View {
        Section {
            if
                homePipelinesModel.status == .failed,
                items.isEmpty
            {
                HomeModulePlaceholderCard()
            } else if
                homePipelinesModel.status == .loading,
                items.isEmpty
            {
                HomeModulePlaceholderCard(
                    isLoading: true
                )
            } else if items.isEmpty {
                HomeModuleEmptyCard(
                    title: "No items yet"
                )
            } else {
                HomeCarouselSection {
                    ForEach(items.prefix(4)) { item in
                        pipelineCardLink(item)
                    }
                }
            }
        } header: {
            HomeModuleHeader(
                module: module,
                countText: items.isEmpty ? nil
                    : "\(items.count)",
                onSeeAll: {
                    path.append(
                        HomeNavigationRoute
                            .pipelines
                    )
                }
            )
        }
    }

    private var recentProjectsModule: some View {
        Section {
            if recentProjectItems.isEmpty {
                HomeModulePlaceholderCard(
                    isLoading:
                        !model.hasLoaded
                )
            } else {
                HomeCarouselSection {
                    ForEach(
                        recentProjectItems.prefix(6)
                    ) { project in
                        NavigationLink(
                            value:
                                GitLabNativeRoute
                                .project(
                                    GitLabProjectRoute(
                                        pathWithNamespace:
                                            project
                                            .pathWithNamespace
                                    )
                                )
                        ) {
                            HomeProjectCard(
                                project: project
                            )
                        }
                        .accessibilityIdentifier(
                            "home.module.project.\(project.id)"
                        )
                    }
                }
            }
        } header: {
            HomeModuleHeader(
                module: .recentProjects,
                onSeeAll: {
                    path.append(
                        HomeDashboardSection
                            .recentProjects
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func pipelineCardLink(
        _ item: GitLabHomePipeline
    ) -> some View {
        if let route = item.route {
            NavigationLink {
                GitLabPipelineDetailView(
                    route: route,
                    cacheLifetime: item.pipeline
                        .detailCacheLifetime,
                    loader: pipelineLoader,
                    accountID: accountID,
                    appSession: appSession,
                    apiAccess: session.apiAccess
                )
            } label: {
                HomePipelineCard(item: item)
            }
            .accessibilityIdentifier(
                "home.module.pipeline.\(item.id)"
            )
        }
    }

    private var starredProjectsModule: some View {
        Section {
            if starredProjectItems.isEmpty {
                HomeModuleEmptyCard(
                    title: "No starred projects"
                )
            } else {
                HomeCarouselSection {
                    ForEach(
                        starredProjectItems.prefix(6)
                    ) { project in
                        NavigationLink(
                            value:
                                GitLabNativeRoute
                                .project(
                                    GitLabProjectRoute(
                                        pathWithNamespace:
                                            project
                                            .pathWithNamespace
                                    )
                                )
                        ) {
                            HomeProjectCard(
                                project: project
                            )
                        }
                        .accessibilityIdentifier(
                            "home.module.starred.\(project.id)"
                        )
                    }
                }
            }
        } header: {
            HomeModuleHeader(
                module: .starredProjects
            )
        }
    }

    private var assignedMergeRequestsModule:
        some View
    {
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
            mergeRequestsModuleHeader
        }
    }

    private var issuesModuleHeader: some View {
        HomeModuleHeader(
            module: .myIssues,
            countText: issuesModuleCount,
            onSeeAll: {
                path.append(
                    HomeDashboardSection
                        .assignedIssues
                )
            }
        )
    }

    private var mergeRequestsModuleHeader:
        some View
    {
        HomeModuleHeader(
            module: .assignedMergeRequests,
            countText:
                mergeRequestsModuleCount,
            onSeeAll: {
                path.append(
                    HomeNavigationRoute.inbox
                )
            }
        )
    }

    private var inboxView: some View {
        GitLabInboxView(
            session: session,
            accountID: accountID,
            appSession: appSession,
            model: inboxModel,
            issueLoader: issueLoader,
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
            onResourceEdited:
                onResourceEdited
        )
    }

    private var issuesModuleCount: String? {
        assignedIssuesModel.statCount.map(String.init)
    }

    private var mergeRequestsModuleCount: String? {
        assignedMergeRequestsModel.statCount.map(
            String.init
        )
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
        async let pipelineProbe: Void =
            homePipelinesModel.loadIfNeeded()
        _ = await (
            home,
            mergeRequests,
            reviews,
            issues,
            projects,
            pipelineProbe
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
        async let pipelineProbe: Void =
            homePipelinesModel.refresh()
        _ = await (
            home,
            mergeRequests,
            reviews,
            issues,
            projects,
            pipelineProbe
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
                ?? homePipelinesModel.loadError
        else {
            return
        }

        await appSession.handleAuthenticationFailure(
            error,
            for: accountID
        )
    }
}
