import SwiftUI

struct GlabAppFooter: View {
    var body: some View {
        VStack(spacing: 6) {
            Text("v\(appVersion)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)

            Text("Made with ❤️ by")
                .font(.glabCaption)
                .foregroundStyle(.secondary)

            Link(destination: repositoryURL) {
                Text(repositoryOwner)
                    .font(.glabCaption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .underline()
            }
            .accessibilityLabel("View GitLab Mobile on GitHub")
            .accessibilityIdentifier("app.githubLink")
        }
    }

    /// Shown in the footer; kept in one place so rebranding touches a
    /// single constant.
    private var repositoryOwner: String {
        "Mrakoff"
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.0"
    }

    private var repositoryURL: URL {
        URL(string: "https://github.com/mrakofff/gitlab-mobile")!
    }
}
