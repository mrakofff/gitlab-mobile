import SwiftUI

struct GitLabMergeRequestCreationBranchPickerView:
    View
{
    let title: String
    let selectedBranch: String
    let branchesModel:
        GitLabRepositoryBranchesModel
    let select: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            Group {
                if branchesModel.isLoadingInitial {
                    GitLabContentStateScrollView {
                        GitLabLoadingStateView(
                            message:
                                "Loading branches"
                        )
                    }
                } else if
                    branchesModel.items.isEmpty,
                    let error =
                        branchesModel.loadError
                {
                    GitLabContentStateScrollView {
                        GitLabRetryStateView(
                            error: error
                        ) {
                            Task {
                                await branchesModel
                                    .refresh()
                            }
                        }
                    }
                } else {
                    branchList
                }
            }
            .background(Color.glabCanvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(
                edge: .top,
                spacing: 0
            ) {
                GitLabSearchField(
                    text: $searchText,
                    prompt: "Find a branch",
                    accessibilityIdentifier:
                        "mergeRequestCreation.branchSearch"
                )
            }
            .toolbar {
                ToolbarItem(
                    placement:
                        .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                await branchesModel.loadIfNeeded()
            }
        }
    }

    private var filteredBranches:
        [GitLabRepositoryBranch]
    {
        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )
        let branches = branchesModel
            .sortedRepositoryBranches
        guard !query.isEmpty else {
            return branches
        }
        return branches.filter {
            $0.name.localizedStandardContains(
                query
            )
        }
    }

    private var branchList: some View {
        GlabList {
            ForEach(filteredBranches) { branch in
                Button {
                    select(branch.name)
                    dismiss()
                } label: {
                    HStack(spacing: 10) {
                        Image(
                            systemName:
                                "arrow.triangle.branch"
                        )
                        .foregroundStyle(
                            Color.glabAccent
                        )
                        .accessibilityHidden(true)

                        VStack(
                            alignment: .leading,
                            spacing: 2
                        ) {
                            Text(branch.name)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .truncationMode(.middle)

                            if branch.isDefault {
                                Text("Default")
                                    .font(.glabCaption)
                                    .foregroundStyle(
                                        .secondary
                                    )
                            }
                        }

                        Spacer(minLength: 8)

                        if branch.name
                            == selectedBranch
                        {
                            Image(
                                systemName:
                                    "checkmark"
                            )
                            .font(.glabBody.bold())
                            .foregroundStyle(
                                Color.glabAccent
                            )
                            .accessibilityLabel(
                                "Selected"
                            )
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .task {
                    await branchesModel
                        .loadNextPageIfNeeded(
                            after: branch
                        )
                }
            }
        }
    }
}
