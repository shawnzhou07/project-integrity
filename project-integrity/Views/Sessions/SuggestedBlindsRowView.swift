// Refer to UI_MASTER.md at project root before making UI changes.
import SwiftUI

struct SuggestedBlindsRowView: View {
    let suggestions: [BlindSuggestion]
    let emptyMessage: String
    let onSelect: (BlindSuggestion) -> Void

    // Approximate max height for 3 chip rows: ~33pt chip + 8pt gap, × 3 rows
    private let maxChipRowsHeight: CGFloat = 33 * 3 + 8 * 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Suggested blinds")
                .font(.caption)
                .foregroundColor(.appSecondary)
            if suggestions.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundColor(.appSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 33)
            } else {
                _FlowLayout(spacing: 8) {
                    ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                        Button {
                            onSelect(suggestion)
                        } label: {
                            Text(suggestion.chipLabel)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.appPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.appSurface2)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxHeight: maxChipRowsHeight, alignment: .top)
                .clipped()
            }
        }
        .listRowBackground(Color.appSurface)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }
}

private struct _FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        compute(subviews: subviews, width: proposal.width ?? 0).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = compute(subviews: subviews, width: bounds.width).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                          proposal: .unspecified)
        }
    }

    private func compute(subviews: Subviews, width: CGFloat) -> (origins: [CGPoint], size: CGSize) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let sz = subview.sizeThatFits(.unspecified)
            if x + sz.width > width, x > 0 {
                y += lineHeight + spacing
                x = 0
                lineHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            lineHeight = max(lineHeight, sz.height)
            x += sz.width + spacing
        }

        return (origins, CGSize(width: width, height: y + lineHeight))
    }
}
