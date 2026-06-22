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
    var memo: String
    var createdAt: Date

    init(
        name: String,
        hourlyWage: Int,
        defaultBreakMinutes: Int,
        memo: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.hourlyWage = hourlyWage
        self.defaultBreakMinutes = defaultBreakMinutes
        self.memo = memo
        self.createdAt = Date()
    }
}
