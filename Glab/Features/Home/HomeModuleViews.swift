import SwiftUI

extension ProjectsModel {
    var recentHomeProjects: [GitLabHomeProject] {
        items.prefix(6).map { project in
            GitLabHomeProject(
                id: project.id,
                name: project.name,
                nameWithNamespace:
                    project.nameWithNamespace,
                pathWithNamespace:
                    project.pathWithNamespace,
                webURL: project.webURL
            )
        }
    }

    var starredHomeProjects: [GitLabHomeProject] {
        items.prefix(6).map { project in
                GitLabHomeProject(
                    id: project.id,
                    name: project.name,
                    nameWithNamespace:
                        project.nameWithNamespace,
                    pathWithNamespace:
                        project.pathWithNamespace,
                    webURL: project.webURL
                )
            }
    }
}

// MARK: - Module cards

struct HomePipelineCard: View {
    let item: GitLabHomePipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                Text(shortProjectPath)
                    .font(.glabSubheadline.weight(.semibold))
                    .lineLimit(1)
                    .layoutPriority(1)

                Spacer(minLength: 8)

                if let time = relativeTime {
                    Text(time)
                        .font(.glabCaption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            HStack(spacing: 5) {
                Text(item.pipeline.displayID)
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Image(systemName: "arrow.triangle.branch")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)

                Text(item.pipeline.ref)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .font(.glabCaption)
            .lineLimit(1)

            Text(item.pipeline.status.title)
                .font(.glabCaption.weight(.semibold))
                .foregroundStyle(item.pipeline.status.tint)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var shortProjectPath: String {
        let path = item.project.pathWithNamespace
        let components = path.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard components.count > 1 else {
            return path
        }
        return "…/"
            + (components.last.map(String.init) ?? path)
    }

    private var relativeTime: String? {
        guard
            let date =
                item.pipeline.updatedAt
                ?? item.pipeline.createdAt
        else {
            return nil
        }
        return GitLabRelativeTimeFormatter.string(
            from: date
        )
    }

    private var accessibilityLabel: String {
        [
            item.project.pathWithNamespace,
            item.pipeline.displayID,
            item.pipeline.ref,
            item.pipeline.status.title,
        ]
        .joined(separator: ", ")
    }
}

struct HomeProjectCard: View {
    let project: GitLabHomeProject

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                HomeProjectAvatarBadge(
                    name: project.name
                )
                .accessibilityHidden(true)

                Text(project.name)
                    .font(.glabBody.weight(.semibold))
                    .lineLimit(1)
                    .layoutPriority(1)
            }

            Text(project.pathWithNamespace)
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .frame(width: 240, alignment: .leading)
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(project.pathWithNamespace)
    }
}

struct HomeProjectAvatarBadge: View {
    let name: String
    var size: CGFloat = 36

    var body: some View {
        Text(initials)
            .font(
                .system(
                    size: size * 0.42,
                    weight: .semibold,
                    design: .rounded
                )
            )
            .foregroundStyle(.white)
            .frame(
                width: size,
                height: size
            )
            .background(
                Color(hue: hue, saturation: 0.45, brightness: 0.75),
                in: .rect(cornerRadius: size * 0.28)
            )
            .accessibilityHidden(true)
    }

    private var initials: String {
        let parts = name.split(separator: " ")
            .prefix(2)
        let text = parts.map {
            $0.first.map(String.init) ?? ""
        }.joined()
        return text.isEmpty
            ? String(name.prefix(1)).uppercased()
            : text.uppercased()
    }

    private var hue: Double {
        let scalar = name.unicodeScalars.first?.value ?? 0
        return Double(scalar % 360) / 360
    }
}

struct HomeModuleEmptyCard: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.glabBody.weight(.semibold))

            Text("Items will appear here when available.")
                .font(.glabCaption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .contentShape(.rect(cornerRadius: 16))
    }
}

struct HomeModulePlaceholderCard: View {
    var isLoading = false

    var body: some View {
        HStack(spacing: 8) {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Text(isLoading ? "Loading…" : "Could not load.")
                .font(.glabSubheadline)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
        .glassEffect(
            .regular.interactive(),
            in: .rect(cornerRadius: 16)
        )
        .contentShape(.rect(cornerRadius: 16))
    }
}

// MARK: - Module sections

struct HomeModuleHeader: View {
    let module: HomeModule
    let countText: String?
    let onSeeAll: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: module.systemImage)
                .font(.glabSubheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(module.title)
                .font(.glabHeadline)
                .foregroundStyle(.primary)

            if let countText {
                Text(countText)
                    .font(.glabCaption.weight(.semibold))
                    .monospacedDigit()
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(
                        Color.glabAccent.opacity(0.12),
                        in: .capsule
                    )
                    .foregroundStyle(Color.glabAccent)
            }

            Spacer(minLength: 8)

            if let onSeeAll {
                Button("See all", action: onSeeAll)
                    .font(.glabSubheadline)
            }
        }
        .textCase(nil)
    }

    init(
        module: HomeModule,
        countText: String? = nil,
        onSeeAll: (() -> Void)? = nil
    ) {
        self.module = module
        self.countText = countText
        self.onSeeAll = onSeeAll
    }
}

private let homeCarouselRowInset: CGFloat = 20

struct HomeCarouselSection<Content: View>: View {
    let content: () -> Content

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                content()
            }
            .padding(.horizontal, homeCarouselRowInset)
            .padding(.vertical, 6)
        }
        .padding(.horizontal, -homeCarouselRowInset)
        .scrollTargetBehavior(.viewAligned)
    }
}

// MARK: - Pipelines list screen

enum HomePipelineFilter: String, CaseIterable, Hashable {
    case attention = "Needs attention"
    case active = "Running"
    case failed = "Failed"
    case recent = "Recent"

    func matches(
        _ item: GitLabHomePipeline
    ) -> Bool {
        switch self {
        case .attention:
            item.pipeline.status
                .isActivelyChanging
                || item.pipeline.status.rawValue
                    == "failed"
        case .active:
            item.pipeline.status
                .isActivelyChanging
        case .failed:
            item.pipeline.status.rawValue
                == "failed"
        case .recent:
            true
        }
    }
}

struct HomePipelinesView: View {
    let model: HomePipelinesModel
    let loader: any GitLabHomePipelinesLoading
    let pipelineLoader: any GitLabPipelineLoading
    let accountID: GitLabAccountID
    let appSession: AppSession
    let apiAccess: GitLabAPIAccess

    @State private var filter: HomePipelineFilter =
        .attention

    var body: some View {
        GlabList {
            Section {
                Picker("Filter", selection: $filter) {
                    ForEach(
                        HomePipelineFilter.allCases,
                        id: \.self
                    ) { filter in
                        Text(filter.rawValue)
                            .tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(
                    .init(top: 4, leading: 0, bottom: 0, trailing: 0)
                )
            }

            pipelineRows
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Pipelines")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await model.refresh()
            await handleAuthenticationFailure()
        }
        .task {
            await model.loadIfNeeded()
            await handleAuthenticationFailure()
        }
    }

    @ViewBuilder
    private var pipelineRows: some View {
        let filtered = filteredPipelines

        if model.status == .loading,
            model.pipelines.isEmpty
        {
            HStack {
                Spacer()
                ProgressView("Loading pipelines…")
                    .font(.glabFootnote)
                Spacer()
            }
            .listRowBackground(Color.clear)
        } else if filtered.isEmpty {
            GitLabEmptyStateView(
                title: emptyTitle,
                message:
                    "Pipelines will show up here once CI runs.",
                gitLabIcon: .pipeline
            )
            .listRowBackground(Color.clear)
        } else {
            ForEach(filtered) { item in
                if
                    let route = item.route
                {
                    NavigationLink {
                        GitLabPipelineDetailView(
                            route: route,
                            cacheLifetime: item.pipeline
                                .detailCacheLifetime,
                            loader: pipelineLoader,
                            accountID: accountID,
                            appSession: appSession,
                            apiAccess: apiAccess
                        )
                    } label: {
                        HomePipelineListRow(
                            item: item
                        )
                    }
                    .accessibilityIdentifier(
                        "home.pipelines.row.\(item.id)"
                    )
                }
            }
        }
    }

    private var filteredPipelines:
        [GitLabHomePipeline]
    {
        model.pipelines.filter {
            filter.matches($0)
        }
    }

    private var emptyTitle: String {
        switch filter {
        case .attention:
            "Nothing needs attention"
        case .active:
            "No running pipelines"
        case .failed:
            "No failed pipelines"
        case .recent:
            "No pipelines"
        }
    }

    private func handleAuthenticationFailure()
        async
    {
        guard
            let error = model.loadError,
            model.status == .failed
        else {
            return
        }
        await appSession.handleAuthenticationFailure(
            error,
            for: accountID
        )
    }
}

struct HomePipelineListRow: View {
    let item: GitLabHomePipeline

    var body: some View {
        HStack(
            alignment: .top,
            spacing: 10
        ) {
            GitLabCIStatusIcon(
                status: item.pipeline.status
            )
            .padding(.top, 2)

            VStack(
                alignment: .leading,
                spacing: 4
            ) {
                Text(item.project.name)
                    .font(.glabBody.weight(.semibold))
                    .lineLimit(2)

                Text(
                    [
                        item.pipeline.displayID,
                        item.pipeline.ref,
                        item.pipeline.shortSHA,
                    ]
                    .joined(separator: "  ")
                )
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            [
                item.project.name,
                item.pipeline.displayID,
                item.pipeline.status.title,
            ]
            .joined(separator: ", ")
        )
    }
}

// MARK: - Edit Home sheet

struct HomeEditSheet: View {
    var layout: HomeLayout
    let onCancel: () -> Void
    let onSave: (HomeLayout) -> Void

    @State private var draft: HomeLayout

    init(
        layout: HomeLayout,
        onCancel: @escaping () -> Void,
        onSave: @escaping (HomeLayout) -> Void
    ) {
        self.layout = layout
        self.onCancel = onCancel
        self.onSave = onSave
        _draft = State(
            initialValue: layout.normalized()
        )
    }

    var body: some View {
        NavigationStack {
            GlabList {
                presetSection
                shownSection
                hiddenSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Edit Home")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(draft)
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var presetSection: some View {
        Section("Preset") {
            Picker("Preset", selection: presetSelection) {
                Text("Custom").tag(HomeLayoutPreset?.none)
                ForEach(
                    HomeLayoutPreset.allCases,
                    id: \.self
                ) { preset in
                    Text(preset.title)
                        .tag(HomeLayoutPreset?.some(preset))
                }
            }
            .labelsHidden()
        }
    }

    private var presetSelection:
        Binding<HomeLayoutPreset?>
    {
        Binding {
            draft.preset
        } set: { preset in
            guard let preset else {
                draft = HomeLayout(
                    shown: draft.shown,
                    hidden: draft.hidden,
                    preset: nil
                )
                return
            }
            draft = preset.layout
        }
    }

    private var shownSection: some View {
        Section {
            ForEach(draft.shown, id: \.self) {
                module in
                HomeEditModuleRow(module: module)
            }
            .onDelete { offsets in
                draft.shown.remove(atOffsets: offsets)
                draft.preset = nil
                draft = draft.normalized()
            }
        } header: {
            Text("Shown on Home")
        } footer: {
            Text(
                "Drag to reorder. Swipe to hide a module."
            )
        }
    }

    private var hiddenSection: some View {
        Section("Hidden") {
            ForEach(draft.hidden, id: \.self) {
                module in
                Button {
                    add(module)
                } label: {
                    HStack {
                        HomeEditModuleRow(
                            module: module
                        )
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(Color.glabAccent)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func add(_ module: HomeModule) {
        draft.hidden.removeAll { $0 == module }
        draft.shown.append(module)
        draft.preset = nil
        draft = draft.normalized()
    }
}

struct HomeEditModuleRow: View {
    let module: HomeModule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: module.systemImage)
                .font(.glabSubheadline)
                .foregroundStyle(Color.glabAccent)
                .frame(width: 24)
                .accessibilityHidden(true)

            Text(module.title)
                .font(.glabBody)
        }
        .padding(.vertical, 2)
    }
}
