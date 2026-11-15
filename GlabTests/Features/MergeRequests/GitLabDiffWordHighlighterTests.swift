import Foundation
import Testing
@testable import Glab

@Suite("GitLab diff word highlighting")
struct GitLabDiffWordHighlighterTests {
    @Test("Identical lines produce only common segments")
    func identicalLinesAreCommon() {
        let segments = GitLabDiffWordHighlighter
            .segments(
                old: "let value = compute()",
                new: "let value = compute()"
            )

        #expect(
            segments.old
                .allSatisfy { $0.kind == .common }
        )
        #expect(
            segments.new
                .allSatisfy { $0.kind == .common }
        )
        #expect(
            segments.old.map(\.text).joined()
                == "let value = compute()"
        )
        #expect(
            segments.new.map(\.text).joined()
                == "let value = compute()"
        )
    }

    @Test("Replaced words are marked changed on both sides")
    func replacedWordSplitsSegments() {
        let segments = GitLabDiffWordHighlighter
            .segments(
                old: "fetchData(from: cache)",
                new: "fetchData(from: network)"
            )

        let oldChanged = segments.old
            .filter { $0.kind == .changed }
            .map(\.text)
            .joined()
        let newChanged = segments.new
            .filter { $0.kind == .changed }
            .map(\.text)
            .joined()
        #expect(oldChanged == "cache")
        #expect(newChanged == "network")
    }

    @Test("Segment concatenation reassembles the line exactly")
    func segmentsReassembleLines() throws {
        let pairs = [
            (
                "func render(with context: Context) -> Bool {",
                "func render(with layout: LayoutContext) -> Bool {"
            ),
            (
                "self.title = title ?? NSLocalizedString(\"missing\", comment: \"\")",
                "self.title = title ?? NSLocalizedString(\"fallback\", comment: \"\")"
            ),
            (
                "",
                "whole new line"
            ),
            (
                "removed entirely",
                ""
            ),
        ]

        for (old, new) in pairs {
            let segments =
                GitLabDiffWordHighlighter.segments(
                    old: old,
                    new: new
                )
            #expect(
                segments.old.map(\.text).joined()
                    == old
            )
            #expect(
                segments.new.map(\.text).joined()
                    == new
            )
        }
    }
}
