import SwiftUI

struct GitLabProjectSummaryCard: View {
    let project: GitLabProject

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                avatar

                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(project.name)
                        .font(.glabTitle2.bold())
                    Text(project.pathWithNamespace)
                        .font(.glabSubheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            HStack(spacing: 8) {
                Label(
                    project.visibility.title,
                    systemImage:
                        project.visibility
                        .systemImage
                )
                .font(.glabCaption.weight(.medium))
                .foregroundStyle(Color.glabAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(
                    Color.glabAccent.opacity(0.12),
                    in: .capsule
                )

                Label(
                    project.starCount.formatted(),
                    systemImage: "star"
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)

                if let forks = project.forksCount {
                    Label(
                        forks.formatted(),
                        systemImage:
                            "arrow.triangle.branch"
                    )
                    .font(.glabCaption)
                    .foregroundStyle(.secondary)
                }
            }

            if let description =
                project.trimmedDescription
            {
                Text(description)
                    .font(.glabSubheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .frame(
                        maxWidth: .infinity,
                        alignment: .leading
                    )
            }
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("project.header")
    }

    private var avatar: some View {
        AsyncImage(url: project.safeAvatarURL) {
            phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFill()
            default:
                Text(project.avatarMark)
                    .font(
                        .glabHeadline.weight(.bold)
                    )
                    .foregroundStyle(Color.glabAccent)
            }
        }
        .frame(width: 58, height: 58)
        .background(Color.glabAccent.opacity(0.12))
        .clipShape(.rect(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    Color.secondary.opacity(0.18),
                    lineWidth: 0.5
                )
        }
        .accessibilityHidden(true)
    }
}

struct GitLabProjectLanguageBar: View {
    let languages: [GitLabProjectLanguage]

    private static let palette: [Color] = [
        .blue, .orange, .green, .purple, .pink,
        .teal,
    ]
    private static let otherColor = Color.gray
    private static let legendLimit = 4

    private static let visibleThreshold = 0.1

    private var legend: [Entry] {
        let visible = languages.filter {
            $0.percentage >= Self.visibleThreshold
        }
        var entries = visible.prefix(
            Self.legendLimit
        )
        .enumerated()
        .map {
            Entry(
                name: $1.name,
                percentage: $1.percentage,
                color: Self.palette[
                    $0 % Self.palette.count
                ]
            )
        }
        let rest = visible.dropFirst(
            Self.legendLimit
        )
        .reduce(0) { $0 + $1.percentage }
        if rest >= Self.visibleThreshold {
            entries.append(
                Entry(
                    name: "Other",
                    percentage: rest,
                    color: Self.otherColor
                )
            )
        }
        return entries
    }

    var body: some View {
        let entries = legend
        let total = entries.reduce(0) {
            $0 + $1.percentage
        }

        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(entries) { entry in
                        entry.color.frame(
                            width: max(
                                3,
                                proxy.size.width
                                    * entry.percentage
                                    / total
                            )
                        )
                    }
                }
                .clipShape(.capsule)
            }
            .frame(height: 6)

            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(minimum: 92),
                        alignment: .leading
                    ),
                ],
                alignment: .leading,
                spacing: 4
            ) {
                ForEach(entries) { entry in
                    HStack(spacing: 5) {
                        Circle()
                            .fill(entry.color)
                            .frame(
                                width: 7,
                                height: 7
                            )
                        Text(entry.name)
                            .font(.glabCaption)
                            .lineLimit(1)
                        Text(
                            "\(entry.percentage.formatted(.number.precision(.fractionLength(1))))%"
                        )
                        .font(.glabCaption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "Languages: "
                + entries.map {
                    "\($0.name) \($0.percentage.formatted(.number.precision(.fractionLength(1)))) percent"
                }
                .joined(separator: ", ")
        )
        .accessibilityIdentifier(
            "project.languages"
        )
    }

    private struct Entry: Identifiable {
        let name: String
        let percentage: Double
        let color: Color

        var id: String { name }
    }
}

struct GitLabProjectActionItem: View {
    let title: String
    let systemImage: String
    var tint: Color = .glabAccent
    var isLoading = false

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(
                            .glabSubheadline.weight(
                                .semibold
                            )
                        )
                }
            }
            .foregroundStyle(tint)
            .frame(height: 20)

            Text(title)
                .font(.glabCaption)
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(
            .regular
                .tint(tint.opacity(0.12))
                .interactive(),
            in: .rect(cornerRadius: 14)
        )
        .contentShape(.rect(cornerRadius: 14))
    }
}

struct GitLabProjectBranchChip: View {
    let branch: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "arrow.triangle.branch")
                .font(.glabCaption)
            Text(branch)
                .font(
                    .glabCaption.weight(.medium)
                )
                .lineLimit(1)
        }
        .foregroundStyle(Color.glabAccent)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(
            Color.glabAccent.opacity(0.12),
            in: .capsule
        )
    }
}

struct GitLabProjectCommitRow: View {
    let commit: GitLabCommit

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(commit.authorMark)
                .font(
                    .glabCaption.weight(.bold)
                )
                .foregroundStyle(Color.glabAccent)
                .frame(width: 32, height: 32)
                .background(
                    Color.glabAccent.opacity(0.12),
                    in: .circle
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(commit.title)
                    .font(
                        .glabSubheadline.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(
                    "\(commit.authorName) · \(GitLabRelativeTimeFormatter.string(from: commit.authoredDate)) · \(commit.shortID)"
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
