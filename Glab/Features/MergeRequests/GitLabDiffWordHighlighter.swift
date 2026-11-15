import Foundation

/// Word-level diff segments for a pair of changed lines. Tokens marked
/// `.changed` carry the prominence tint; `.common` tokens stay plain.
nonisolated enum GitLabDiffWordSegmentKind:
    Equatable,
    Sendable
{
    case common
    case changed
}

nonisolated struct GitLabDiffWordSegment:
    Equatable,
    Sendable
{
    let text: String
    let kind: GitLabDiffWordSegmentKind
}

nonisolated enum GitLabDiffWordHighlighter {
    /// Splits both lines into words and pairs them with an LCS pass so
    /// unchanged words stay plain while inserted or removed words get
    /// highlighted inside their line.
    static func segments(
        old: String,
        new: String
    ) -> (
        old: [GitLabDiffWordSegment],
        new: [GitLabDiffWordSegment]
    ) {
        let oldTokens = tokens(for: old)
        let newTokens = tokens(for: new)
        let matches = longestCommonMatches(
            oldTokens,
            newTokens
        )
        return (
            old: segments(
                for: oldTokens,
                matchedIndices: matches.old
            ),
            new: segments(
                for: newTokens,
                matchedIndices: matches.new
            )
        )
    }

    /// Alternating word and separator runs: separate tokens keep
    /// whitespace/punctuation boundaries so segments reassemble the line
    /// exactly.
    private static func tokens(
        for line: String
    ) -> [String] {
        var tokens: [String] = []
        var current: Substring?

        func flush() {
            if let token = current {
                tokens.append(String(token))
                current = nil
            }
        }

        func append(
            _ character: Character,
            extendsWord: Bool
        ) {
            if let token = current, isWord(token.first) == extendsWord
                || (extendsWord && token.last == "_")
            {
                current = token + Substring(String(character))
            } else {
                flush()
                current = Substring(String(character))
            }
        }

        for character in line {
            let isWordCharacter =
                character.isLetter || character.isNumber
            append(character, extendsWord: isWordCharacter)
        }
        flush()
        return tokens
    }

    private static func isWord(
        _ character: Character?
    ) -> Bool {
        guard let character else {
            return false
        }
        return character.isLetter || character.isNumber
    }

    /// LCS-based pairing of the indices that stay common in both lines.
    private static func longestCommonMatches(
        _ oldTokens: [String],
        _ newTokens: [String]
    ) -> (
        old: [Int],
        new: [Int]
    ) {
        let oldCount = oldTokens.count
        let newCount = newTokens.count
        guard oldCount > 0, newCount > 0 else {
            return ([], [])
        }
        // Guard against pathological inputs: the quadratic table is not
        // worth it for two very long dissimilar lines.
        guard oldCount * newCount <= 4_000_000 else {
            return ([], [])
        }

        let width = newCount + 1
        var table = [Int](
            repeating: 0,
            count: (oldCount + 1) * width
        )
        for oldIndex in stride(
            from: oldCount - 1,
            through: 0,
            by: -1
        ) {
            for newIndex in stride(
                from: newCount - 1,
                through: 0,
                by: -1
            ) {
                let cell = oldIndex * width + newIndex
                if oldTokens[oldIndex] == newTokens[newIndex] {
                    table[cell] =
                        table[(oldIndex + 1) * width + newIndex + 1] + 1
                } else {
                    table[cell] = max(
                        table[(oldIndex + 1) * width + newIndex],
                        table[oldIndex * width + newIndex + 1]
                    )
                }
            }
        }

        var oldMatches: [Int] = []
        var newMatches: [Int] = []
        var oldIndex = 0
        var newIndex = 0
        while oldIndex < oldCount, newIndex < newCount {
            if oldTokens[oldIndex] == newTokens[newIndex] {
                oldMatches.append(oldIndex)
                newMatches.append(newIndex)
                oldIndex += 1
                newIndex += 1
            } else if
                table[(oldIndex + 1) * width + newIndex]
                    >= table[oldIndex * width + newIndex + 1]
            {
                oldIndex += 1
            } else {
                newIndex += 1
            }
        }
        return (old: oldMatches, new: newMatches)
    }

    private static func segments(
        for tokens: [String],
        matchedIndices: [Int]
    ) -> [GitLabDiffWordSegment] {
        guard !tokens.isEmpty else {
            return []
        }
        let matched = Set(matchedIndices)
        var segments: [GitLabDiffWordSegment] = []
        segments.reserveCapacity(tokens.count)

        var pendingKind: GitLabDiffWordSegmentKind?
        var pendingText = ""

        func flush() {
            guard let kind = pendingKind else {
                return
            }
            segments.append(
                GitLabDiffWordSegment(
                    text: pendingText,
                    kind: kind
                )
            )
            pendingKind = nil
            pendingText = ""
        }

        for (index, token) in tokens.enumerated() {
            let kind: GitLabDiffWordSegmentKind =
                matched.contains(index) ? .common : .changed
            if pendingKind == kind {
                pendingText += token
            } else {
                flush()
                pendingKind = kind
                pendingText = token
            }
        }
        flush()

        return segments
    }
}
