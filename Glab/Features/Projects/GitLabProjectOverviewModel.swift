import Foundation
import Observation

enum GitLabProjectOverviewSection<Value> {
    case loading
    case loaded(Value)
    case failed

    mutating func failIfLoading() {
        if case .loading = self {
            self = .failed
        }
    }
}

@MainActor
@Observable
final class GitLabProjectOverviewModel {
    static let recentCommitLimit = 5

    private(set) var languages:
        GitLabProjectOverviewSection<
            [GitLabProjectLanguage]
        > = .loading
    private(set) var commits:
        GitLabProjectOverviewSection<
            [GitLabCommit]
        > = .loading
    private(set) var latestPipeline:
        GitLabProjectOverviewSection<
            GitLabPipeline?
        > = .loading
    private(set) var openMergeRequestCount:
        GitLabProjectOverviewSection<Int?> =
        .loading
    private(set) var branchCount:
        GitLabProjectOverviewSection<Int?> =
        .loading
    private(set) var releaseCount:
        GitLabProjectOverviewSection<Int?> =
        .loading
    private(set) var authenticationFailure:
        GitLabSessionClientError?

    @ObservationIgnored
    private let project: GitLabProject
    @ObservationIgnored
    private let overviewLoader:
        any GitLabProjectOverviewLoading
    @ObservationIgnored
    private let commitLoader:
        any GitLabCommitLoading
    @ObservationIgnored
    private let isAccountCurrent:
        @MainActor () -> Bool
    @ObservationIgnored
    private var hasStarted = false

    init(
        project: GitLabProject,
        overviewLoader:
            any GitLabProjectOverviewLoading,
        commitLoader: any GitLabCommitLoading,
        isAccountCurrent:
            @escaping @MainActor () -> Bool
    ) {
        self.project = project
        self.overviewLoader = overviewLoader
        self.commitLoader = commitLoader
        self.isAccountCurrent = isAccountCurrent
    }

    func loadIfNeeded() async {
        guard !hasStarted else {
            return
        }
        hasStarted = true
        await loadAll()
    }

    func refresh() async {
        hasStarted = true
        await loadAll()
    }

    private func loadAll() async {
        async let languages: Void = loadLanguages()
        async let commits: Void = loadCommits()
        async let pipeline: Void = loadLatestPipeline()
        async let mergeRequests: Void =
            loadOpenMergeRequestCount()
        async let branches: Void = loadBranchCount()
        async let releases: Void = loadReleaseCount()
        _ = await (
            languages,
            commits,
            pipeline,
            mergeRequests,
            branches,
            releases
        )
    }

    private func loadBranchCount() async {
        do throws(GitLabSessionClientError) {
            let value =
                try await overviewLoader
                .loadBranchCount(projectID: project.id)
            guard isAccountCurrent() else {
                return
            }
            branchCount = .loaded(value)
        } catch {
            record(error) {
                branchCount.failIfLoading()
            }
        }
    }

    private func loadReleaseCount() async {
        do throws(GitLabSessionClientError) {
            let value =
                try await overviewLoader
                .loadReleaseCount(projectID: project.id)
            guard isAccountCurrent() else {
                return
            }
            releaseCount = .loaded(value)
        } catch {
            record(error) {
                releaseCount.failIfLoading()
            }
        }
    }

    private func loadLanguages() async {
        do throws(GitLabSessionClientError) {
            let value =
                try await overviewLoader
                .loadLanguages(projectID: project.id)
            guard isAccountCurrent() else {
                return
            }
            languages = .loaded(value)
        } catch {
            record(error) {
                languages.failIfLoading()
            }
        }
    }

    private func loadCommits() async {
        do throws(GitLabSessionClientError) {
            let page =
                try await commitLoader
                .loadCommitsPage(
                    projectID: project.id,
                    refName: nil,
                    after: nil
                )
            guard isAccountCurrent() else {
                return
            }
            commits = .loaded(
                Array(
                    page.commits.prefix(
                        Self.recentCommitLimit
                    )
                )
            )
        } catch {
            record(error) {
                commits.failIfLoading()
            }
        }
    }

    private func loadLatestPipeline() async {
        do throws(GitLabSessionClientError) {
            let value =
                try await overviewLoader
                .loadLatestPipeline(
                    projectID: project.id
                )
            guard isAccountCurrent() else {
                return
            }
            latestPipeline = .loaded(value)
        } catch {
            record(error) {
                latestPipeline.failIfLoading()
            }
        }
    }

    private func loadOpenMergeRequestCount() async {
        do throws(GitLabSessionClientError) {
            let value =
                try await overviewLoader
                .loadOpenMergeRequestCount(
                    projectID: project.id
                )
            guard isAccountCurrent() else {
                return
            }
            openMergeRequestCount = .loaded(value)
        } catch {
            record(error) {
                openMergeRequestCount.failIfLoading()
            }
        }
    }

    private func record(
        _ error: GitLabSessionClientError,
        markFailed: () -> Void
    ) {
        guard isAccountCurrent() else {
            return
        }
        if error.requiresReauthentication {
            authenticationFailure = error
        }
        markFailed()
    }
}
