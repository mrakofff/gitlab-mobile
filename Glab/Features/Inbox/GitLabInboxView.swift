import SwiftUI

/// Inbox screen (phase 3): a unified feed of open merge requests
/// and issues with filter chips — All / Assigned / Mentioned /
/// Review requested / Build failed.
struct GitLabInboxView: View {
    let session: GitLabStoredSession
    let accountID: GitLabAccountID
    let appSession: AppSession
    let model: GitLabInboxModel
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
    let onResourceEdited:
        (GitLabResourceEditResult) -> Void

    var body: some View {
        GlabList {
            inboxSection
        }
        .listStyle(.insetGrouped)
        .background(Color.glabCanvas)
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(
            for: GitLabNativeRoute.self
        ) {
            nativeDestination(for: $0)
        }
        .refreshable {
            await model.refresh()
            await handleAuthenticationFailure()
        }
        .task {
            await model.loadIfNeeded()
            await handleAuthenticationFailure()
        }
        .safeAreaInset(
            edge: .top,
            spacing: 0
        ) {
            filterChips
        }
        .accessibilityIdentifier("inbox.screen")
    }

    @ViewBuilder
    private var inboxSection: some View {
        if model.isLoadingInitial,
            model.items.isEmpty
        {
            Section {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .accessibilityIdentifier(
                    "inbox.loading"
                )
            }
        } else if
            let loadError = model.loadError,
            model.items.isEmpty
        {
            Section {
                GitLabInlineRetryRow(
                    title: "Inbox could not be loaded.",
                    error: loadError,
                    accessibilityIdentifier:
                        "inbox.retry",
                    retry: {
                        Task {
                            await model.refresh()
                            await handleAuthenticationFailure()
                        }
                    }
                )
                .listRowBackground(Color.clear)
            }
        } else if model.items.isEmpty {
            Section {
                GitLabEmptyStateView(
                    title: model
                        .selectedFilter
                        .emptyTitle,
                    message: model
                        .selectedFilter
                        .emptyMessage,
                    gitLabIcon:
                        model.selectedFilter
                        .gitLabIcon
                )
                .listRowBackground(Color.clear)
                .accessibilityIdentifier(
                    "inbox.empty"
                )
            }
        } else {
            Section {
                ForEach(model.displayedItems) {
                    item in
                    NavigationLink(
                        value: item.nativeRoute
                    ) {
                        GitLabInboxRow(item: item)
                    }
                    .accessibilityIdentifier(
                        "inbox.\(item.isMergeRequest ? "mergeRequest" : "issue").\(item.projectID).\(item.iid)"
                    )
                }
            }
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(
                    GitLabInboxFilter.allCases,
                    id: \.self
                ) { filter in
                    chipButton(filter)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color.glabCanvas)
        .accessibilityIdentifier("inbox.filterChips")
    }

    private func chipButton(
        _ filter: GitLabInboxFilter
    ) -> some View {
        let isSelected =
            model.selectedFilter == filter

        return Button {
            model.select(filter)
        } label: {
            HStack(spacing: 5) {
                GitLabIconView(filter.gitLabIcon)
                Text(filter.title)
            }
            .font(
                .glabSubheadline.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                isSelected
                    ? Color.glabCanvas
                    : .secondary
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected
                    ? Color.glabAccent
                    : Color(
                        uiColor:
                            .tertiarySystemFill
                    ),
                in: .capsule
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(
            isSelected
                ? .isSelected
                : []
        )
        .accessibilityIdentifier(
            "inbox.chip.\(filter.rawValue)"
        )
    }

    @ViewBuilder
    private func nativeDestination(
        for route: GitLabNativeRoute
    ) -> some View {
        switch route {
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
        case let .mergeRequest(mergeRequestRoute):
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
        default:
            EmptyView()
        }
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error = model
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

private struct GitLabInboxRow: View {
    let item: GitLabInboxItem

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 4
        ) {
            HStack(spacing: 6) {
                statusBadge

                Spacer(minLength: 8)

                if let updatedAt = item.updatedAt {
                    Text(
                        GitLabRelativeTimeFormatter
                            .string(
                                from: updatedAt
                            )
                    )
                    .font(.glabCaption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }

            Text(item.title)
                .font(
                    .glabBody.weight(.medium)
                )
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(footer)
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            item.title + ", " + footer
        )
        .accessibilityHint(
            "Opens the native GitLab detail"
        )
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            GitLabIconView(icon)
                .foregroundStyle(iconTint)
            Text(badgeTitle)
        }
        .font(
            .glabCaption.weight(
                .semibold
            )
        )
        .foregroundStyle(iconTint)
    }

    private var badgeTitle: String {
        if item.isMergeRequest,
            item.hasFailedPipeline
        {
            return "Build failed"
        }
        if item.isDraft,
            item.isMergeRequest
        {
            return "Draft"
        }
        return item.stateTitle
    }

    private var icon: GitLabIcon {
        if item.isMergeRequest,
            item.hasFailedPipeline
        {
            return .pipelineFailed
        }
        if item.isMergeRequest {
            switch item.state {
            case "merged":
                return .merged
            case "closed":
                return .mergeRequestClosed
            default:
                return .mergeRequestOpen
            }
        }
        switch item.state {
        case "closed":
            return .issueClosed
        default:
            return .workItemIssue
        }
    }

    private var iconTint: Color {
        if item.isMergeRequest,
            item.hasFailedPipeline
        {
            return .red
        }
        switch item.state {
        case "merged":
            return .purple
        case "closed":
            return .secondary
        case "opened":
            return .green
        default:
            return .secondary
        }
    }

    private var footer: String {
        var parts: [String] = []
        if let detail = item.detail {
            parts.append(detail)
        }
        parts.append(item.reference)
        if let username = item.authorUsername {
            parts.append("@\(username)")
        }
        return parts.joined(
            separator: " · "
        )
    }
}
