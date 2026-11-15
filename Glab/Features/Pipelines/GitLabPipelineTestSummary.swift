import Foundation

nonisolated struct GitLabPipelineTestReport:
    Equatable,
    Sendable
{
    let totalTime: TimeInterval?
    let totalCount: Int
    let successCount: Int
    let failedCount: Int
    let errorCount: Int
    let skippedCount: Int
    let suites:
        [GitLabPipelineTestSuite]

    var failureCount: Int {
        failedCount + errorCount
    }

    init(
        totalTime: TimeInterval?,
        totalCount: Int,
        successCount: Int,
        failedCount: Int,
        errorCount: Int,
        skippedCount: Int,
        suites: [GitLabPipelineTestSuite]
    ) {
        self.totalTime = totalTime
        self.totalCount = totalCount
        self.successCount = successCount
        self.failedCount = failedCount
        self.errorCount = errorCount
        self.skippedCount = skippedCount
        self.suites = suites
    }
}

nonisolated struct GitLabPipelineTestSuite:
    Equatable,
    Identifiable,
    Sendable
{
    let name: String
    let failedCount: Int
    let errorCount: Int
    let testCases:
        [GitLabPipelineTestCase]

    var id: String { name }

    var failureCount: Int {
        failedCount + errorCount
    }

    var failedCases:
        [GitLabPipelineTestCase]
    {
        testCases.filter {
            $0.isFailure
        }
    }
}

nonisolated struct GitLabPipelineTestCase:
    Equatable,
    Identifiable,
    Sendable
{
    let name: String
    let className: String?
    let status: GitLabPipelineTestCaseStatus
    let time: TimeInterval?

    var id: String {
        className.map {
            "\($0).\(name)"
        } ?? name
    }

    var isFailure: Bool {
        status == .failed || status == .error
    }
}

nonisolated enum GitLabPipelineTestCaseStatus:
    Equatable,
    Sendable
{
    case success
    case failed
    case error
    case skipped
    case unknown
}

extension GitLabPipelineTestReport:
    Decodable
{
    private enum CodingKeys:
        String,
        CodingKey
    {
        case totalTime = "total_time"
        case totalCount = "total_count"
        case successCount = "success_count"
        case failedCount = "failed_count"
        case errorCount = "error_count"
        case skippedCount = "skipped_count"
        case testSuiteJSON = "test_suites"
    }

    init(
        from decoder: any Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        totalTime = container.decodeLossy(
            Double.self,
            forKey: .totalTime
        )
        totalCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .totalCount
            ) ?? 0
        successCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .successCount
            ) ?? 0
        failedCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .failedCount
            ) ?? 0
        errorCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .errorCount
            ) ?? 0
        skippedCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .skippedCount
            ) ?? 0
        suites =
            container.decodeLossy(
                [GitLabPipelineTestSuite].self,
                forKey: .testSuiteJSON
            ) ?? []
    }
}

extension GitLabPipelineTestSuite:
    Decodable
{
    private enum CodingKeys:
        String,
        CodingKey
    {
        case name
        case failedCount = "failed_count"
        case errorCount = "error_count"
        case testCases = "test_cases"
    }

    init(
        from decoder: any Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        name =
            container.decodeNonemptyStringIfPresent(
                forKey: .name
            )
            ?? "Tests"
        failedCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .failedCount
            ) ?? 0
        errorCount =
            container.decodeNonnegativeIntIfPresent(
                forKey: .errorCount
            ) ?? 0
        testCases =
            container.decodeLossy(
                [GitLabPipelineTestCase].self,
                forKey: .testCases
            ) ?? []
    }
}

extension GitLabPipelineTestCase:
    Decodable
{
    private enum CodingKeys:
        String,
        CodingKey
    {
        case name
        case className = "classname"
        case status
        case time
    }

    init(
        from decoder: any Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy: CodingKeys.self
            )

        name =
            container.decodeNonemptyStringIfPresent(
                forKey: .name
            )
            ?? "Unknown test"
        className =
            container.decodeNonemptyStringIfPresent(
                forKey: .className
            )
        status = Self.status(
            from: container
        )
        time = container.decodeLossy(
            Double.self,
            forKey: .time
        )
    }

    private static func status(
        from container:
            KeyedDecodingContainer<
                CodingKeys
            >
    ) -> GitLabPipelineTestCaseStatus {
        let raw = (
            container.decodeLossy(
                String.self,
                forKey: .status
            ) ?? ""
        )
        .trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .lowercased()

        switch raw {
        case "success":
            return .success
        case "failed":
            return .failed
        case "error":
            return .error
        case "skipped":
            return .skipped
        default:
            return .unknown
        }
    }
}

private nonisolated extension KeyedDecodingContainer
{
    func decodeLossy<Value>(
        _ type: Value.Type,
        forKey key: Key
    ) -> Value?
    where Value: Decodable {
        do {
            return try decodeIfPresent(
                type,
                forKey: key
            )
        } catch {
            return nil
        }
    }

    func decodeNonnegativeIntIfPresent(
        forKey key: Key
    ) -> Int? {
        guard
            let value = decodeLossy(
                Int.self,
                forKey: key
            ),
            value >= 0
        else {
            return nil
        }
        return value
    }

    func decodeNonemptyStringIfPresent(
        forKey key: Key
    ) -> String? {
        guard
            let value = decodeLossy(
                String.self,
                forKey: key
            )
        else {
            return nil
        }
        let normalized =
            value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        return normalized.isEmpty
            ? nil
            : normalized
    }
}
