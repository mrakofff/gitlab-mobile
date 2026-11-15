import Foundation
import Testing
@testable import Glab

@Suite("GitLab pipeline test report decoding")
struct GitLabPipelineTestReportTests {
    private let decoder = JSONDecoder()

    @Test("Decodes a full JUnit test report")
    func decodesFullReport() throws {
        let report = try decoder.decode(
            GitLabPipelineTestReport.self,
            from: Self.fullReport
        )

        #expect(report.totalTime == 52)
        #expect(report.totalCount == 14)
        #expect(report.successCount == 11)
        #expect(report.failedCount == 3)
        #expect(report.errorCount == 0)
        #expect(report.skippedCount == 0)
        #expect(report.failureCount == 3)
        #expect(
            report.suites.map(\.name)
                == ["Unit tests", "Smoke tests"]
        )

        let unitSuite = try #require(
            report.suites.first
        )
        #expect(
            unitSuite.testCases.count == 3
        )
        let failedCase = try #require(
            unitSuite.failedCases.first
        )
        #expect(
            failedCase.name
                == "testPipelineStatusPillRenders"
        )
        #expect(
            failedCase.className
                == "GitLabPipelineHeaderViewTests"
        )
        #expect(failedCase.isFailure)
        #expect(failedCase.time == 2.1)
    }

    @Test("Decodes a sparse report with missing fields")
    func decodesSparseReport() throws {
        let report = try decoder.decode(
            GitLabPipelineTestReport.self,
            from: Self.sparseReport
        )

        #expect(report.totalTime == nil)
        #expect(report.totalCount == 0)
        #expect(report.failureCount == 0)
        #expect(report.suites.count == 2)

        let unnamedSuite = try #require(
            report.suites.first
        )
        #expect(unnamedSuite.name == "Tests")
        #expect(
            unnamedSuite.testCases.count == 1
        )
        let caseWithoutClass = try #require(
            unnamedSuite.testCases.first
        )
        #expect(caseWithoutClass.className == nil)
        #expect(!caseWithoutClass.isFailure)

        let suiteWithCases = try #require(
            report.suites.last
        )
        let damagedCase = try #require(
            suiteWithCases.testCases.first
        )
        #expect(
            damagedCase.name == "Unknown test"
        )
        #expect(
            damagedCase.status == .unknown
        )
    }

    private static let fullReport =
        Data(
            """
            {
              "total_time": 52,
              "total_count": 14,
              "success_count": 11,
              "failed_count": 3,
              "error_count": 0,
              "skipped_count": 0,
              "test_suites": [
                {
                  "name": "Unit tests",
                  "failed_count": 3,
                  "error_count": 0,
                  "test_cases": [
                    {
                      "name": "testPipelineStatusPillRenders",
                      "classname": "GitLabPipelineHeaderViewTests",
                      "status": "failed",
                      "time": 2.1
                    },
                    {
                      "name": "testStageChipsShowProgress",
                      "classname": "GitLabPipelineStageChipTests",
                      "status": "success",
                      "time": 1.4
                    },
                    {
                      "name": "testHeaderCardsAreCompact",
                      "classname": "GitLabPipelineHeaderViewTests",
                      "status": "success",
                      "time": 0.8
                    }
                  ]
                },
                {
                  "name": "Smoke tests",
                  "failed_count": 0,
                  "test_cases": []
                }
              ]
            }
            """
            .utf8
        )

    private static let sparseReport =
        Data(
            """
            {
              "test_suites": [
                {
                  "test_cases": [
                    {
                      "name": "testTabsRender"
                    }
                  ]
                },
                {
                  "test_cases": [
                    {
                      "classname": 4,
                      "status": 99
                    }
                  ]
                }
              ]
            }
            """
            .utf8
        )
}
