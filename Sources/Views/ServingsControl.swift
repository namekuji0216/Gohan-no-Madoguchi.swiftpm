import SwiftUI

struct ServingsControl: View {
    @Binding var servings: Int
    var range: ClosedRange<Int> = 1...10

    var body: some View {
        HStack(spacing: 12) {
            Button {
                if servings > range.lowerBound { servings -= 1 }
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(servings > range.lowerBound ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)

            Text("\(servings)人分")
                .font(.body.bold())
                .frame(minWidth: 56, alignment: .center)

            Button {
                if servings < range.upperBound { servings += 1 }
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(servings < range.upperBound ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
            }
            .buttonStyle(.plain)
        }
    }
}
