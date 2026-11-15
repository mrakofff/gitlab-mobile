import SwiftUI

struct GitLabStatTile<Icon: View>: View {
    let title: String
    var tint: Color = .glabAccent
    let value: String
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        VStack(spacing: 2) {
            icon()
                .font(.glabSubheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(height: 18)
                .accessibilityHidden(true)

            Text(value)
                .font(.glabTitle3.bold())
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(.primary)

            Text(title)
                .font(.glabCaption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .frame(minHeight: 80)
        .glassEffect(
            .regular.tint(tint.opacity(0.12)).interactive(),
            in: .rect(cornerRadius: 16)
        )
        .contentShape(.rect(cornerRadius: 16))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(value)
    }
}

struct GitLabStatTileRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GlassEffectContainer(spacing: 8) {
            LazyVGrid(
                columns: Array(
                    repeating: GridItem(
                        .flexible(),
                        spacing: 8
                    ),
                    count:
                        dynamicTypeSize.isAccessibilitySize
                        ? 2
                        : 4
                ),
                spacing: 8
            ) {
                content()
            }
        }
    }
}
