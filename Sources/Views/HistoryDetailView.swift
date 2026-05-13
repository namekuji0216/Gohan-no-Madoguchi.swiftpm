import SwiftUI

struct HistoryDetailView: View {
    let recipe: RecipeHistory

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // 写真
                if let data = recipe.photoData, let ui = UIImage(data: data) {
                    Image(uiImage: ui)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                // 評価・日付
                HStack {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= recipe.rating ? "star.fill" : "star")
                                .foregroundStyle(.yellow)
                        }
                    }
                    Spacer()
                    Text(recipe.createdAt.formatted(date: .long, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // 材料
                VStack(alignment: .leading, spacing: 10) {
                    Label("材料", systemImage: "list.bullet")
                        .font(.headline)
                    ForEach(recipe.ingredients, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("・").foregroundStyle(.secondary)
                            Text(item)
                        }
                    }
                }

                // 手順
                VStack(alignment: .leading, spacing: 12) {
                    Label("作り方", systemImage: "text.alignleft")
                        .font(.headline)
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.callout.bold())
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(.tint, in: Circle())
                            Text(step)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(recipe.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
