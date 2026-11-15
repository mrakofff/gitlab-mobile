import SwiftUI

struct GitLabMergeRequestCreationView: View {
    struct Branch: Identifiable {
        let isSource: Bool
        var id: Bool { isSource }
    }

    @Bindable private var model:
        GitLabMergeRequestCreationModel
    @Environment(\.dismiss) private var dismiss
    @State private var pickingBranch: Branch?

    init(
        model: GitLabMergeRequestCreationModel
    ) {
        _model = Bindable(model)
    }

    var body: some View {
        NavigationStack {
            Form {
                branchesSection
                titleSection
                descriptionSection
                optionsSection
            }
            .navigationTitle("New merge request")
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(
                    placement: .cancellationAction
                ) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(model.isSubmitting)
                    .accessibilityIdentifier(
                        "mergeRequestCreation.cancel"
                    )
                }
            }
            .sheet(
                item: $pickingBranch
            ) { target in
                NavigationStack {
                    GitLabMergeRequestCreationBranchPickerView(
                        title: target.isSource
                            ? "Source branch"
                            : "Target branch",
                        selectedBranch: target
                            .isSource
                            ? model.sourceBranch
                            : model.targetBranch,
                        branchesModel:
                            model.branchesModel
                    ) { name in
                        if target.isSource {
                            model.sourceBranch = name
                        } else {
                            model.targetBranch = name
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .safeAreaInset(edge: .bottom) {
                createArea
            }
        }
    }

    private var branchesSection: some View {
        Section("Branches") {
            Button {
                pickingBranch = Branch(
                    isSource: true
                )
            } label: {
                branchLabel(
                    title: "Source branch",
                    branch: model.sourceBranch,
                    placeholder: "Select"
                )
            }
            .accessibilityIdentifier(
                "mergeRequestCreation.sourceBranch"
            )

            Button {
                pickingBranch = Branch(
                    isSource: false
                )
            } label: {
                branchLabel(
                    title: "Target branch",
                    branch: model.targetBranch,
                    placeholder: "main"
                )
            }
            .accessibilityIdentifier(
                "mergeRequestCreation.targetBranch"
            )
        }
    }

    private func branchLabel(
        title: String,
        branch: String,
        placeholder: String
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if branch.isEmpty {
                Text(placeholder)
                    .foregroundStyle(
                        Color.glabAccent
                    )
            } else {
                Text(branch)
                    .foregroundStyle(
                        Color.glabAccent
                    )
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Image(systemName: "chevron.right")
                .font(.glabFootnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    private var titleSection: some View {
        Section("Title") {
            TextField(
                "Title",
                text: $model.title
            )
            .accessibilityIdentifier(
                "mergeRequestCreation.title"
            )
        }
    }

    private var descriptionSection: some View {
        Section("Description") {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $model.description)
                    .frame(minHeight: 88)
                    .accessibilityIdentifier(
                        "mergeRequestCreation.description"
                    )
                if model.description.isEmpty {
                    Text("Description (optional)")
                        .foregroundStyle(.tertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private var optionsSection: some View {
        Section("Options") {
            Toggle(
                "Delete source branch when merged",
                isOn: $model.removeSourceBranch
            )
            Toggle(
                "Squash commits when merged",
                isOn: $model.squash
            )
        }
    }

    private var createArea: some View {
        VStack(spacing: 8) {
            if let failure = model.failureText {
                Label(
                    failure,
                    systemImage:
                        "exclamationmark.triangle.fill"
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )
            }
            if model.isSubmitting {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Creating merge request…")
                        .font(.glabSubheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            Button {
                Task {
                    await model.submit()
                }
            } label: {
                Label(
                    "Create merge request",
                    systemImage:
                        "arrow.triangle.pull"
                )
                .font(.glabCallout.weight(.semibold))
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.isValid)
            .accessibilityIdentifier(
                "mergeRequestCreation.create"
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
