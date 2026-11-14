import Foundation
import Testing
@testable import Glab

@Suite("GitLab project overview contract")
struct GitLabProjectOverviewTests {
    @Test("Decodes languages sorted by share and drops invalid values")
    func decodesLanguages() throws {
        let json = Data(
            """
            {
              "Swift": 61.5,
              "Ruby": 30.25,
              "Shell": 8.25,
              "Broken": "n/a",
              "Empty": 0
            }
            """.utf8
        )

        let languages = try JSONDecoder().decode(
            GitLabProjectLanguages.self,
            from: json
        )

        #expect(
            languages.items.map(\.name)
                == ["Swift", "Ruby", "Shell"]
        )
        #expect(languages.items.first?.percentage == 61.5)
    }

    @Test("Decodes empty languages object")
    func decodesEmptyLanguages() throws {
        let languages = try JSONDecoder().decode(
            GitLabProjectLanguages.self,
            from: Data("{}".utf8)
        )

        #expect(languages.items.isEmpty)
    }

    @Test("Decodes optional description and counters when present")
    func decodesProjectOverviewFields() throws {
        let json = Data(
            """
            {
              "id": 7,
              "name": "App",
              "name_with_namespace": "Team / App",
              "path_with_namespace": "team/app",
              "star_count": 1,
              "last_activity_at": "2026-07-25T12:00:00Z",
              "visibility": "private",
              "description": "  Native client  ",
              "open_issues_count": 4,
              "forks_count": 2
            }
            """.utf8
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let project = try decoder.decode(
            GitLabProject.self,
            from: json
        )

        #expect(project.trimmedDescription == "Native client")
        #expect(project.openIssuesCount == 4)
        #expect(project.forksCount == 2)
    }

    @Test("Builds the project pipelines request")
    func buildsProjectPipelinesRequest() throws {
        let request = try #require(
            GitLabPipelineEndpoints.projectPipelines(
                projectID: 9
            )
        )

        #expect(
            request.pathComponents
                == ["projects", "9", "pipelines"]
        )
        #expect(
            request.queryItems.first {
                $0.name == "per_page"
            }?.value == "25"
        )
        #expect(
            GitLabPipelineEndpoints.projectPipelines(
                projectID: 0
            ) == nil
        )
    }
}
