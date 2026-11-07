import Testing
@testable import Glab

@Suite("Home merge request status")
struct HomeMergeRequestStatusTests {
    @Test(
        "Maps detailed merge status to a dashboard status",
        arguments: [
            ("mergeable", HomeMergeRequestStatus.ready),
            ("not_approved", .waitingForApproval),
            ("requested_changes", .changesRequested),
            ("conflict", .conflicts),
            ("need_rebase", .needsRebase),
            ("discussions_not_resolved", .unresolvedThreads),
            ("ci_still_running", .pipelineRunning),
            ("draft_status", .draft),
            ("checking", .open),
        ]
    )
    func mapsDetailedStatus(
        detailedStatus: String,
        expected: HomeMergeRequestStatus
    ) {
        let mergeRequest = makeTestMergeRequest(
            detailedMergeStatus: detailedStatus
        )

        #expect(HomeMergeRequestStatus(mergeRequest) == expected)
    }

    @Test("Draft wins over any merge status")
    func draftWins() {
        let mergeRequest = makeTestMergeRequest(
            draft: true,
            detailedMergeStatus: "mergeable"
        )

        #expect(HomeMergeRequestStatus(mergeRequest) == .draft)
    }

    @Test("Required CI distinguishes failed from pending pipelines")
    func requiredCI() {
        let failed = makeTestMergeRequest(
            detailedMergeStatus: "ci_must_pass",
            headPipeline: GitLabMergeRequestHeadPipeline(
                id: 1,
                status: "failed",
                webURL: nil
            )
        )
        let pending = makeTestMergeRequest(
            detailedMergeStatus: "ci_must_pass"
        )

        #expect(HomeMergeRequestStatus(failed) == .pipelineFailed)
        #expect(HomeMergeRequestStatus(pending) == .pipelineRunning)
    }

    @Test("Falls back to conflicts and pipeline data without a status")
    func fallsBackWithoutDetailedStatus() {
        let conflicted = makeTestMergeRequest(hasConflicts: true)
        let failed = makeTestMergeRequest(
            headPipeline: GitLabMergeRequestHeadPipeline(
                id: 1,
                status: "failed",
                webURL: nil
            )
        )
        let plain = makeTestMergeRequest()

        #expect(HomeMergeRequestStatus(conflicted) == .conflicts)
        #expect(HomeMergeRequestStatus(failed) == .pipelineFailed)
        #expect(HomeMergeRequestStatus(plain) == .open)
    }
}
