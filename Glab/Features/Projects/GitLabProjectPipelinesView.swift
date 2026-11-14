import SwiftUI

struct GitLabProjectPipelinesView: View {
    let pipelineLoader: any GitLabPipelineLoading
    let accountID: GitLabAccountID
    let appSession: AppSession
    let apiAccess: GitLabAPIAccess
    let isAccountCurrent:
        @MainActor () -> Bool

    @State private var model:
        GitLabProjectPipelinesModel

    init(
        project: GitLabProject,
        overviewLoader:
            any GitLabProjectOverviewLoading,
        pipelineLoader: any GitLabPipelineLoading,
        accountID: GitLabAccountID,
        appSession: AppSession,
        apiAccess: GitLabAPIAccess,
        isAccountCurrent:
            @escaping @MainActor () -> Bool
    ) {
        self.pipelineLoader = pipelineLoader
        self.accountID = accountID
        self.appSession = appSession
        self.apiAccess = apiAccess
        self.isAccountCurrent = isAccountCurrent
        _model = State(
            initialValue:
                GitLabProjectPipelinesModel(
                    accountID: accountID,
                    projectID: project.id,
                    loader: overviewLoader,
                    isAccountCurrent:
                        isAccountCurrent
                )
        )
    }

    var body: some View {
        GlabList {
            pipelineRows
        }
        .listStyle(.plain)
        .navigationTitle("Pipelines")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier(
            "project.pipelines.list"
        )
        .refreshable {
            await model.refresh()
            await handleAuthenticationFailure()
        }
        .task {
            await model.loadIfNeeded()
            await handleAuthenticationFailure()
        }
    }

    @ViewBuilder
    private var pipelineRows: some View {
        let pipelines = model.pipelines

        if
            pipelines.didFailRefresh,
            let error = pipelines.loadError
        {
            GitLabInlineRetryRow(
                title:
                    "Couldn’t refresh pipelines",
                error: error,
                accessibilityIdentifier:
                    "project.pipelines.refreshError"
            ) {
                Task {
                    await model.refresh()
                    await handleAuthenticationFailure()
                }
            }
        }

        if
            pipelines.items.isEmpty,
            pipelines.isLoadingInitial
        {
            loadingRow("Loading pipelines…")
        } else if
            pipelines.items.isEmpty,
            let error = pipelines.loadError
        {
            GitLabInlineRetryRow(
                title:
                    "Couldn’t load pipelines",
                error: error,
                accessibilityIdentifier:
                    "project.pipelines.loadError"
            ) {
                Task {
                    await model.refresh()
                    await handleAuthenticationFailure()
                }
            }
        } else if
            pipelines.items.isEmpty,
            pipelines.hasLoaded
        {
            GitLabEmptyStateView(
                title: "No pipelines",
                message:
                    "This project has no pipelines yet.",
                gitLabIcon: .pipeline
            )
            .listRowBackground(Color.clear)
            .accessibilityIdentifier(
                "project.pipelines.empty"
            )
        } else {
            ForEach(pipelines.items) { pipeline in
                if
                    let route =
                        GitLabPipelineRoute(
                            projectID:
                                model.projectID,
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
                    }
                    .accessibilityIdentifier(
                        "project.pipelines.row.\(pipeline.id)"
                    )
                    .task {
                        await model
                            .loadNextPageIfNeeded(
                                after: pipeline
                            )
                        await handleAuthenticationFailure()
                    }
                }
            }
        }

        if pipelines.isLoadingNextPage {
            loadingRow("Loading more…")
        } else if
            pipelines.didFailNextPage,
            let error = pipelines.loadError
        {
            GitLabInlineRetryRow(
                title:
                    "Couldn’t load more pipelines",
                error: error,
                accessibilityIdentifier:
                    "project.pipelines.nextPageError"
            ) {
                Task {
                    await model.retryNextPage()
                    await handleAuthenticationFailure()
                }
            }
        }
    }

    private func loadingRow(
        _ title: String
    ) -> some View {
        HStack {
            Spacer()
            ProgressView(title)
                .font(.glabFootnote)
            Spacer()
        }
        .listRowBackground(Color.clear)
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
