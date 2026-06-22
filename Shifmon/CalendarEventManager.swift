//
//  CalendarEventManager.swift
//  Shifmon
//
//  Created by seimu9.
//

import Foundation
import EventKit

// iPhone標準カレンダーへシフト予定を追加・更新・削除する管理クラス
final class CalendarEventManager {
    static let shared = CalendarEventManager()

    private let eventStore = EKEventStore()

    private init() {}

    // シフトを標準カレンダーに追加し、作成されたイベントIDを返す
    func addShiftToCalendar(
        workplaceName: String,
        startTime: Date,
        endTime: Date,
        memo: String,
        completion: ((String?) -> Void)? = nil
    ) {
        requestCalendarAccess { [weak self] granted, error in
            guard let self else { return }

            if let error {
                print("カレンダー権限の取得に失敗しました: \(error.localizedDescription)")
                self.completeOnMain(completion, value: nil)
                return
            }

            guard granted else {
                print("カレンダーへのアクセスが許可されていません。")
                self.completeOnMain(completion, value: nil)
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
                self.completeOnMain(completion, value: event.eventIdentifier)
            } catch {
                print("標準カレンダーへの追加に失敗しました: \(error.localizedDescription)")
                self.completeOnMain(completion, value: nil)
            }
        }
    }

    // 登録済みの標準カレンダー予定を更新する
    // 既存IDがない場合は、新規追加として扱う
    func updateShiftCalendarEvent(
        identifier: String?,
        workplaceName: String,
        startTime: Date,
        endTime: Date,
        memo: String,
        completion: ((String?) -> Void)? = nil
    ) {
        requestCalendarAccess { [weak self] granted, error in
            guard let self else { return }

            if let error {
                print("カレンダー権限の取得に失敗しました: \(error.localizedDescription)")
                self.completeOnMain(completion, value: nil)
                return
            }

            guard granted else {
                print("カレンダーへのアクセスが許可されていません。")
                self.completeOnMain(completion, value: nil)
                return
            }

            guard let identifier,
                  let event = self.eventStore.event(withIdentifier: identifier) else {
                self.addShiftToCalendar(
                    workplaceName: workplaceName,
                    startTime: startTime,
                    endTime: endTime,
                    memo: memo,
                    completion: completion
                )
                return
            }

            event.title = "勤務：\(workplaceName)"
            event.startDate = startTime
            event.endDate = endTime
            event.notes = memo.isEmpty
                ? "Shifmonから更新"
                : "\(memo)\n\nShifmonから更新"

            do {
                try self.eventStore.save(event, span: .thisEvent)
                print("標準カレンダーのシフトを更新しました。")
                self.completeOnMain(completion, value: event.eventIdentifier)
            } catch {
                print("標準カレンダーの更新に失敗しました: \(error.localizedDescription)")
                self.completeOnMain(completion, value: nil)
            }
        }
    }

    // 標準カレンダー予定を削除する
    func deleteCalendarEvent(identifier: String?) {
        guard let identifier else { return }

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

            guard let event = self.eventStore.event(withIdentifier: identifier) else {
                print("削除対象のカレンダー予定が見つかりませんでした。")
                return
            }

            do {
                try self.eventStore.remove(event, span: .thisEvent)
                print("標準カレンダーのシフトを削除しました。")
            } catch {
                print("標準カレンダーの削除に失敗しました: \(error.localizedDescription)")
            }
        }
    }

    private func requestCalendarAccess(
        completion: @escaping (Bool, Error?) -> Void
    ) {
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                completion(granted, error)
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                completion(granted, error)
            }
        }
    }

    private func completeOnMain(
        _ completion: ((String?) -> Void)?,
        value: String?
    ) {
        DispatchQueue.main.async {
            completion?(value)
        }
    }
}
