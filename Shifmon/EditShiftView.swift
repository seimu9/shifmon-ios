//
//  EditShiftView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import SwiftData

// 登録済みシフトを編集する画面
struct EditShiftView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let shift: WorkShift

    @State private var workplaceName: String
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var hourlyWage: String
    @State private var nightHourlyWage: String
    @State private var transportationCost: String
    @State private var breakMinutes: String
    @State private var memo: String

    @State private var showAlert = false
    @State private var alertMessage = ""

    init(shift: WorkShift) {
        self.shift = shift
        _workplaceName = State(initialValue: shift.workplaceName)
        _startTime = State(initialValue: shift.startTime)
        _endTime = State(initialValue: shift.endTime)
        _hourlyWage = State(initialValue: String(shift.hourlyWage))
        _nightHourlyWage = State(initialValue: String(shift.effectiveNightHourlyWage))
        _transportationCost = State(initialValue: String(shift.transportationCost))
        _breakMinutes = State(initialValue: String(shift.breakMinutes))
        _memo = State(initialValue: shift.memo)
    }

    var body: some View {
        Form {
            Section("勤務情報") {
                TextField("勤務先 例：ROOTS渋谷", text: $workplaceName)

                DatePicker(
                    "開始",
                    selection: $startTime,
                    displayedComponents: [.date, .hourAndMinute]
                )

                DatePicker(
                    "終了",
                    selection: $endTime,
                    displayedComponents: [.date, .hourAndMinute]
                )
            }

            Section("給料情報") {
                TextField("時給 例：1200", text: $hourlyWage)
                    .keyboardType(.numberPad)

                TextField("深夜時給 例：1500", text: $nightHourlyWage)
                    .keyboardType(.numberPad)

                TextField("交通費 例：500", text: $transportationCost)
                    .keyboardType(.numberPad)

                TextField("休憩時間（分）例：60", text: $breakMinutes)
                    .keyboardType(.numberPad)
            }

            Section("メモ") {
                TextField("メモ 例：遅番、ヘルプなど", text: $memo, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button {
                    updateShift()
                } label: {
                    Text("変更を保存する")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("シフト編集")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: startTime) {
            applyAutomaticBreakTime()
        }
        .onChange(of: endTime) {
            applyAutomaticBreakTime()
        }
        .alert("保存できません", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func applyAutomaticBreakTime() {
        let autoBreakMinutes = BreakRuleHelper.automaticBreakMinutes(
            startTime: startTime,
            endTime: endTime
        )
        breakMinutes = String(autoBreakMinutes)
    }

    private func updateShift() {
        applyAutomaticBreakTime()

        let trimmedWorkplaceName = workplaceName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalWorkplaceName = trimmedWorkplaceName.isEmpty ? "バイト先未設定" : trimmedWorkplaceName

        guard endTime > startTime else {
            alertMessage = "終了時間は開始時間より後にしてください。"
            showAlert = true
            return
        }

        guard let wage = Int(hourlyWage), wage > 0 else {
            alertMessage = "時給は1円以上の数字で入力してください。"
            showAlert = true
            return
        }

        let trimmedNightHourlyWage = nightHourlyWage.trimmingCharacters(in: .whitespacesAndNewlines)
        let nightWage: Int

        if trimmedNightHourlyWage.isEmpty || trimmedNightHourlyWage == "0" {
            nightWage = WorkPlace.defaultNightHourlyWage(for: wage)
        } else if let parsedNightWage = Int(trimmedNightHourlyWage), parsedNightWage > 0 {
            nightWage = parsedNightWage
        } else {
            alertMessage = "深夜時給は0以上の数字で入力してください。"
            showAlert = true
            return
        }

        guard let transportation = Int(transportationCost), transportation >= 0 else {
            alertMessage = "交通費は0以上の数字で入力してください。"
            showAlert = true
            return
        }

        guard let breakValue = Int(breakMinutes), breakValue >= 0 else {
            alertMessage = "休憩時間は0以上の数字で入力してください。"
            showAlert = true
            return
        }

        shift.workplaceName = finalWorkplaceName
        shift.startTime = startTime
        shift.endTime = endTime
        shift.hourlyWage = wage
        shift.nightHourlyWage = nightWage
        shift.transportationCost = transportation
        shift.breakMinutes = breakValue
        shift.memo = memo

        do {
            try modelContext.save()

            CalendarEventManager.shared.updateShiftCalendarEvent(
                identifier: shift.calendarEventIdentifier,
                workplaceName: finalWorkplaceName,
                startTime: startTime,
                endTime: endTime,
                memo: memo
            ) { eventIdentifier in
                if shift.calendarEventIdentifier == nil,
                   let eventIdentifier {
                    shift.calendarEventIdentifier = eventIdentifier
                    try? modelContext.save()
                }
            }

            dismiss()
        } catch {
            alertMessage = "保存中にエラーが発生しました。"
            showAlert = true
        }
    }
}
