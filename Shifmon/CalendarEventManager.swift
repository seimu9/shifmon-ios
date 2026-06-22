//
//  CalendarEventManager.swift
//  Shifmon
//
//  Created by seimu9.
//

import Foundation
import EventKit

// iPhone標準カレンダーへシフト予定を追加する管理クラス
final class CalendarEventManager {
    static let shared = CalendarEventManager()

    private let eventStore = EKEventStore()

    private init() {}

    func addShiftToCalendar(
        workplaceName: String,
        startTime: Date,
        endTime: Date,
        memo: String
    ) {
        requestCalendarAccess { [weak self] granted, error in
            guard let self else { return }

            if let error {
                print("カレンダー権限の取得に失敗しました: \(error.localizedDescription)")
                return
            }

            guard granted else {
                print("カレンダーへのアクセスが許可されていません。")
                return
            }

            let event = EKEvent(eventStore: self.eventStore)
            event.title = "勤務：\(workplaceName)"
            event.startDate = startTime
            event.endDate = endTime
            event.notes = memo.isEmpty
                ? "Shifmonから追加"
                : "\(memo)\n\nShifmonから追加"
            event.calendar = self.eventStore.defaultCalendarForNewEvents

            do {
                try self.eventStore.save(event, span: .thisEvent)
                print("標準カレンダーにシフトを追加しました。")
            } catch {
                print("標準カレンダーへの追加に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    private func requestCalendarAccess(
        completion: @escaping (Bool, Error?) -> Void
    ) {
        if #available(iOS 17.0, *) {
            eventStore.requestWriteOnlyAccessToEvents { granted, error in
                completion(granted, error)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                completion(granted, error)
            }
        }
    }
}
