//
//  WorkPlaceListView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import SwiftData

// バイト先一覧・管理画面
struct WorkPlaceListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkPlace.createdAt, order: .reverse) private var workPlaces: [WorkPlace]

    var body: some View {
        List {
            if workPlaces.isEmpty {
                ContentUnavailableView(
                    "バイト先がありません",
                    systemImage: "building.2",
                    description: Text("よく使うバイト先を登録して、シフト入力を楽にしよう")
                )
            } else {
                ForEach(workPlaces, id: \.id) { workPlace in
                    WorkPlaceRowView(workPlace: workPlace)
                }
                .onDelete(perform: deleteWorkPlaces)
            }
        }
        .navigationTitle("バイト先管理")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    AddWorkPlaceView()
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
    }

    private func deleteWorkPlaces(at offsets: IndexSet) {
        for index in offsets {
            let workPlace = workPlaces[index]
            modelContext.delete(workPlace)
        }

        do {
            try modelContext.save()
        } catch {
            print("バイト先の削除に失敗しました: \(error.localizedDescription)")
        }
    }
}

// バイト先一覧の1行
struct WorkPlaceRowView: View {
    let workPlace: WorkPlace

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workPlace.name)
                .font(.headline)

            HStack(spacing: 12) {
                Label("時給 \(FormatHelper.yenText(workPlace.hourlyWage))", systemImage: "yensign.circle")
                Label("休憩 \(workPlace.defaultBreakMinutes)分", systemImage: "cup.and.saucer")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Label("\(workPlace.openingTimeText) 〜 \(workPlace.closingTimeText)", systemImage: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("全日ワード：\(workPlace.fullDayKeywords)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !workPlace.memo.isEmpty {
                Text(workPlace.memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}

// バイト先追加画面
struct AddWorkPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var hourlyWage = "1200"
    @State private var defaultBreakMinutes = "0"

    @State private var openingTimeText = "12:10"
    @State private var closingTimeText = "23:00"
    @State private var fullDayKeywords = "全日, オーラス, OL, ol, 通し"

    @State private var memo = ""

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section("バイト先情報") {
                TextField("バイト先名 例：ROOTS渋谷", text: $name)

                TextField("時給 例：1200", text: $hourlyWage)
                    .keyboardType(.numberPad)

                TextField("標準休憩時間（分）例：60", text: $defaultBreakMinutes)
                    .keyboardType(.numberPad)
            }

            Section("全日・オーラス設定") {
                TextField("開店時間 例：12:10 / 1210", text: $openingTimeText)
                    .keyboardType(.numbersAndPunctuation)

                TextField("閉店時間 例：23:00 / 2300", text: $closingTimeText)
                    .keyboardType(.numbersAndPunctuation)

                TextField("全日キーワード", text: $fullDayKeywords)

                Text("例：全日, オーラス, OL, ol, 通し")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("メモ") {
                TextField("メモ 例：通常時給、深夜ありなど", text: $memo, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button {
                    saveWorkPlace()
                } label: {
                    Text("保存する")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("バイト先追加")
        .navigationBarTitleDisplayMode(.inline)
        .alert("保存できません", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func saveWorkPlace() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty else {
            alertMessage = "バイト先名を入力してください。"
            showAlert = true
            return
        }

        guard let wage = Int(hourlyWage), wage > 0 else {
            alertMessage = "時給は1円以上の数字で入力してください。"
            showAlert = true
            return
        }

        guard let breakValue = Int(defaultBreakMinutes), breakValue >= 0 else {
            alertMessage = "休憩時間は0以上の数字で入力してください。"
            showAlert = true
            return
        }

        guard let normalizedOpeningTime = normalizeTimeInput(openingTimeText) else {
            alertMessage = "開店時間を正しく入力してください。例：12:10 / 1210"
            showAlert = true
            return
        }

        guard let normalizedClosingTime = normalizeTimeInput(closingTimeText) else {
            alertMessage = "閉店時間を正しく入力してください。例：23:00 / 2300"
            showAlert = true
            return
        }

        let newWorkPlace = WorkPlace(
            name: trimmedName,
            hourlyWage: wage,
            defaultBreakMinutes: breakValue,
            openingTimeText: normalizedOpeningTime,
            closingTimeText: normalizedClosingTime,
            fullDayKeywords: fullDayKeywords,
            memo: memo
        )

        modelContext.insert(newWorkPlace)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存中にエラーが発生しました。"
            showAlert = true
        }
    }

    private func normalizeTimeInput(_ input: String) -> String? {
        let text = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "時", with: ":")
            .replacingOccurrences(of: "分", with: "")

        if text.contains(":") {
            let parts = text.split(separator: ":").map(String.init)

            guard let hour = Int(parts[safe: 0] ?? ""),
                  hour >= 0,
                  hour <= 29 else {
                return nil
            }

            let minute: Int

            if let minuteText = parts[safe: 1], !minuteText.isEmpty {
                guard let parsedMinute = Int(minuteText),
                      parsedMinute >= 0,
                      parsedMinute <= 59 else {
                    return nil
                }

                minute = parsedMinute
            } else {
                minute = 0
            }

            return String(format: "%d:%02d", hour, minute)
        }

        let digits = text.filter { $0.isNumber }

        if digits.count == 4 {
            let hourText = String(digits.prefix(2))
            let minuteText = String(digits.suffix(2))

            guard let hour = Int(hourText),
                  let minute = Int(minuteText),
                  hour >= 0,
                  hour <= 29,
                  minute >= 0,
                  minute <= 59 else {
                return nil
            }

            return String(format: "%d:%02d", hour, minute)
        }

        if digits.count == 3 {
            let hourText = String(digits.prefix(1))
            let minuteText = String(digits.suffix(2))

            guard let hour = Int(hourText),
                  let minute = Int(minuteText),
                  hour >= 0,
                  hour <= 29,
                  minute >= 0,
                  minute <= 59 else {
                return nil
            }

            return String(format: "%d:%02d", hour, minute)
        }

        if digits.count <= 2, let hour = Int(digits), hour >= 0, hour <= 29 {
            return String(format: "%d:00", hour)
        }

        return nil
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
