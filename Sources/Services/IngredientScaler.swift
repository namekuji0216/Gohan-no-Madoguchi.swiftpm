import Foundation

enum IngredientScaler {
    /// 食材リストの分量を人数比で比例換算する
    static func scale(_ ingredients: [String], from original: Int, to target: Int) -> [String] {
        guard original > 0, target > 0, original != target else { return ingredients }
        let ratio = Double(target) / Double(original)
        return ingredients.map { scaleLine($0, ratio: ratio) }
    }

    private static func scaleLine(_ text: String, ratio: Double) -> String {
        // 数字（整数・小数）を検出して比例換算。分数・"少々"等の非数値はそのまま残す
        text.replacing(/\d+(?:\.\d+)?/) { match -> String in
            guard let value = Double(String(match.output)), value > 0 else {
                return String(match.output)
            }
            let scaled = value * ratio
            // 誤差が小さければ整数で返す
            if abs(scaled.rounded() - scaled) < 0.05 {
                return String(Int(scaled.rounded()))
            }
            // 0.5 刻みは ".5" で返す、それ以外は小数第1位
            if abs((scaled * 2).rounded() / 2 - scaled) < 0.05 {
                return String(format: "%.1f", (scaled * 2).rounded() / 2)
            }
            return String(format: "%.1f", scaled)
        }
    }
}
