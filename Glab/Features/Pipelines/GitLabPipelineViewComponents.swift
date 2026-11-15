import SwiftUI

struct GitLabPipelineHistoryRow: View {
    let pipeline: GitLabPipeline

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            GitLabCIStatusIcon(
                status: pipeline.status
            )
            .padding(.top, 2)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(
                    pipeline.name
                    ?? "Pipeline \(pipeline.displayID)"
                )
                .font(
                    .glabBody.weight(.semibold)
                )
                .lineLimit(3)

                metadata
                    .font(.glabCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            [
                pipeline.name
                    ?? "Pipeline \(pipeline.displayID)",
                pipeline.status.title,
                pipeline.ref,
                pipeline.shortSHA,
            ]
            .joined(separator: ", ")
        )
    }

    private var metadata: Text {
        let status =
            Text(pipeline.status.title)
            .foregroundStyle(
                pipeline.status.tint
            )
        let sha =
            Text(pipeline.shortSHA)
            .fontDesign(.monospaced)
        let relativeTime =
            pipeline.relativeTime
                .map { "  \($0)" }
                ?? ""
        return Text(
            "\(status)  \(pipeline.ref)  \(sha)\(relativeTime)"
        )
    }
}

struct GitLabPipelineHeader: View {
    let pipeline: GitLabPipeline
    let jobs:
        [GitLabPipelineStageRow]

    private var totalJobs: Int {
        jobs.count
    }

    private var finishedJobs: Int {
        jobs.filter {
            $0.status.isTerminal
        }
        .count
    }

    private var failedJobs: Int {
        jobs.filter {
            $0.status.rawValue == "failed"
        }
        .count
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: 10
        ) {
            HStack(
                alignment: .center,
                spacing: 8
            ) {
                GitLabCIStatusIcon(
                    status: pipeline.status
                )

                VStack(
                    alignment: .leading,
                    spacing: 2
                ) {
                    Text(
                        pipeline.status.title
                    )
                    .font(
                        .glabHeadline.weight(
                            .semibold
                        )
                    )
                    .foregroundStyle(
                        pipeline.status.tint
                    )

                    statusSubtitle
                        .font(.glabCaption)
                        .foregroundStyle(
                            .secondary
                        )
                }

                Spacer(minLength: 8)

                if
                    let durationText =
                        pipeline
                    .durationText
                {
                    Text(durationText)
                        .font(
                            .glabSubheadline
                            .monospacedDigit()
                            .weight(.semibold)
                        )
                        .foregroundStyle(
                            .secondary
                        )
                }
            }

            if totalJobs > 0,
                pipeline.status
                .showsActivityAnimation
            {
                GeometryReader {
                    proxy in
                    Capsule()
                        .fill(
                            Color.glabSeparator
                        )
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(
                                    Color.glabAccent
                                )
                                .frame(
                                    width: max(
                                        8,
                                        proxy.size.width
                                            * CGFloat(
                                                finishedJobs
                                            )
                                            / CGFloat(
                                                totalJobs
                                            )
                                    )
                                )
                        }
                }
                .frame(height: 3)
                .accessibilityHidden(true)
            }

            Text(
                pipeline.name
                    ?? "Pipeline "
                    + pipeline.displayID
            )
            .font(
                .glabSubheadline.weight(
                    .medium
                )
            )
            .lineLimit(2)

            HStack(spacing: 6) {
                Text(pipeline.ref)
                    .font(
                        .glabCaption.weight(
                            .medium
                        )
                    )
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Color.glabAccent.opacity(0.12),
                        in: .capsule
                    )

                shaChip
            }
            .accessibilityElement(
                children: .ignore
            )
            .accessibilityLabel(
                "Branch \(pipeline.ref), commit \(pipeline.shortSHA)"
            )
            .accessibilityIdentifier(
                "pipelines.detail.header.commitChips"
            )

            HStack(spacing: 5) {
                if
                    let author =
                        pipeline.user?.displayName
                {
                    Text(author)
                        .lineLimit(1)
                }
                if
                    let source =
                        pipeline.humanSource
                {
                    Text(source)
                }
                if
                    let date =
                        pipeline.createdAt
                {
                    Text(
                        GitLabRelativeTimeFormatter
                        .string(from: date)
                    )
                }
            }
            .font(.glabCaption)
            .foregroundStyle(.secondary)
            .lineLimit(1)

            HStack(spacing: 8) {
                GitLabStatTile(
                    title: "Queued",
                    value: pipeline
                        .queuedDurationText
                        ?? "—"
                ) {
                    Image(
                        systemName: "hourglass"
                    )
                }

                GitLabStatTile(
                    title: "Finished",
                    value: pipeline
                        .finishedAtTimeText
                        ?? "—"
                ) {
                    Image(
                        systemName: "checkmark.circle"
                    )
                }
            }
            .padding(.vertical, 2)

            if
                let updatedAt =
                    pipeline.updatedAt
            {
                HStack(spacing: 4) {
                    Image(
                        systemName: "clock"
                    )
                    .accessibilityHidden(true)
                    Text(
                        "Updated at "
                            + Self.timeFormatter
                            .string(
                                from: updatedAt
                            )
                    )
                }
                .font(.glabCaption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(
            children: .combine
        )
        .accessibilityIdentifier(
            "pipelines.detail.header"
        )
    }

    private var statusSubtitle: Text {
        let jobs = Text(
            "Jobs: \(totalJobs)"
        )
        if failedJobs > 0 {
            return Text(
                "\(jobs) · \(failedJobs) failed"
            )
        }
        if totalJobs > 0,
            finishedJobs == totalJobs,
            failedJobs == 0
        {
            return Text("\(jobs) · all passed")
        }
        return Text(
            "\(jobs) · \(finishedJobs) finished"
        )
    }

    private var shaChip: some View {
        Text(pipeline.shortSHA)
            .fontDesign(.monospaced)
            .font(.glabCaption)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Color.glabAccent.opacity(0.12),
                in: .capsule
            )
    }

    private static let timeFormatter:
        DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()
}

struct GitLabPipelineJobRow: View {
    let row: GitLabPipelineStageRow

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            GitLabCIStatusIcon(
                status: row.status
            )
            .padding(.top, 2)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(row.name)
                    .font(
                        .glabBody.weight(.medium)
                    )
                    .lineLimit(3)

                Text(row.metadataSummary)
                    .font(.glabCaption)
                    .foregroundStyle(.secondary)

                if
                    let artifactText =
                        row.artifactText
                {
                    Text(artifactText)
                        .font(.glabCaption)
                        .foregroundStyle(
                            .tertiary
                        )
                        .lineLimit(1)
                }

                if
                    let downstreamSummary =
                        row.downstreamSummary
                {
                    Text(downstreamSummary)
                        .font(.glabCaption)
                        .foregroundStyle(
                            .secondary
                        )
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            row.accessibilityLabel
        )
        .accessibilityIdentifier(
            row.accessibilityIdentifier
        )
    }
}

struct GitLabPipelineStageChip: View {
    let stage: GitLabPipelineStage

    var body: some View {
        let total = stage.rows.count
        let done = stage.rows.filter {
            $0.status.isTerminal
        }
        .count

        return HStack(spacing: 5) {
            GitLabCIStatusIcon(
                status: stage.status
            )

            Text(stage.name)
                .font(
                    .glabCaption.weight(.medium)
                )
                .lineLimit(1)

            Text("\(done)/\(total)")
                .font(
                    .glabCaption
                    .monospacedDigit()
                )
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(
            Color.glabAccent.opacity(0.12),
            in: .capsule
        )
        .accessibilityElement(
            children: .ignore
        )
        .accessibilityLabel(
            "Stage \(stage.name), \(done) of \(total) jobs finished"
        )
    }
}

extension GitLabPipeline {
    /// "Merge request event · Nitesh
    /// Balusu" style trigger summary line.
    var humanSource: String? {
        guard let source else {
            return nil
        }
        let title =
            source.replacingOccurrences(
                of: "_",
                with: " "
            )
        .capitalized
        return source.contains("_")
            ? title
            : nil
    }

    var durationText: String? {
        duration.flatMap {
            GitLabDurationFormatter.string(
                seconds: $0
            )
        }
    }

    var queuedDurationText: String? {
        queuedDuration
            .flatMap {
                GitLabDurationFormatter.string(
                    seconds: $0
                )
            }
    }

    var finishedAtTimeText: String? {
        guard let finishedAt else {
            return nil
        }
        return Self.clockFormatter.string(
            from: finishedAt
        )
    }

    private static let clockFormatter:
        DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter
        }()
}

extension GitLabPipelineStage {
    /// Aggregated status: failed wins over
    /// running over waiting over terminal
    /// success — mirrors how a stage reads at
    /// a glance in CI dashboards.
    var status: GitLabCIStatus {
        if rows.contains(where: {
            $0.status.rawValue == "failed"
        }) {
            return GitLabCIStatus(
                rawValue: "failed"
            )
        }
        if rows.contains(where: {
            $0.status.isActiveLike
        }) {
            return GitLabCIStatus(
                rawValue: "running"
            )
        }
        if rows.contains(where: {
            $0.status.showsWaitingIndicator
        }) {
            return GitLabCIStatus(
                rawValue: "pending"
            )
        }
        if rows.contains(where: {
            $0.status.rawValue == "manual"
        }) {
            return GitLabCIStatus(
                rawValue: "manual"
            )
        }
        return GitLabCIStatus(
            rawValue: "success"
        )
    }
}

private extension GitLabCIStatus {
    var isActiveLike: Bool {
        switch rawValue {
        case "running",
             "canceling",
             "preparing":
            true
        default:
            false
        }
    }
}

struct GitLabCIStatusIcon: View {
    let status: GitLabCIStatus

    var body: some View {
        Group {
            if let gitLabIcon = status.gitLabIcon {
                GitLabIconView(gitLabIcon)
            } else {
                Image(
                    systemName:
                        "questionmark.circle.fill"
                )
                .font(.glabBody)
            }
        }
        .foregroundStyle(status.tint)
        .frame(width: 22)
        .accessibilityHidden(true)
    }
}

extension GitLabPipeline {
    var displayID: String {
        "#\(iid ?? id)"
    }

    var shortSHA: String {
        String(sha.prefix(8))
    }

    var detailCacheLifetime:
        GitLabPipelineCacheLifetime
    {
        status.isTerminal
            ? .completed
            : .active
    }

    var metadataSummary: String {
        var values: [String] = []
        if let source {
            values.append(
                source.replacingOccurrences(
                    of: "_",
                    with: " "
                )
            )
        }
        if let user {
            values.append(user.displayName)
        }
        if
            let duration,
            let formatted =
                GitLabDurationFormatter
                .string(seconds: duration)
        {
            values.append(formatted)
        }
        if
            let date =
                finishedAt
                ?? updatedAt
                ?? startedAt
                ?? createdAt
        {
            values.append(
                GitLabRelativeTimeFormatter
                    .string(from: date)
            )
        }
        return values.joined(
            separator: " · "
        )
    }

    var relativeTime: String? {
        guard
            let date = updatedAt ?? createdAt
        else {
            return nil
        }
        return GitLabRelativeTimeFormatter
            .string(from: date)
    }
}

extension GitLabPipelineStageRow {
    var allowsFailure: Bool {
        switch content {
        case let .job(job):
            job.allowFailure
        case let .triggerJob(job):
            job.allowFailure
        }
    }

    var durationText: String? {
        let duration:
            TimeInterval? =
            switch content {
            case let .job(job):
                job.duration
            case let .triggerJob(job):
                job.duration
            }
        guard let duration else {
            return nil
        }
        return GitLabDurationFormatter
            .string(seconds: duration)
    }

    var artifactText: String? {
        guard
            case let .job(job) = content,
            job.artifactSummary.totalSize > 0
        else {
            return nil
        }
        return ByteCountFormatter.string(
            fromByteCount: Int64(
                job.artifactSummary.totalSize
            ),
            countStyle: .file
        )
        + " artifacts"
    }

    var downstreamSummary: String? {
        guard
            case let .triggerJob(job) =
                content,
            let pipeline =
                job.downstreamPipeline
        else {
            return nil
        }
        return [
            pipeline.status.title,
            pipeline.ref,
            pipeline.shortSHA,
        ]
        .joined(separator: " · ")
    }

    var metadataSummary: String {
        var values: [String] = []
        if case .triggerJob = content {
            values.append("Child")
        }
        values.append(status.jobTitle)
        if attempt != .only {
            values.append(attempt.title)
        }
        if let durationText {
            values.append(durationText)
        }
        if allowsFailure {
            values.append("Allowed")
        }
        return values.joined(
            separator: " · "
        )
    }

    var accessibilityLabel: String {
        var values = [
            name,
            status.jobTitle,
        ]
        if case .triggerJob = content {
            values.append("Child pipeline")
        }
        if attempt != .only {
            values.append(attempt.title)
        }
        if allowsFailure {
            values.append("Failure allowed")
        }
        if let durationText {
            values.append(durationText)
        }
        if let downstreamSummary {
            values.append(downstreamSummary)
        }
        return values.joined(
            separator: ", "
        )
    }

    var accessibilityIdentifier: String {
        switch id {
        case let .job(id):
            "pipelines.detail.job.\(id)"
        case let .triggerJob(id):
            "pipelines.detail.triggerJob.\(id)"
        }
    }
}

extension GitLabPipelineJobAttempt {
    var title: String {
        switch self {
        case .only:
            ""
        case .latest:
            "Latest run"
        case .earlier:
            "Earlier run"
        }
    }
}

extension GitLabCIStatus {
    var gitLabIcon: GitLabIcon? {
        switch rawValue {
        case "created":
            .pipelineCreated
        case "waiting_for_resource",
             "waiting_for_callback":
            .pipelinePending
        case "preparing":
            .pipelinePreparing
        case "pending":
            .pipelinePending
        case "running":
            .pipelineRunning
        case "canceling":
            .pipelineCanceled
        case "scheduled":
            .pipelineScheduled
        case "manual":
            .pipelineManual
        case "success":
            .pipelineSuccess
        case "failed":
            .pipelineFailed
        case "canceled":
            .pipelineCanceled
        case "skipped":
            .pipelineSkipped
        default:
            nil
        }
    }

    var tint: Color {
        switch rawValue {
        case "success":
            .green
        case "failed":
            .red
        case "canceled",
             "skipped":
            .secondary
        case "manual":
            .orange
        case "created",
             "waiting_for_resource",
             "preparing",
             "waiting_for_callback",
             "pending",
             "running",
             "canceling",
             "scheduled":
            .blue
        default:
            .secondary
        }
    }
}
