import Foundation
import Observation

typealias GitLabRepositoryDirectoryModel =
    GitLabPaginatedResourceModel<
        GitLabRepositoryEntry,
        String
    >

extension GitLabPaginatedResourceModel
where
    Item == GitLabRepositoryEntry,
    Identity == String
{
    convenience init(
        projectID: Int,
        ref: String,
        path: String,
        loader: any GitLabRepositoryBrowsing
    ) {
        self.init(
            loadPage: {
                (nextPageURL: URL?) async throws(
                    GitLabSessionClientError
                ) -> GitLabResourcePage<
                    GitLabRepositoryEntry
                > in
                let page = try await loader
                    .loadTreePage(
                        projectID: projectID,
                        ref: ref,
                        path: path,
                        after: nextPageURL
                    )
                return GitLabResourcePage(
                    items: page.entries,
                    nextPageURL:
                        page.nextPageURL
                )
            },
            loadFirstPage: {
                (
                    refreshBehavior:
                        GitLabCacheRefreshBehavior,
                    onPage:
                        @escaping @Sendable (
                            GitLabResourcePageEvent<
                                GitLabRepositoryEntry
                            >
                        ) async -> Void
                ) async throws(
                    GitLabSessionClientError
                ) -> Void in
                try await loader
                    .loadTreeFirstPage(
                        projectID: projectID,
                        ref: ref,
                        path: path,
                        refreshBehavior:
                            refreshBehavior,
                        onPage: onPage
                    )
            },
            identity: \GitLabRepositoryEntry.id,
            searchValues: {
                [$0.name, $0.path]
            }
        )
    }

    var sortedRepositoryEntries:
        [GitLabRepositoryEntry]
    {
        displayedItems.sorted {
            if
                $0.sortPriority
                    != $1.sortPriority
            {
                return $0.sortPriority
                    < $1.sortPriority
            }
            return $0.name.localizedStandardCompare(
                $1.name
            ) == .orderedAscending
        }
    }
}

typealias GitLabRepositoryBranchesModel =
    GitLabPaginatedResourceModel<
        GitLabRepositoryBranch,
        String
    >

extension GitLabPaginatedResourceModel
where
    Item == GitLabRepositoryBranch,
    Identity == String
{
    convenience init(
        projectID: Int,
        defaultBranchName: String? = nil,
        search: String? = nil,
        loader: any GitLabRepositoryBrowsing
    ) {
        self.init(
            loadPage: {
                (nextPageURL: URL?) async throws(
                    GitLabSessionClientError
                ) -> GitLabResourcePage<
                    GitLabRepositoryBranch
                > in
                let page = try await loader
                    .loadBranchesPage(
                        projectID: projectID,
                        search: search,
                        after: nextPageURL
                    )
                return GitLabResourcePage(
                    items: page.branches,
                    nextPageURL:
                        page.nextPageURL
                )
            },
            loadFirstPage: {
                (
                    _:
                        GitLabCacheRefreshBehavior,
                    onPage:
                        @escaping @Sendable (
                            GitLabResourcePageEvent<
                                GitLabRepositoryBranch
                            >
                        ) async -> Void
                ) async throws(
                    GitLabSessionClientError
                ) -> Void in
                let loadedPage = try await loader
                    .loadBranchesPage(
                        projectID: projectID,
                        search: search,
                        after: nil
                    )
                var branches = loadedPage.branches
                if
                    !branches.contains(
                        where: \.isDefault
                    ),
                    let defaultBranch = await loader
                        .loadDefaultBranchIfAvailable(
                            projectID: projectID,
                            name: defaultBranchName
                        )
                {
                    branches.removeAll {
                        $0.name == defaultBranch.name
                    }
                    branches.insert(defaultBranch, at: 0)
                }
                await onPage(
                    GitLabResourcePageEvent(
                        page: GitLabResourcePage(
                            items: branches,
                            nextPageURL:
                                loadedPage.nextPageURL
                        ),
                        source: .network
                    )
                )
            },
            identity: \GitLabRepositoryBranch.name,
            searchValues: { [$0.name] }
        )
    }

    var sortedRepositoryBranches:
        [GitLabRepositoryBranch]
    {
        displayedItems.sorted {
            if $0.isDefault != $1.isDefault {
                return $0.isDefault
            }
            return $0.name.localizedStandardCompare(
                $1.name
            ) == .orderedAscending
        }
    }
}

private extension GitLabRepositoryBrowsing {
    func loadDefaultBranchIfAvailable(
        projectID: Int,
        name: String?
    ) async -> GitLabRepositoryBranch? {
        guard let name, !name.isEmpty else {
            return nil
        }
        return try? await loadBranch(
            projectID: projectID,
            name: name
        )
    }
}

@MainActor
@Observable
final class GitLabRepositorySearchModel {
    private(set) var results:
        [GitLabRepositorySearchResult] = []
    private(set) var nextPageURL: URL?
    private(set) var error:
        GitLabSessionClientError?
    private(set) var isSearching = false
    private(set) var isLoadingNextPage = false
    private(set) var didSearch = false

    private let projectID: Int
    private let ref: String
    private let loader:
        any GitLabRepositoryBrowsing
    private var currentQuery = ""

    init(
        projectID: Int,
        ref: String,
        loader: any GitLabRepositoryBrowsing
    ) {
        self.projectID = projectID
        self.ref = ref
        self.loader = loader
    }

    var authenticationFailure:
        GitLabSessionClientError?
    {
        guard
            error?.requiresReauthentication
                == true
        else {
            return nil
        }
        return error
    }

    func search(_ query: String) async {
        let query = query.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !query.isEmpty else {
            clear()
            return
        }

        currentQuery = query
        isSearching = true
        isLoadingNextPage = false
        error = nil
        nextPageURL = nil
        results = []
        didSearch = false

        do {
            let page = try await loader
                .loadSearchPage(
                    projectID: projectID,
                    ref: ref,
                    query: query,
                    after: nil
                )
            guard
                !Task.isCancelled,
                currentQuery == query
            else {
                return
            }
            results = Self.deduplicated(
                page.results
            )
            nextPageURL = page.nextPageURL
            didSearch = true
        } catch {
            guard
                !Task.isCancelled,
                currentQuery == query
            else {
                return
            }
            self.error = error
            didSearch = true
        }
        if currentQuery == query {
            isSearching = false
        }
    }

    func loadNextPageIfNeeded(
        after result:
            GitLabRepositorySearchResult
    ) async {
        guard
            results.last?.id == result.id,
            let nextPageURL,
            !isSearching,
            !isLoadingNextPage
        else {
            return
        }

        isLoadingNextPage = true
        error = nil
        let query = currentQuery
        do {
            let page = try await loader
                .loadSearchPage(
                    projectID: projectID,
                    ref: ref,
                    query: query,
                    after: nextPageURL
                )
            guard
                !Task.isCancelled,
                currentQuery == query
            else {
                return
            }
            results = Self.deduplicated(
                results + page.results
            )
            self.nextPageURL =
                page.nextPageURL
        } catch {
            guard
                !Task.isCancelled,
                currentQuery == query
            else {
                return
            }
            self.error = error
        }
        if currentQuery == query {
            isLoadingNextPage = false
        }
    }

    func retry() async {
        await search(currentQuery)
    }

    private func clear() {
        currentQuery = ""
        results = []
        nextPageURL = nil
        error = nil
        isSearching = false
        isLoadingNextPage = false
        didSearch = false
    }

    private static func deduplicated(
        _ results:
            [GitLabRepositorySearchResult]
    ) -> [GitLabRepositorySearchResult] {
        var seen: Set<String> = []
        return results.filter {
            seen.insert($0.id).inserted
        }
    }
}

@MainActor
@Observable
final class GitLabRepositoryFileModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(GitLabSourceDocument)
        case failed(
            GitLabRepositorySourceLoadError
        )
    }

    private(set) var state: State = .idle

    private let route:
        GitLabRepositoryFileRoute
    private let loader:
        any GitLabRepositorySourceLoading

    init(
        route: GitLabRepositoryFileRoute,
        loader:
            any GitLabRepositorySourceLoading
    ) {
        self.route = route
        self.loader = loader
    }

    var authenticationFailure:
        GitLabSessionClientError?
    {
        guard
            case let .failed(error) = state
        else {
            return nil
        }
        return error.authenticationFailure
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }
        await load()
    }

    func retry() async {
        await load()
    }

    private func load() async {
        state = .loading
        do {
            let document = try await loader
                .loadSource(at: route)
            guard !Task.isCancelled else {
                return
            }
            state = .loaded(document)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            state = .failed(error)
        }
    }
}

nonisolated struct GitLabRepositoryTag:
    Decodable,
    Equatable,
    Identifiable,
    Sendable
{
    let name: String
    let message: String?
    let commitID: String?

    var id: String { name }

    var shortCommitID: String? {
        guard
            let commitID,
            commitID.count > 8
        else {
            return commitID
        }
        return String(commitID.prefix(8))
    }

    private enum CodingKeys: String, CodingKey {
        case name
        case message
        case targetCommit = "target_commit"
    }

    init(
        name: String,
        message: String?,
        commitID: String?
    ) {
        self.name = name
        self.message = message
        self.commitID = commitID
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(
            keyedBy: CodingKeys.self
        )
        name = try container.decode(
            String.self,
            forKey: .name
        )
        message = try container.decodeIfPresent(
            String.self,
            forKey: .message
        )
        // target_commit is a commit object in the API;
        // tolerate an object with "id" or a raw sha string.
        if let commitObject = try? container.nestedContainer(
            keyedBy: CommitObjectKey.self,
            forKey: .targetCommit
        ) {
            commitID = try commitObject.decodeIfPresent(
                String.self,
                forKey: .id
            )
        } else {
            commitID = try container.decodeIfPresent(
                String.self,
                forKey: .targetCommit
            )
        }
    }

    private enum CommitObjectKey: String, CodingKey {
        case id
    }
}

nonisolated struct GitLabRepositoryTagPage:
    Equatable,
    Sendable
{
    let tags: [GitLabRepositoryTag]
    let nextPageURL: URL?
}

typealias GitLabRepositoryTagsModel =
    GitLabPaginatedResourceModel<
        GitLabRepositoryTag,
        String
    >

extension GitLabPaginatedResourceModel
where
    Item == GitLabRepositoryTag,
    Identity == String
{
    convenience init(
        projectID: Int,
        loader: any GitLabRepositoryBrowsing
    ) {
        self.init(
            loadPage: {
                (nextPageURL: URL?) async throws(
                    GitLabSessionClientError
                ) -> GitLabResourcePage<
                    GitLabRepositoryTag
                > in
                let page = try await loader
                    .loadTagsPage(
                        projectID: projectID,
                        after: nextPageURL
                    )
                return GitLabResourcePage(
                    items: page.tags,
                    nextPageURL:
                        page.nextPageURL
                )
            },
            loadFirstPage: {
                (
                    _:
                        GitLabCacheRefreshBehavior,
                    onPage:
                        @escaping @Sendable (
                            GitLabResourcePageEvent<
                                GitLabRepositoryTag
                            >
                        ) async -> Void
                ) async throws(
                    GitLabSessionClientError
                ) -> Void in
                let loadedPage = try await loader
                    .loadTagsPage(
                        projectID: projectID,
                        after: nil
                    )
                await onPage(
                    GitLabResourcePageEvent(
                        page: GitLabResourcePage(
                            items: loadedPage.tags,
                            nextPageURL:
                                loadedPage
                                .nextPageURL
                        ),
                        source: .network
                    )
                )
            },
            identity: \GitLabRepositoryTag.name,
            searchValues: { [$0.name] }
        )
    }
}
