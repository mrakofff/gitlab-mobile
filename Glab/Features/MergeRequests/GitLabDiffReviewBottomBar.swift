import SwiftUI

/// Bottom review bar for the merge request diff screen: an Approve /
/// Remove approval action, a Merge (or auto-merge) action, and a comment
/// shortcut. Reuses the approval-management and merge models owned by the
/// merge request detail screen. Confirmation dialogs are drawn here
/// because the detail screen sits below this one in the navigation stack
/// and would not present its alerts while this view is on top; approval
/// failures stay as inline rows (they self-clear on the next request,
/// matching the approvals section on the detail screen).
struct GitLabDiffReviewBottomBar: View {
    let approvalManagementModel:
        GitLabMergeRequestApprovalManagementModel
    let mergeModel: GitLabMergeRequestMergeModel
    let apiAccess: GitLabAPIAccess
    let startComment: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            if let failure = approvalManagementModel.failure
            {
                Label(
                    failure.userMessage,
                    systemImage: "exclamationmark.circle"
                )
                .font(.glabCaption)
                .foregroundStyle(.orange)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(
                    "mergeRequestDiffs.review.approvalFailure"
                )
            }

            HStack(spacing: 10) {
                if apiAccess.canWrite {
                    commentButton
                }
                approvalButton
                mergeButton
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(.bar)
        .alert(
            approvalConfirmationTitle,
            isPresented: approvalConfirmationIsPresented
        ) {
            Button(approvalConfirmationActionTitle) {
                Task {
                    await approvalManagementModel
                        .confirmAction()
                }
            }
            .accessibilityIdentifier(
                "mergeRequestDiffs.review.approveConfirm"
            )
            Button("Cancel", role: .cancel) {
                approvalManagementModel
                    .cancelConfirmation()
            }
        } message: {
            Text(approvalConfirmationMessage)
        }
        .alert(
            mergeConfirmationTitle,
            isPresented: mergeConfirmationIsPresented
        ) {
            if let confirmation = mergeModel.confirmation {
                Button(confirmation.action.title) {
                    Task {
                        await mergeModel.confirm()
                    }
                }
                .accessibilityIdentifier(
                    "mergeRequestDiffs.review.mergeConfirm"
                )
            }
            Button("Cancel", role: .cancel) {
                mergeModel.dismissConfirmation()
            }
        } message: {
            Text(mergeConfirmationMessage)
        }
        .alert(
            "Couldn’t merge request",
            isPresented: mergeFailureIsPresented
        ) {
            Button("OK", role: .cancel) {
                mergeModel.dismissFailure()
            }
        } message: {
            Text(mergeModel.failure?.message ?? "")
        }
        .onDisappear {
            if approvalManagementModel.confirmation != nil {
                approvalManagementModel
                    .cancelConfirmation()
            }
        }
    }

    private var commentButton: some View {
        Button(action: startComment) {
            Image(systemName: "bubble.left")
                .font(.glabBody)
                .frame(width: 40, height: 38)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("Comment on merge request")
        .accessibilityIdentifier(
            "mergeRequestDiffs.review.comment"
        )
    }

    @ViewBuilder
    private var approvalButton: some View {
        if approvalManagementModel.isBusy {
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text(
                    Self.phaseTitle(
                        approvalManagementModel.phase
                    )
                )
                .font(.glabSubheadline.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        } else if approvalManagementModel.canUnapprove {
            Button {
                approvalManagementModel.requestUnapprove()
            } label: {
                reviewLabel(
                    title: "Approved",
                    systemImage: "checkmark.circle.fill",
                    isProminent: false
                )
            }
            .buttonStyle(.glass)
            .tint(.green)
            .accessibilityLabel("Remove approval")
            .accessibilityIdentifier(
                "mergeRequestDiffs.review.unapprove"
            )
        } else if approvalManagementModel
            .requiresGitLabReauthenticationForApproval
        {
            Button {} label: {
                reviewLabel(
                    title: "Sign in required",
                    systemImage: "lock.fill",
                    isProminent: false
                )
            }
            .buttonStyle(.glass)
            .disabled(true)
            .accessibilityIdentifier(
                "mergeRequestDiffs.review.reauthentication"
            )
        } else if approvalManagementModel.canApprove {
            Button {
                approvalManagementModel.requestApprove()
            } label: {
                reviewLabel(
                    title: "Approve",
                    systemImage: "checkmark.circle",
                    isProminent: true
                )
            }
            .buttonStyle(.glassProminent)
            .tint(.green)
            .accessibilityIdentifier(
                "mergeRequestDiffs.review.approve"
            )
        }
    }

    @ViewBuilder
    private var mergeButton: some View {
        switch mergeModel.eligibility {
        case .mergeNow:
            mergeActionButton(for: .mergeNow)
        case .autoMerge:
            mergeActionButton(for: .autoMerge)
        case .alreadyAutoMerging:
            reviewLabel(
                title: "Auto-merge set",
                systemImage: "clock.badge.checkmark",
                isProminent: false
            )
        case .checking, .unavailable:
            reviewLabel(
                title: "Merge",
                systemImage: "arrow.triangle.merge",
                isProminent: true
            )
            .opacity(0.5)
        case let .blocked(reasons):
            mergeBlockedButton(reasons: reasons)
        }
    }

    private func mergeActionButton(
        for action: GitLabMergeRequestMergeAction
    ) -> some View {
        Button {
            Task {
                await mergeModel.request(action)
            }
        } label: {
            reviewLabel(
                title: action.title,
                systemImage: action == .mergeNow
                    ? "arrow.triangle.merge"
                    : "clock.arrow.circlepath",
                isProminent: true
            )
        }
        .buttonStyle(.glassProminent)
        .tint(Color.glabAccent)
        .disabled(mergeModel.isBusy)
        .accessibilityLabel(action.title)
        .accessibilityIdentifier(
            "mergeRequestDiffs.review.merge"
        )
    }

    private func mergeBlockedButton(
        reasons: [GitLabMergeRequestMergeBlockReason]
    ) -> some View {
        Button {} label: {
            reviewLabel(
                title: "Merge blocked",
                systemImage: "lock.fill",
                isProminent: false
            )
        }
        .buttonStyle(.glass)
        .disabled(true)
        .accessibilityLabel(
            "Merge blocked, "
                + reasons.map(\.title).joined(separator: ", ")
        )
        .accessibilityIdentifier(
            "mergeRequestDiffs.review.mergeBlocked"
        )
    }

    private static func phaseTitle(
        _ phase:
            GitLabMergeRequestApprovalManagementPhase
    ) -> String {
        switch phase {
        case .idle:
            "Ready"
        case .preflighting:
            "Checking revision"
        case .mutating:
            "Updating GitLab"
        case .reconciling:
            "Confirming update"
        case .checkingGitLab:
            "Checking GitLab"
        }
    }

    private func reviewLabel(
        title: String,
        systemImage: String,
        isProminent: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.glabCaption.weight(.semibold))
            Text(title)
                .font(.glabSubheadline.weight(.semibold))
        }
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: approval alert presentation

    private var approvalConfirmationTitle: String {
        approvalManagementModel.confirmation?.action
            == .unapprove
            ? "Remove approval?"
            : "Approve merge request?"
    }

    private var approvalConfirmationActionTitle: String {
        approvalManagementModel.confirmation?.action
            == .unapprove
            ? "Remove Approval"
            : "Approve"
    }

    private var approvalConfirmationMessage: String {
        "The merge request author and reviewers will see "
            + "this change in GitLab."
    }

    private var approvalConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: {
                approvalManagementModel.confirmation != nil
            },
            set: { isPresented in
                if !isPresented {
                    approvalManagementModel
                        .cancelConfirmation()
                }
            }
        )
    }

    // MARK: merge alert presentation

    private var mergeConfirmationTitle: String {
        mergeModel.confirmation?.action == .autoMerge
            ? "Set auto-merge?"
            : "Merge request?"
    }

    private var mergeConfirmationMessage: String {
        guard
            let confirmation = mergeModel.confirmation
        else {
            return ""
        }
        let route = "\(confirmation.sourceBranch) → "
            + confirmation.targetBranch
        switch confirmation.action {
        case .mergeNow:
            return "Merge “\(confirmation.title)” "
                + "from \(route)?"
        case .autoMerge:
            return "GitLab will merge “\(confirmation.title)” "
                + "from \(route) after all checks pass "
                + "and may use a merge train."
        }
    }

    private var mergeConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { mergeModel.confirmation != nil },
            set: { isPresented in
                if !isPresented {
                    mergeModel.dismissConfirmation()
                }
            }
        )
    }

    private var mergeFailureIsPresented: Binding<Bool> {
        Binding(
            get: { mergeModel.failure != nil },
            set: { isPresented in
                if !isPresented {
                    mergeModel.dismissFailure()
                }
            }
        )
    }
}

extension GitLabMergeRequestMergeBlockReason {
    var title: String {
        switch self {
        case .readOnly:
            "Read-only access"
        case .permissionDenied:
            "No merge permission"
        case .notOpen:
            "Not open"
        case .draft:
            "Draft"
        case .missingHeadSHA:
            "No diff"
        case .conflict:
            "Conflicts"
        case .unresolvedDiscussions:
            "Unresolved discussions"
        case .approvals:
            "Missing approvals"
        case .pipeline:
            "Pipeline"
        case .serverRequirement:
            "GitLab requirements"
        }
    }
}
