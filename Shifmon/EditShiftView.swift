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
        .alert("保存できません", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func updateShift() {
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

        guard let breakValue = Int(breakMinutes), breakValue >= 0 else {
            alertMessage = "休憩時間は0以上の数字で入力してください。"
            showAlert = true
            return
        }

        shift.workplaceName = finalWorkplaceName
        shift.startTime = startTime
        shift.endTime = endTime
        shift.hourlyWage = wage
        shift.breakMinutes = breakValue
        shift.memo = memo

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存中にエラーが発生しました。"
            showAlert = true
        }
    }
}
