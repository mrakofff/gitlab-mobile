import Foundation
import UIKit

nonisolated struct GitLabDiffSyntaxHighlightRequest:
    Sendable
{
    let document: GitLabParsedDiffDocument
    let oldLanguage: GitLabSyntaxLanguage?
    let newLanguage: GitLabSyntaxLanguage?
    let theme: GitLabSyntaxTheme
}

nonisolated struct GitLabDiffHighlightedLine:
    Sendable
{
    private let source: GitLabHighlightedText
    private let range: NSRange
    private let wordRanges:
        [(range: NSRange, kind: GitLabDiffLineKind)]?

    init(
        source: GitLabHighlightedText,
        range: NSRange
    ) {
        self.source = source
        self.range = range
        wordRanges = nil
    }

    /// Lines configured with word-level change ranges get background
    /// tints for added or removed tokens within the line.
    init(
        source: GitLabHighlightedText,
        range: NSRange,
        wordRanges: [(
            range: NSRange,
            kind: GitLabDiffLineKind
        )]
    ) {
        self.source = source
        self.range = range
        self.wordRanges = wordRanges
    }

    init(_ attributedString: NSAttributedString) {
        source = GitLabHighlightedText(
            attributedString
        )
        range = NSRange(
            location: 0,
            length: attributedString.length
        )
        wordRanges = nil
    }

    /// Returns a copy configured with word-level tint ranges.
    func withWordRanges(
        _ newWordRanges: [(
            range: NSRange,
            kind: GitLabDiffLineKind
        )]
    ) -> GitLabDiffHighlightedLine {
        GitLabDiffHighlightedLine(
            source: source,
            range: range,
            wordRanges: newWordRanges
        )
    }

    var attributedString: NSAttributedString {
        let substring =
            source.attributedString.attributedSubstring(
                from: range
            )
        guard let wordRanges, !wordRanges.isEmpty else {
            return substring
        }
        let result = NSMutableAttributedString(
            attributedString: substring
        )
        let offset = range.location
        for wordRange in wordRanges {
            let color =
                wordRange.kind == .addition
                ? Self.additionWordColor
                : Self.deletionWordColor
            result.addAttribute(
                .backgroundColor,
                value: color,
                range: NSRange(
                    location: wordRange.range.location - offset,
                    length: wordRange.range.length
                )
            )
        }
        return result
    }

    private static let additionWordColor =
        UIColor.systemGreen.withAlphaComponent(0.28)

    private static let deletionWordColor =
        UIColor.systemRed.withAlphaComponent(0.32)
}

nonisolated struct GitLabDiffSyntaxHighlighter:
    Sendable
{
    static let maximumHunkCount = 100
    static let maximumProjectedSourceByteCount =
        GitLabSyntaxHighlighter.maximumInputByteCount * 2

    private struct Projection: Sendable {
        let lines: [String]
        let ordinals: [Int]
    }

    private let syntaxHighlighter:
        any GitLabSyntaxHighlighting

    init(
        syntaxHighlighter:
            any GitLabSyntaxHighlighting
    ) {
        self.syntaxHighlighter = syntaxHighlighter
    }

    @concurrent
    func highlight(
        _ request: GitLabDiffSyntaxHighlightRequest
    ) async throws -> [Int: GitLabDiffHighlightedLine] {
        try Task.checkCancellation()
        guard
            request.oldLanguage != nil
                || request.newLanguage != nil,
            !request.document.hunks.isEmpty,
            request.document.hunks.count
                <= Self.maximumHunkCount,
            try Self.projectedSourceByteCount(
                in: request.document
            ) <= Self.maximumProjectedSourceByteCount
        else {
            return [:]
        }

        var result: [Int: GitLabDiffHighlightedLine] = [:]
        result.reserveCapacity(
            request.document.items.count
        )

        for hunkIndex in request.document.hunks.indices {
            try Task.checkCancellation()
            let hunk = request.document.hunks[hunkIndex]
            let endIndex =
                if
                    request.document.hunks.indices
                    .contains(hunkIndex + 1)
                {
                    request.document.hunks[
                        hunkIndex + 1
                    ].renderItemIndex
                } else {
                    request.document.items.endIndex
                }
            let itemRange = request.document.items.index(
                after: hunk.renderItemIndex
            )..<endIndex
            let projections = try Self.projections(
                for: request.document.items[itemRange]
            )

            if let oldLanguage = request.oldLanguage {
                let oldLines = try await highlightedLines(
                    projections.old,
                    language: oldLanguage,
                    theme: request.theme
                )
                result.merge(oldLines) { _, new in new }
            }

            if let newLanguage = request.newLanguage {
                let newLines = try await highlightedLines(
                    projections.new,
                    language: newLanguage,
                    theme: request.theme
                )
                // The new side is the preferred source of attributes for
                // context rows shared by both projections.
                result.merge(newLines) { _, new in new }
            }
        }

        try Task.checkCancellation()
        let wordHighlights = try Self.wordHighlightRanges(
            in: request.document
        )
        guard !wordHighlights.isEmpty else {
            return result
        }
        for (index, line) in result {
            guard
                let ranges = wordHighlights[index],
                !ranges.isEmpty
            else {
                continue
            }
            result[index] = line
                .withWordRanges(ranges)
        }
        return result
    }

    /// Pairs each deletion run with the addition run that follows it and
    /// marks the tokens that actually changed inside both lines. Ranges
    /// are projection-relative: locations follow the order in which the
    /// old or new projection concatenates its lines, mirroring
    /// `lineRanges(for:in:)`.
    private static func wordHighlightRanges(
        in document: GitLabParsedDiffDocument
    ) throws -> [Int: [(
        range: NSRange,
        kind: GitLabDiffLineKind
    )]] {
        var result: [Int: [(
            range: NSRange,
            kind: GitLabDiffLineKind
        )]] = [:]
        var oldLocations: [Int: NSRange] = [:]
        var newLocations: [Int: NSRange] = [:]
        var oldLocation = 0
        var newLocation = 0

        for item in document.items {
            guard let line = item.line else {
                continue
            }
            let length = line.text.utf16.count
            switch line.kind {
            case .deletion:
                oldLocations[line.ordinal] =
                    NSRange(
                        location: oldLocation,
                        length: length
                    )
                oldLocation += length + 1
            case .addition:
                newLocations[line.ordinal] =
                    NSRange(
                        location: newLocation,
                        length: length
                    )
                newLocation += length + 1
            case .context:
                oldLocations[line.ordinal] =
                    NSRange(
                        location: oldLocation,
                        length: length
                    )
                oldLocation += length + 1
                newLocations[line.ordinal] =
                    NSRange(
                        location: newLocation,
                        length: length
                    )
                newLocation += length + 1
            }
        }

        var deletionRun: [GitLabDiffLine] = []
        var additionRun: [GitLabDiffLine] = []

        func flushRun() throws {
            guard
                !deletionRun.isEmpty,
                !additionRun.isEmpty
            else {
                deletionRun = []
                additionRun = []
                return
            }
            defer {
                deletionRun = []
                additionRun = []
            }
            try Task.checkCancellation()
            let pairCount = min(
                deletionRun.count,
                additionRun.count
            )
            for index in 0..<pairCount {
                let segments = GitLabDiffWordHighlighter.segments(
                    old: deletionRun[index].text,
                    new: additionRun[index].text
                )
                if
                    let oldRange = oldLocations[
                        deletionRun[index].ordinal
                    ],
                    !segments.old.isEmpty
                {
                    result[deletionRun[index].ordinal, default: []] =
                        wordRanges(
                            for: segments.old,
                            kind: .deletion,
                            absoluteRange: oldRange
                        )
                }
                if
                    let newRange = newLocations[
                        additionRun[index].ordinal
                    ],
                    !segments.new.isEmpty
                {
                    result[additionRun[index].ordinal, default: []] =
                        wordRanges(
                            for: segments.new,
                            kind: .addition,
                            absoluteRange: newRange
                        )
                }
            }
        }

        for item in document.items {
            guard let line = item.line else {
                // A hunk header or metadata row separates runs too.
                try flushRun()
                continue
            }
            switch line.kind {
            case .deletion:
                try flushRun()
                deletionRun.append(line)
            case .addition:
                additionRun.append(line)
            case .context:
                try flushRun()
            }
        }
        try flushRun()
        return result
    }

    private static func wordRanges(
        for segments: [GitLabDiffWordSegment],
        kind: GitLabDiffLineKind,
        absoluteRange: NSRange
    ) -> [(
        range: NSRange,
        kind: GitLabDiffLineKind
    )] {
        var ranges: [(
            range: NSRange,
            kind: GitLabDiffLineKind
        )] = []
        ranges.reserveCapacity(segments.count)
        var offset = absoluteRange.location
        for segment in segments {
            let length = segment.text.utf16.count
            if segment.kind == .changed {
                ranges.append(
                    (
                        range: NSRange(
                            location: offset,
                            length: length
                        ),
                        kind: kind
                    )
                )
            }
            offset += length
        }
        return ranges
    }

    private func highlightedLines(
        _ projection: Projection,
        language: GitLabSyntaxLanguage,
        theme: GitLabSyntaxTheme
    ) async throws -> [Int: GitLabDiffHighlightedLine] {
        guard !projection.lines.isEmpty else {
            return [:]
        }
        try Task.checkCancellation()
        guard
            let highlighted = await syntaxHighlighter
                .highlight(
                    GitLabSyntaxHighlightRequest(
                        lines: projection.lines,
                        language: language,
                        theme: theme
                    )
                )
        else {
            try Task.checkCancellation()
            return [:]
        }
        try Task.checkCancellation()
        guard
            let ranges = try Self.lineRanges(
                for: projection.lines,
                in: highlighted.attributedString
            )
        else {
            return [:]
        }

        var result: [Int: GitLabDiffHighlightedLine] = [:]
        result.reserveCapacity(
            projection.ordinals.count
        )
        for index in projection.lines.indices {
            if index.isMultiple(of: 256) {
                try Task.checkCancellation()
            }
            result[projection.ordinals[index]] =
                GitLabDiffHighlightedLine(
                    source: highlighted,
                    range: ranges[index]
                )
        }
        return result
    }

    private static func projections(
        for items: ArraySlice<GitLabDiffRenderItem>
    ) throws -> (old: Projection, new: Projection) {
        var oldLines: [String] = []
        var oldOrdinals: [Int] = []
        var newLines: [String] = []
        var newOrdinals: [Int] = []

        for (index, item) in items.enumerated() {
            if index.isMultiple(of: 256) {
                try Task.checkCancellation()
            }
            guard let line = item.line else {
                continue
            }
            switch line.kind {
            case .context:
                oldLines.append(line.text)
                oldOrdinals.append(line.ordinal)
                newLines.append(line.text)
                newOrdinals.append(line.ordinal)
            case .addition:
                newLines.append(line.text)
                newOrdinals.append(line.ordinal)
            case .deletion:
                oldLines.append(line.text)
                oldOrdinals.append(line.ordinal)
            }
        }

        return (
            old: Projection(
                lines: oldLines,
                ordinals: oldOrdinals
            ),
            new: Projection(
                lines: newLines,
                ordinals: newOrdinals
            )
        )
    }

    private static func lineRanges(
        for lines: [String],
        in highlighted: NSAttributedString
    ) throws -> [NSRange]? {
        var ranges: [NSRange] = []
        ranges.reserveCapacity(lines.count)
        var location = 0
        for (index, line) in lines.enumerated() {
            if index.isMultiple(of: 256) {
                try Task.checkCancellation()
            }
            let length = line.utf16.count
            ranges.append(
                NSRange(
                    location: location,
                    length: length
                )
            )
            location += length + 1
        }
        guard
            max(0, location - 1)
                == highlighted.length
        else {
            return nil
        }
        return ranges
    }

    private static func projectedSourceByteCount(
        in document: GitLabParsedDiffDocument
    ) throws -> Int {
        var byteCount = 0
        var projectedLineCount = 0
        for (index, item) in document.items.enumerated() {
            if index.isMultiple(of: 256) {
                try Task.checkCancellation()
            }
            guard let line = item.line else {
                continue
            }
            let projectionCount =
                line.kind == .context ? 2 : 1
            byteCount +=
                line.text.utf8.count
                * projectionCount
            projectedLineCount += projectionCount
            guard
                byteCount
                    <= maximumProjectedSourceByteCount
            else {
                return byteCount
            }
        }
        return byteCount
            + max(0, projectedLineCount - 1)
    }
}
