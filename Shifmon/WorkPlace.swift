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
    var id: UUID = UUID()
    var name: String = ""

    // 給料設定
    var hourlyWage: Int = 1200
    var nightHourlyWage: Int = 1500
    var transportationCost: Int = 0

    // 給料日設定
    var closingDay: Int = 31
    var payday: Int = 25

    // シフト読み取り設定
    var openingTimeText: String = "12:10"
    var closingTimeText: String = "23:00"
    var fullDayKeywords: String = "全日, オーラス, OL, ol, 通し"

    // 連携設定
    var isCalendarSyncEnabled: Bool = true

    // その他
    var defaultBreakMinutes: Int = 0
    var memo: String = ""
    var createdAt: Date = Date()

    var fullDayKeywordList: [String] {
        fullDayKeywords
            .replacingOccurrences(of: "、", with: ",")
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    var effectiveNightHourlyWage: Int {
        nightHourlyWage > 0 ? nightHourlyWage : Self.defaultNightHourlyWage(for: hourlyWage)
    }

    static func defaultNightHourlyWage(for hourlyWage: Int) -> Int {
        Int((Double(hourlyWage) * 1.25).rounded())
    }

    init(
        name: String,
        hourlyWage: Int,
        nightHourlyWage: Int = 0,
        transportationCost: Int = 0,
        closingDay: Int = 31,
        payday: Int = 25,
        openingTimeText: String = "12:10",
        closingTimeText: String = "23:00",
        fullDayKeywords: String = "全日, オーラス, OL, ol, 通し",
        isCalendarSyncEnabled: Bool = true,
        defaultBreakMinutes: Int = 0,
        memo: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.hourlyWage = hourlyWage
        self.nightHourlyWage = nightHourlyWage > 0 ? nightHourlyWage : Self.defaultNightHourlyWage(for: hourlyWage)
        self.transportationCost = transportationCost
        self.closingDay = closingDay
        self.payday = payday
        self.openingTimeText = openingTimeText
        self.closingTimeText = closingTimeText
        self.fullDayKeywords = fullDayKeywords
        self.isCalendarSyncEnabled = isCalendarSyncEnabled
        self.defaultBreakMinutes = defaultBreakMinutes
        self.memo = memo
        self.createdAt = Date()
    }
}
