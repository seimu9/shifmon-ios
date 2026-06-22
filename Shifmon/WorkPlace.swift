//
//  WorkPlace.swift
//  Shifmon
//
//  Created by seimu9.
//

import Foundation
import SwiftData

// バイト先情報を保存するデータモデル
@Model
final class WorkPlace {
    var id: UUID
    var name: String
    var hourlyWage: Int
    var defaultBreakMinutes: Int

    // 全日・オーラス判定用
    var openingTimeText: String = "12:10"
    var closingTimeText: String = "23:00"
    var fullDayKeywords: String = "全日, オーラス, OL, ol, 通し"

    var memo: String
    var createdAt: Date

    init(
        name: String,
        hourlyWage: Int,
        defaultBreakMinutes: Int,
        openingTimeText: String = "12:10",
        closingTimeText: String = "23:00",
        fullDayKeywords: String = "全日, オーラス, OL, ol, 通し",
        memo: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.hourlyWage = hourlyWage
        self.defaultBreakMinutes = defaultBreakMinutes
        self.openingTimeText = openingTimeText
        self.closingTimeText = closingTimeText
        self.fullDayKeywords = fullDayKeywords
        self.memo = memo
        self.createdAt = Date()
    }

    var fullDayKeywordList: [String] {
        fullDayKeywords
            .replacingOccurrences(of: "、", with: ",")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
