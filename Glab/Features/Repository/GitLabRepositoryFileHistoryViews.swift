import SwiftUI

// MARK: - Shared timeline commit row

struct GitLabTimelineCommitRow: View {
    let commit: GitLabCommit
    let showConnector: Bool
    let tagNames: [String]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            timelineColumn

            VStack(alignment: .leading, spacing: 3) {
                Text(commit.title)
                    .font(
                        .glabSubheadline.weight(.semibold)
                    )
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(
                    "\(commit.authorName) · \(GitLabRelativeTimeFormatter.string(from: commit.authoredDate)) · \(commit.shortID)"
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

                if !tagNames.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(tagNames, id: \.self) {
                            tag in
                            GitLabTagBadge(name: tag)
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }

    private var timelineColumn: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.glabAccent)
                .frame(width: 8, height: 8)
            if showConnector {
                Rectangle()
                    .fill(
                        Color.glabAccent.opacity(0.25)
                    )
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 10)
        .padding(.top, 6)
        .accessibilityHidden(true)
    }
}

struct GitLabTagBadge: View {
    let name: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "tag.fill")
                .font(.caption2)
            Text(name)
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.purple, in: .capsule)
    }
}

// MARK: - File / project history

struct GitLabFileHistoryView: View {
    let projectID: Int
    let path: String?
    let ref: String
    let loader: any GitLabCommitLoading
    let accountID: GitLabAccountID
    let appSession: AppSession

    @State private var model:
        GitLabRepositoryFileHistoryModel

    init(
        projectID: Int,
        path: String?,
        ref: String,
        loader: any GitLabCommitLoading,
        accountID: GitLabAccountID,
        appSession: AppSession
    ) {
        self.projectID = projectID
        self.path = path
        self.ref = ref
        self.loader = loader
        self.accountID = accountID
        self.appSession = appSession
        _model = State(
            initialValue:
                GitLabRepositoryFileHistoryModel(
                    projectID: projectID,
                    ref: ref,
                    path: path,
                    loader: loader
                )
        )
    }

    var body: some View {
        content
            .background(Color.glabCanvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await refresh()
            }
            .task {
                await model.loadIfNeeded()
                await handleAuthenticationFailure()
            }
            .accessibilityIdentifier(
                "repository.fileHistory"
            )
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ScrollView {
                GitLabLoadingStateView(
                    message: "Loading history"
                )
                .padding(20)
            }
        case let .failed(error):
            GitLabContentStateScrollView {
                GitLabRetryStateView(error: error) {
                    Task {
                        await refresh()
                    }
                }
            }
        case .loaded:
            historyList
        }
    }

    private var historyList: some View {
        GlabList {
            if
                case let .loaded(groups) = model.state,
                groups.isEmpty
            {
                GitLabEmptyStateView(
                    title: "No commits",
                    message: "Nothing has touched this yet.",
                    systemImage: "clock.arrow.circlepath"
                )
                .listRowBackground(Color.clear)
            }

            dateSections

            paginationRows

            if path != nil {
                Text(
                    "History stops at the last rename of this file."
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private var dateSections: some View {
        if
            case let .loaded(groups) = model.state,
            !groups.isEmpty
        {
            ForEach(groups) { group in
                Section {
                    ForEach(
                        Array(
                            group.commits.enumerated()
                        ),
                        id: \.element.id
                    ) { index, commit in
                        NavigationLink {
                            GitLabCommitDetailView(
                                projectID: projectID,
                                commit: commit,
                                loader: loader,
                                accountID: accountID,
                                appSession: appSession
                            )
                        } label: {
                            GitLabTimelineCommitRow(
                                commit: commit,
                                showConnector:
                                    index
                                    < group.commits
                                    .count - 1,
                                tagNames: []
                            )
                        }
                        .task {
                            await model
                                .loadNextPageIfNeeded(
                                    after: group
                                )
                            await handleAuthenticationFailure()
                        }
                    }
                } header: {
                    Text(
                        GitLabCommitHistoryGrouper
                            .dayTitle(group.day)
                    )
                    .font(.glabFootnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                }
            }
        }
    }

    @ViewBuilder
    private var paginationRows: some View {
        if model.isLoadingNextPage {
            HStack {
                Spacer()
                ProgressView("Loading more…")
                    .font(.glabFootnote)
                Spacer()
            }
            .listRowBackground(Color.clear)
        } else if model.didFailNextPage {
            Button {
                Task {
                    await model.retryNextPage()
                    await handleAuthenticationFailure()
                }
            } label: {
                Text("Retry loading more")
                    .font(.glabFootnote)
            }
            .listRowBackground(Color.clear)
        }
    }

    private var title: String {
        path.map {
            URL(filePath: $0).lastPathComponent
        } ?? "History"
    }

    private func refresh() async {
        await model.retry()
        await handleAuthenticationFailure()
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

// MARK: - Commit log with tags

@MainActor
@Observable
final class GitLabCommitLogModel {
    enum State: Equatable {
        case idle
        case loading
        case loaded([GitLabCommit])
        case failed(GitLabSessionClientError)
    }

    private(set) var state: State = .idle
    private(set) var isLoadingNextPage = false
    private(set) var didFailNextPage = false
    private(set) var includesAllBranches = false
    private(set) var tagNamesByCommitID:
        [String: [String]] = [:]

    @ObservationIgnored
    private var nextPageURL: URL?
    @ObservationIgnored
    private let projectID: Int
    @ObservationIgnored
    private let refName: String?
    @ObservationIgnored
    private let commitLoader: any GitLabCommitLoading
    @ObservationIgnored
    private let repositoryLoader:
        any GitLabRepositoryBrowsing

    init(
        projectID: Int,
        refName: String?,
        commitLoader: any GitLabCommitLoading,
        repositoryLoader: any GitLabRepositoryBrowsing
    ) {
        self.projectID = projectID
        self.refName = refName
        self.commitLoader = commitLoader
        self.repositoryLoader = repositoryLoader
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

    func tagNames(for commit: GitLabCommit)
        -> [String]
    {
        tagNamesByCommitID[commit.id] ?? []
    }

    var displayedCommits: [GitLabCommit] {
        if case let .loaded(commits) = state {
            return commits
        }
        return []
    }

    func loadIfNeeded() async {
        guard state == .idle else {
            return
        }
        async let commits: Void = load()
        async let tags: Void = loadTags()
        _ = await (commits, tags)
    }

    func retry() async {
        await load()
        await loadTags()
    }

    func setAllBranches(_ all: Bool) async {
        guard all != includesAllBranches else {
            return
        }
        includesAllBranches = all
        await load()
    }

    func loadNextPageIfNeeded(
        after commit: GitLabCommit
    ) async {
        guard
            case let .loaded(commits) = state,
            commits.last?.id == commit.id,
            let nextPageURL,
            !isLoadingNextPage
        else {
            return
        }

        isLoadingNextPage = true
        didFailNextPage = false
        do {
            let page = try await commitLoader
                .loadCommitsPage(
                    projectID: projectID,
                    refName: refName,
                    path: nil,
                    all: includesAllBranches,
                    after: nextPageURL
                )
            guard !Task.isCancelled else {
                return
            }
            self.nextPageURL = page.nextPageURL
            if case let .loaded(existing) = state {
                state = .loaded(
                    existing + page.commits
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

    private func load() async {
        state = .loading
        nextPageURL = nil
        do {
            let page = try await commitLoader
                .loadCommitsPage(
                    projectID: projectID,
                    refName: refName,
                    path: nil,
                    all: includesAllBranches,
                    after: nil
                )
            guard !Task.isCancelled else {
                return
            }
            nextPageURL = page.nextPageURL
            state = .loaded(page.commits)
        } catch {
            guard !Task.isCancelled else {
                return
            }
            state = .failed(error)
        }
    }

    private func loadTags() async {
        guard tagNamesByCommitID.isEmpty else {
            return
        }
        do {
            let page = try await repositoryLoader
                .loadTagsPage(
                    projectID: projectID,
                    after: nil
                )
            guard !Task.isCancelled else {
                return
            }
            var mapping: [String: [String]] = [:]
            for tag in page.tags {
                guard
                    let commitID = tag.commitID
                else {
                    continue
                }
                mapping[commitID, default: []]
                    .append(tag.name)
            }
            tagNamesByCommitID = mapping
        } catch {
            // Tags are a decoration; failure is silent.
        }
    }
}

struct GitLabCommitLogView: View {
    let project: GitLabProject
    let commitLoader: any GitLabCommitLoading
    let repositoryLoader: any GitLabRepositoryBrowsing
    let accountID: GitLabAccountID
    let appSession: AppSession

    @State private var model: GitLabCommitLogModel

    init(
        project: GitLabProject,
        commitLoader: any GitLabCommitLoading,
        repositoryLoader: any GitLabRepositoryBrowsing,
        accountID: GitLabAccountID,
        appSession: AppSession
    ) {
        self.project = project
        self.commitLoader = commitLoader
        self.repositoryLoader = repositoryLoader
        self.accountID = accountID
        self.appSession = appSession
        _model = State(
            initialValue: GitLabCommitLogModel(
                projectID: project.id,
                refName: project.defaultBranch,
                commitLoader: commitLoader,
                repositoryLoader: repositoryLoader
            )
        )
    }

    var body: some View {
        content
            .background(Color.glabCanvas)
            .navigationTitle("Commit history")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable {
                await model.retry()
                await handleAuthenticationFailure()
            }
            .task {
                await model.loadIfNeeded()
                await handleAuthenticationFailure()
            }
            .accessibilityIdentifier(
                "commitLog.view"
            )
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ScrollView {
                GitLabLoadingStateView(
                    message: "Loading commits"
                )
                .padding(20)
            }
        case let .failed(error):
            GitLabContentStateScrollView {
                GitLabRetryStateView(error: error) {
                    Task {
                        await model.retry()
                        await handleAuthenticationFailure()
                    }
                }
            }
        case .loaded:
            commitLogList
        }
    }

    private var commitLogList: some View {
        GlabList {
            Section {
                HStack(spacing: 8) {
                    GitLabProjectBranchChip(
                        branch:
                            model.includesAllBranches
                            ? "all branches"
                            : branchName
                    )

                    Spacer(minLength: 8)

                    Toggle("All branches", isOn:
                        Binding(
                            get: {
                                model
                                    .includesAllBranches
                            },
                            set: { newValue in
                                Task {
                                    await model
                                        .setAllBranches(
                                            newValue
                                        )
                                    await handleAuthenticationFailure()
                                }
                            }
                        )
                    )
                    .labelsHidden()
                    .font(.glabCaption)
                }
            }
            .listRowBackground(Color.clear)

            if
                case let .loaded(commits) =
                    model.state,
                commits.isEmpty
            {
                GitLabEmptyStateView(
                    title: "No commits",
                    message:
                        "Nothing has been committed yet.",
                    systemImage:
                        "point.bottomleft.forward.to.point.topright.scurvepath"
                )
                .listRowBackground(Color.clear)
            }

            ForEach(
                model.displayedCommits
            ) { commit in
                NavigationLink {
                    GitLabCommitDetailView(
                        projectID: project.id,
                        commit: commit,
                        loader: commitLoader,
                        accountID: accountID,
                        appSession: appSession
                    )
                } label: {
                    GitLabTimelineCommitRow(
                        commit: commit,
                        showConnector: true,
                        tagNames: model
                            .tagNames(for: commit)
                    )
                }
                .task {
                    await model
                        .loadNextPageIfNeeded(
                            after: commit
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
            } else if model.didFailNextPage {
                Button {
                    Task {
                        await guardLastCommit()
                    }
                } label: {
                    Text("Retry loading more")
                        .font(.glabFootnote)
                }
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
    }

    private func guardLastCommit() async {
        guard
            case let .loaded(commits) =
                model.state,
            let last = commits.last
        else {
            return
        }
        await model.loadNextPageIfNeeded(
            after: last
        )
    }

    private var branchName: String {
        let trimmed = project.defaultBranch?
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        return (trimmed?.isEmpty == false)
            ? trimmed!
            : "default"
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

// MARK: - Blame sheet

struct GitLabBlameSheetView: View {
    let route: GitLabRepositoryFileRoute
    let loader: any GitLabRepositoryBrowsing
    let accountID: GitLabAccountID
    let appSession: AppSession

    @Environment(\.dismiss) private var dismiss
    @State private var model:
        GitLabRepositoryFileBlameModel

    init(
        route: GitLabRepositoryFileRoute,
        loader: any GitLabRepositoryBrowsing,
        accountID: GitLabAccountID,
        appSession: AppSession
    ) {
        self.route = route
        self.loader = loader
        self.accountID = accountID
        self.appSession = appSession
        _model = State(
            initialValue:
                GitLabRepositoryFileBlameModel(
                    projectID: route.projectID,
                    ref: route.ref,
                    path: route.path,
                    loader: loader
                )
        )
    }

    var body: some View {
        NavigationStack {
            content
                .background(Color.glabCanvas)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle("Blame")
                .toolbar {
                    ToolbarItem(
                        placement: .confirmationAction
                    ) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.large])
        .task {
            await model.loadIfNeeded()
            await handleAuthenticationFailure()
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ScrollView {
                GitLabLoadingStateView(
                    message: "Loading blame"
                )
                .padding(20)
            }
        case let .failed(error):
            GitLabContentStateScrollView {
                GitLabRetryStateView(error: error) {
                    Task {
                        await model.retry()
                        await handleAuthenticationFailure()
                    }
                }
            }
        case .loaded:
            blameList
        }
    }

    private var blameList: some View {
        GlabList {
            if
                case let .loaded(ranges) = model.state,
                ranges.isEmpty
            {
                GitLabEmptyStateView(
                    title: "No blame data",
                    message: "This file has no blame info.",
                    systemImage: "text.justify"
                )
                .listRowBackground(Color.clear)
            }

            if case let .loaded(ranges) = model.state {
                blameRows(ranges)
            }
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func blameRows(
        _ ranges: [GitLabBlameRange]
    ) -> some View {
        let entries = Self.blameEntries(ranges)
        ForEach(
            Array(entries.enumerated()),
            id: \.offset
        ) { _, entry in
            switch entry {
            case let .header(range):
                blameHeader(range)
                    .listRowInsets(
                        EdgeInsets(
                            top: 8,
                            leading: 12,
                            bottom: 2,
                            trailing: 12
                        )
                    )
            case let .line(number, text):
                HStack(
                    alignment: .firstTextBaseline
                ) {
                    Text(number)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.tertiary)
                        .frame(
                            minWidth: 30,
                            alignment: .trailing
                        )
                        .accessibilityHidden(true)
                    Text(text)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .listRowInsets(
                    EdgeInsets(
                        top: 1,
                        leading: 12,
                        bottom: 1,
                        trailing: 12
                    )
                )
            }
        }
    }

    private enum BlameEntry {
        case header(GitLabBlameRange)
        case line(String, String)
    }

    private static func blameEntries(
        _ ranges: [GitLabBlameRange]
    ) -> [BlameEntry] {
        var entries: [BlameEntry] = []
        var lineNumber = 1
        for range in ranges {
            entries.append(.header(range))
            for line in range.lines {
                entries.append(
                    .line("\(lineNumber)", line)
                )
                lineNumber += 1
            }
        }
        return entries
    }

    private func blameHeader(
        _ range: GitLabBlameRange
    ) -> some View {
        HStack(spacing: 8) {
            Text(range.commit.authorMark)
                .font(.glabCaption2.weight(.bold))
                .foregroundStyle(Color.glabAccent)
                .frame(width: 22, height: 22)
                .background(
                    Color.glabAccent.opacity(0.13),
                    in: .circle
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(range.commit.authorName)
                        .font(.glabCaption.weight(.semibold))
                        .lineLimit(1)
                    Text(range.commit.shortID)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Text(
                        GitLabRelativeTimeFormatter
                            .string(
                                from: range.commit
                                    .authoredDate
                            )
                    )
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                Text(range.commit.title)
                    .font(.glabCaption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
