import SwiftUI

/// Adds a "+" toolbar button and presents the New merge request
/// sheet; after a successful creation the flow opens the fresh
/// merge request detail.
struct GitLabProjectMergeRequestCreationModifier:
    ViewModifier
{
    let project: GitLabProject
    let apiAccess: GitLabAPIAccess
    let branchLoader: any GitLabRepositoryBrowsing
    let creationService:
        any GitLabMergeRequestCreationServing
    let accountID: GitLabAccountID
    let appSession: AppSession
    let onCreated: (GitLabMergeRequest) -> Void

    @State private var isPresented = false

    func body(
        content: Content
    ) -> some View {
        content
            .toolbar {
                if apiAccess.canWrite {
                    ToolbarItem(
                        placement:
                            .topBarTrailing
                    ) {
                        Button {
                            isPresented = true
                        } label: {
                            Image(
                                systemName: "plus"
                            )
                        }
                        .accessibilityLabel(
                            "New merge request in \(project.name)"
                        )
                        .accessibilityIdentifier(
                            "projectMergeRequests.newMergeRequestButton"
                        )
                    }
                }
            }
            .sheet(isPresented: $isPresented) {
                GitLabMergeRequestCreationView(
                    model:
                        GitLabMergeRequestCreationModel(
                            projectID: project.id,
                            projectDefaultBranch:
                                project
                                .defaultBranch,
                            branchLoader:
                                branchLoader,
                            service:
                                creationService,
                            isAccountCurrent: {
                                appSession
                                    .activeAccountID
                                    == accountID
                            },
                            onCreated: {
                                mergeRequest in
                                isPresented = false
                                onCreated(
                                    mergeRequest
                                )
                            }
                        )
                )
                .presentationDragIndicator(
                    .visible
                )
            }
    }
}

extension View {
    func gitLabProjectMergeRequestCreation(
        project: GitLabProject,
        apiAccess: GitLabAPIAccess,
        branchLoader: any GitLabRepositoryBrowsing,
        creationService:
            any GitLabMergeRequestCreationServing,
        accountID: GitLabAccountID,
        appSession: AppSession,
        onCreated:
            @escaping (GitLabMergeRequest) -> Void
    ) -> some View {
        modifier(
            GitLabProjectMergeRequestCreationModifier(
                project: project,
                apiAccess: apiAccess,
                branchLoader: branchLoader,
                creationService:
                    creationService,
                accountID: accountID,
                appSession: appSession,
                onCreated: onCreated
            )
        )
    }
}
