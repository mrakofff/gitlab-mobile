import Foundation
import Observation

nonisolated protocol GitLabInboxLoading: Sendable {
    func loadInboxItems(
        for filter: GitLabInboxFilter
    ) async throws(GitLabSessionClientError)
        -> [GitLabInboxItem]
}

nonisolated struct LiveGitLabInboxLoader:
    GitLabInboxLoading,
    Sendable
{
    private let client:
        any GitLabSessionRequestSending

    init(client: any GitLabSessionRequestSending) {
        self.client = client
    }

    @concurrent
    func loadInboxItems(
        for filter: GitLabInboxFilter
    ) async throws(GitLabSessionClientError)
        -> [GitLabInboxItem]
    {
        switch filter {
        case .all:
            let mergeRequests = try await client
                .send(
                    GitLabInboxEndpoints
                        .mergeRequests(
                            scope: "assigned_to_me"
                        )
                )
            let issues = try await client.send(
                GitLabInboxEndpoints.issues(
                    scope: "assigned_to_me"
                )
            )
            let reviews = try await GitLabInboxItem
                .reviewRequestedItems(
                    client: client
                )
            let mentioned = try await GitLabInboxItem
                .mentionedItems(client: client)
            return GitLabInboxItem.mergedSortedByUpdatedAt(
                [
                    mergeRequests.map(GitLabInboxItem.init),
                    issues.map(GitLabInboxItem.init),
                    reviews,
                    mentioned,
                ]
            )
        case .assigned:
            let mergeRequests = try await client
                .send(
                    GitLabInboxEndpoints
                        .mergeRequests(
                            scope: "assigned_to_me"
                        )
                )
            let issues = try await client.send(
                GitLabInboxEndpoints.issues(
                    scope: "assigned_to_me"
                )
            )
            return GitLabInboxItem.mergedSortedByUpdatedAt(
                [
                    mergeRequests.map(GitLabInboxItem.init),
                    issues.map(GitLabInboxItem.init),
                ]
            )
        case .mentioned:
            return try await GitLabInboxItem
                .mentionedItems(client: client)
        case .reviewRequested:
            return try await GitLabInboxItem
                .reviewRequestedItems(client: client)
        case .buildFailed:
            let mergeRequests = try await client
                .send(
                    GitLabInboxEndpoints
                        .mergeRequests(
                            scope: "assigned_to_me"
                        )
                )
            return mergeRequests
                .map(GitLabInboxItem.init)
                .filter { $0.hasFailedPipeline }
        }
    }
}

@MainActor
@Observable
final class GitLabInboxModel {
    private(set) var items: [GitLabInboxItem] = []
    private(set) var selectedFilter:
        GitLabInboxFilter = .all
    {
        didSet {
            guard selectedFilter != oldValue else {
                return
            }
            Task {
                await reload()
            }
        }
    }
    private(set) var loadError:
        GitLabSessionClientError?
    private(set) var isLoadingInitial = false
    private(set) var isRefreshing = false
    private(set) var hasLoaded = false

    private var generation = 0

    var authenticationFailure: GitLabSessionClientError? {
        guard loadError?.requiresReauthentication == true else {
            return nil
        }
        return loadError
    }

    var displayedItems: [GitLabInboxItem] {
        items
    }

    func select(
        _ filter: GitLabInboxFilter
    ) {
        selectedFilter = filter
    }

    func loadIfNeeded() async {
        guard !hasLoaded else {
            return
        }
        await reload(showsInitialLoading: true)
    }

    func refresh() async {
        await reload(
            showsInitialLoading: items.isEmpty
        )
    }

    private func reload(
        showsInitialLoading: Bool = false
    ) async {
        guard
            !isLoadingInitial,
            !isRefreshing
        else {
            return
        }

        let currentGeneration = generation + 1
        generation = currentGeneration
        let filter = selectedFilter

        if showsInitialLoading {
            isLoadingInitial = true
        } else {
            isRefreshing = true
        }
        loadError = nil

        defer {
            isLoadingInitial = false
            isRefreshing = false
        }

        do {
            let loadedItems = try await loader
                .loadInboxItems(for: filter)
            guard
                generation == currentGeneration,
                filter == selectedFilter,
                !Task.isCancelled
            else {
                return
            }
            items = loadedItems
            hasLoaded = true
        } catch {
            guard
                !Task.isCancelled,
                error != .api(.cancelled),
                generation == currentGeneration
            else {
                return
            }
            loadError = error
            hasLoaded = true
        }
    }

    private let loader: any GitLabInboxLoading

    init(loader: any GitLabInboxLoading) {
        self.loader = loader
    }
}
