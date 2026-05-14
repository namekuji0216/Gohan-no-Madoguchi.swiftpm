import SwiftData
import Foundation

enum PantryItemType: String, Codable, CaseIterable {
    case seasoning  = "調味料"
    case meat       = "肉"
    case fish       = "魚"
    case vegetable  = "野菜"
    case other      = "その他"

    var icon: String {
        switch self {
        case .seasoning: "shaker.vertical"
        case .meat:      "fork.knife"
        case .fish:      "fish"
        case .vegetable: "leaf"
        case .other:     "bag"
        }
    }

    var presets: [String] {
        switch self {
        case .seasoning:
            ["塩", "コショウ", "醤油", "みりん", "料理酒", "砂糖", "酢", "味噌",
             "オリーブオイル", "サラダ油", "ごま油", "鶏がらスープの素", "コンソメ", "めんつゆ", "ケチャップ", "マヨネーズ"]
        case .meat:
            ["鶏むね肉", "鶏もも肉", "豚バラ", "豚こま切れ", "牛こま切れ", "合いびき肉", "ベーコン", "ソーセージ", "ハム"]
        case .fish:
            ["サーモン", "まぐろ", "あじ", "さば", "えび", "いか", "あさり", "ツナ缶", "さんま", "たら"]
        case .vegetable:
            ["レタス", "キャベツ", "玉ねぎ", "にんじん", "じゃがいも", "トマト", "きゅうり",
             "ほうれん草", "ブロッコリー", "なす", "ピーマン", "もやし", "長ねぎ", "にんにく", "しょうが", "大根"]
        case .other:
            ["卵", "豆腐", "牛乳", "チーズ", "ご飯", "パスタ", "食パン", "納豆", "こんにゃく", "油揚げ", "しらたき"]
        }
    }
}

@Model
final class PantryItem {
    var name: String
    // SwiftData での Codable enum 直接保存は不安定なため rawValue の String で保持する
    var typeRawValue: String
    var registeredAt: Date

    // computed property として列挙型アクセスを提供
    var type: PantryItemType {
        get { PantryItemType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    init(name: String, type: PantryItemType, registeredAt: Date = .now) {
        self.name = name
        self.typeRawValue = type.rawValue
        self.registeredAt = registeredAt
    }
}
