import Foundation
import Observation

nonisolated struct GitLabCommitDateGroup:
    Equatable,
    Identifiable,
    Sendable
{
    let day: Date
    let commits: [GitLabCommit]

    var id: Date {
        day
    }
}

nonisolated enum GitLabCommitHistoryGrouper {
    static func group(
        _ commits: [GitLabCommit],
        calendar: Calendar = .current
    ) -> [GitLabCommitDateGroup] {
        var groups: [GitLabCommitDateGroup] = []
        for commit in commits {
            let day = calendar.startOfDay(
                for: commit.authoredDate
            )
            if
                let last = groups.last,
                last.day == day
            {
                groups[groups.count - 1] = GitLabCommitDateGroup(
                    day: last.day,
                    commits: last.commits + [commit]
                )
            } else {
                groups.append(
                    GitLabCommitDateGroup(
                        day: day,
                        commits: [commit]
                    )
                )
            }
        }
        return groups
    }

    static func dayTitle(
        _ day: Date,
        calendar: Calendar = .current,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("dMMMM")
        return formatter.string(from: day)
    }
}

@MainActor
@Observable
final class GitLabRepositoryFileHistoryModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([GitLabCommitDateGroup])
        case failed(GitLabSessionClientError)
    }

    private(set) var state: State = .idle
    private(set) var isLoadingNextPage = false
    private(set) var nextPageURL: URL?
    private(set) var didFailNextPage = false

    private let projectID: Int
    private let ref: String
    private let path: String?
    private let loader: any GitLabCommitLoading

    init(
        projectID: Int,
        ref: String,
        path: String?,
        loader: any GitLabCommitLoading
    ) {
        self.projectID = projectID
        self.ref = ref
        self.path = path
        self.loader = loader
    }

    var authenticationFailure:
        GitLabSessionClientError?
    {
        guard
            case let .failed(error) = state,
            error.requiresReauthentication
        else {
            return nil
        }
        return error
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

    func loadNextPageIfNeeded(
        after group: GitLabCommitDateGroup
    ) async {
        guard
            case let .loaded(groups) = state,
            groups.last?.id == group.id,
            let nextPageURL,
            !isLoadingNextPage
        else {
            return
        }

        isLoadingNextPage = true
        didFailNextPage = false
        do {
            let page = try await loader.loadCommitsPage(
                projectID: projectID,
                refName: ref,
                path: path,
                all: false,
                after: nextPageURL
            )
            guard !Task.isCancelled else {
                return
            }
            self.nextPageURL = page.nextPageURL
            if case let .loaded(existingGroups) = state {
                state = .loaded(
                    GitLabCommitHistoryGrouper.group(
                        existingGroups.flatMap(\.commits)
                            + page.commits
                    )
                )
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }
            didFailNextPage = true
        }
        isLoadingNextPage = false
    }

    func retryNextPage() async {
        didFailNextPage = false
        await loadNextPageIfNeeded(
            after: lastGroupOrEmpty
        )
    }

    private var lastGroupOrEmpty: GitLabCommitDateGroup {
        guard
            case let .loaded(groups) = state,
            let last = groups.last
        else {
            return GitLabCommitDateGroup(
                day: .distantPast,
                commits: []
            )
        }
        return last
    }

    private func load() async {
        state = .loading
        do {
            let page = try await loader.loadCommitsPage(
                projectID: projectID,
                refName: ref,
                path: path,
                all: false,
                after: nil
            )
            guard !Task.isCancelled else {
                return
            }
            nextPageURL = page.nextPageURL
            state = .loaded(
                GitLabCommitHistoryGrouper.group(
                    page.commits
                )
            )
        } catch {
            guard !Task.isCancelled else {
                return
            }
            state = .failed(error)
        }
    }
}

@MainActor
@Observable
final class GitLabRepositoryFileBlameModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([GitLabBlameRange])
        case failed(GitLabSessionClientError)
    }

    private(set) var state: State = .idle

    private let projectID: Int
    private let ref: String
    private let path: String
    private let loader: any GitLabRepositoryBrowsing

    init(
        projectID: Int,
        ref: String,
        path: String,
        loader: any GitLabRepositoryBrowsing
    ) {
        self.projectID = projectID
        self.ref = ref
        self.path = path
        self.loader = loader
    }

    var authenticationFailure:
        GitLabSessionClientError?
    {
        guard
            case let .failed(error) = state,
            error.requiresReauthentication
        else {
            return nil
        }
        return error
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
            let ranges = try await loader.loadBlame(
                projectID: projectID,
                ref: ref,
                path: path
            )
            guard !Task.isCancelled else {
                return
            }
            state = .loaded(ranges)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            state = .failed(error)
        }
    }
}

@MainActor
@Observable
final class GitLabRepositoryLastCommitModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded(GitLabCommit, count: Int?)
        case failed(GitLabSessionClientError)
    }

    private(set) var state: State = .idle

    private let projectID: Int
    private let ref: String
    private let loader: any GitLabCommitLoading

    init(
        projectID: Int,
        ref: String,
        loader: any GitLabCommitLoading
    ) {
        self.projectID = projectID
        self.ref = ref
        self.loader = loader
    }

    var authenticationFailure:
        GitLabSessionClientError?
    {
        guard
            case let .failed(error) = state,
            error.requiresReauthentication
        else {
            return nil
        }
        return error
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }
        state = .loading
        do {
            let page = try await loader.loadCommitsPage(
                projectID: projectID,
                refName: ref,
                path: nil,
                all: false,
                after: nil
            )
            guard !Task.isCancelled else {
                return
            }
            if let commit = page.commits.first {
                state = .loaded(
                    commit,
                    count: page.nextPageURL == nil
                        ? page.commits.count
                        : nil
                )
            } else {
                state = .idle
            }
        } catch {
            guard !Task.isCancelled else {
                return
            }
            state = .failed(error)
        }
    }
}
