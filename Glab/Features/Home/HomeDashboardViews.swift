import SwiftUI

extension GitLabPaginatedResourceModel {
    var statCount: Int? {
        reliableItemCount
            ?? (hasLoaded ? items.count : nil)
    }

    var statCountText: String {
        guard let statCount else {
            return "–"
        }
        let isLowerBound =
            reliableItemCount == nil
            && nextPageURL != nil
        return isLowerBound
            ? "\(statCount)+"
            : "\(statCount)"
    }
}

struct HomeNeedsAttentionHeader: View {
    let count: Int?
    let reviews: Int?
    let todos: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Image(
                    systemName:
                        "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

                Text("Needs attention")
                    .font(.glabTitle3.bold())

                Text(count.map(String.init) ?? "–")
                    .font(.glabTitle3.bold())
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }

            if let summary {
                Text(summary)
                    .font(.glabSubheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.needsAttention")
    }

    private var summary: String? {
        var parts: [String] = []
        if let reviews {
            parts.append(
                "\(reviews) \(reviews == 1 ? "review" : "reviews")"
            )
        }
        if let todos {
            parts.append(
                "\(todos) \(todos == 1 ? "todo" : "todos")"
            )
        }
        return parts.isEmpty
            ? nil
            : parts.joined(separator: " · ")
    }
}

struct HomeSectionHeader: View {
    let title: String
    let count: String?
    let identifier: String
    let onSeeAll: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.glabHeadline)
                .foregroundStyle(.primary)

            if let count {
                Text(count)
                    .font(.glabCaption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Color.glabAccent.opacity(0.12),
                        in: .capsule
                    )
                    .foregroundStyle(Color.glabAccent)
            }

            Spacer(minLength: 8)

            Button("See all", action: onSeeAll)
                .font(.glabSubheadline)
                .accessibilityIdentifier(identifier)
        }
        .textCase(nil)
    }
}

struct HomeMergeRequestRow: View {
    let mergeRequest: GitLabMergeRequest

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(status.title)
                    .font(.glabCaption.weight(.semibold))
                    .foregroundStyle(statusColor)

                Spacer(minLength: 8)

                Text(
                    GitLabRelativeTimeFormatter.string(
                        from: mergeRequest.updatedAt
                    )
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)
            }

            Text(mergeRequest.title)
                .font(.glabBody.weight(.medium))
                .lineLimit(2)

            Text(footer)
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var status: HomeMergeRequestStatus {
        HomeMergeRequestStatus(mergeRequest)
    }

    private var statusColor: Color {
        switch status {
        case .ready:
            .green
        case .waitingForApproval, .needsRebase,
            .unresolvedThreads:
            .orange
        case .changesRequested, .conflicts,
            .pipelineFailed:
            .red
        case .pipelineRunning:
            .blue
        case .draft, .open:
            .secondary
        }
    }

    private var footer: String {
        "\(mergeRequest.references.short) · "
            + mergeRequest.author.displayName
    }
}

struct HomeIssueRow: View {
    let issue: GitLabIssue

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(issue.title)
                .font(.glabBody.weight(.medium))
                .lineLimit(2)

            Text(footer)
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var footer: String {
        [
            issue.references.full,
            GitLabRelativeTimeFormatter.string(
                from: issue.updatedAt
            ),
        ].joined(separator: " · ")
    }
}

struct HomeDashboardSectionPlaceholder: View {
    let message: String
    var isLoading = false
    var retry: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            }

            Text(message)
                .font(.glabSubheadline)
                .foregroundStyle(.secondary)

            if let retry {
                Spacer(minLength: 8)
                Button("Retry", action: retry)
                    .font(.glabSubheadline)
            }
        }
        .padding(.vertical, 2)
    }
}

struct HomeCatchUpShortcutRow: View {
    let count: Int?

    var body: some View {
        HStack(spacing: 14) {
            GitLabIconView(.todoDone)
                .foregroundStyle(Color.glabAccent)
                .frame(width: 38, height: 38)
                .background(
                    Color.glabAccent.opacity(0.12),
                    in: .rect(cornerRadius: 10)
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("Catch Up")
                    .font(.glabBody.weight(.semibold))

                Text("Swipe through pending Todos")
                    .font(.glabSubheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let count, count > 0 {
                Text("\(count)")
                    .font(.glabSubheadline.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(Color.glabAccent)
                    .accessibilityLabel(
                        "\(count) Todos"
                    )
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Catch Up")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(
            "Opens a swipeable Todo queue."
        )
    }

    private var accessibilityValue: String {
        guard let count, count > 0 else {
            return "Pending Todos available"
        }
        return "\(count) pending Todos"
    }
}

struct HomeWorkShortcutRow: View {
    let section: HomeDashboardSection
    let presentation: HomeDashboardRowPresentation

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        icon
                        Spacer()
                        statusAccessory
                    }

                    textContent
                }
            } else {
                HStack(spacing: 14) {
                    icon
                    textContent
                    Spacer(minLength: 8)
                    statusAccessory
                }
            }
        }
        .padding(.vertical, 5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(section.title)
        .accessibilityValue(presentation.accessibilityValue)
    }

    private var icon: some View {
        Group {
            if let gitLabIcon = section.gitLabIcon {
                GitLabIconView(gitLabIcon)
            } else {
                Image(systemName: section.systemImage)
                    .font(.glabHeadline)
            }
        }
            .foregroundStyle(Color.glabAccent)
            .frame(width: 38, height: 38)
            .background(
                Color.glabAccent.opacity(0.12),
                in: .rect(cornerRadius: 10)
            )
            .accessibilityHidden(true)
    }

    private var textContent: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(section.title)
                .font(.glabBody.weight(.medium))

            Text(presentation.subtitle)
                .font(.glabSubheadline)
                .foregroundStyle(
                    presentation.status == .failed
                        ? AnyShapeStyle(.red)
                        : AnyShapeStyle(.secondary)
                )
                .lineLimit(2)
        }
    }

    @ViewBuilder
    private var statusAccessory: some View {
        Group {
            if presentation.status == .loading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else if presentation.status == .failed {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
                    .accessibilityHidden(true)
            } else if presentation.status == .stale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
            }
        }
    }
}
