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
                    NavigationLink {
                        EditWorkPlaceView(workPlace: workPlace)
                    } label: {
                        WorkPlaceRowView(workPlace: workPlace)
                    }
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
            modelContext.delete(workPlaces[index])
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(workPlace.name)
                        .font(.headline)

                    Text(workPlace.isCalendarSyncEnabled ? "標準カレンダー連携 ON" : "標準カレンダー連携 OFF")
                        .font(.caption)
                        .foregroundStyle(workPlace.isCalendarSyncEnabled ? .blue : .secondary)
                }

                Spacer()

                Image(systemName: "building.2.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
            }

            HStack(spacing: 10) {
                InfoChip(title: "通常", value: FormatHelper.yenText(workPlace.hourlyWage), systemImage: "yensign.circle")
                InfoChip(title: "深夜", value: nightWageText, systemImage: "moon.stars")
            }

            HStack(spacing: 10) {
                InfoChip(title: "交通費", value: transportationText, systemImage: "tram.fill")
                InfoChip(title: "休憩", value: "\(workPlace.defaultBreakMinutes)分", systemImage: "cup.and.saucer")
            }

            HStack(spacing: 10) {
                InfoChip(title: "営業時間", value: "\(workPlace.openingTimeText)〜\(workPlace.closingTimeText)", systemImage: "clock")
                InfoChip(title: "給料日", value: "\(dayText(workPlace.closingDay))締め/\(dayText(workPlace.payday))払い", systemImage: "calendar.badge.clock")
            }

            Text("全日ワード：\(workPlace.fullDayKeywords)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !workPlace.memo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(workPlace.memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    private var nightWageText: String {
        if workPlace.nightHourlyWage > 0 {
            return FormatHelper.yenText(workPlace.nightHourlyWage)
        } else {
            let defaultNightWage = WorkPlaceFormHelper.defaultNightHourlyWage(for: workPlace.hourlyWage)
            return "\(FormatHelper.yenText(defaultNightWage)) 自動"
        }
    }

    private var transportationText: String {
        workPlace.transportationCost > 0 ? FormatHelper.yenText(workPlace.transportationCost) : "なし"
    }

    private func dayText(_ day: Int) -> String {
        day >= 31 ? "月末" : "\(day)日"
    }
}

// 小さい情報チップ
struct InfoChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// バイト先追加画面
struct AddWorkPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var hourlyWage = "1200"
    @State private var nightHourlyWage = "0"
    @State private var transportationCost = "0"
    @State private var closingDay = 31
    @State private var payday = 25
    @State private var openingTimeText = "12:10"
    @State private var closingTimeText = "23:00"
    @State private var fullDayKeywords = "全日, オーラス, OL, ol, 通し"
    @State private var isCalendarSyncEnabled = true
    @State private var defaultBreakMinutes = "0"
    @State private var memo = ""

    @State private var showAlert = false
    @State private var alertMessage = ""

    private let dayOptions = Array(1...31)

    var body: some View {
        WorkPlaceFormView(
            title: "バイト先追加",
            name: $name,
            hourlyWage: $hourlyWage,
            nightHourlyWage: $nightHourlyWage,
            transportationCost: $transportationCost,
            closingDay: $closingDay,
            payday: $payday,
            openingTimeText: $openingTimeText,
            closingTimeText: $closingTimeText,
            fullDayKeywords: $fullDayKeywords,
            isCalendarSyncEnabled: $isCalendarSyncEnabled,
            defaultBreakMinutes: $defaultBreakMinutes,
            memo: $memo,
            buttonTitle: "保存する",
            dayOptions: dayOptions
        ) {
            saveWorkPlace()
        }
        .alert("保存できません", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func saveWorkPlace() {
        guard let values = validateFormValues(
            name: name,
            hourlyWage: hourlyWage,
            nightHourlyWage: nightHourlyWage,
            transportationCost: transportationCost,
            defaultBreakMinutes: defaultBreakMinutes,
            openingTimeText: openingTimeText,
            closingTimeText: closingTimeText,
            setError: { message in
                alertMessage = message
                showAlert = true
            }
        ) else {
            return
        }

        let newWorkPlace = WorkPlace(
            name: values.name,
            hourlyWage: values.hourlyWage,
            nightHourlyWage: values.nightHourlyWage,
            transportationCost: values.transportationCost,
            closingDay: closingDay,
            payday: payday,
            openingTimeText: values.openingTimeText,
            closingTimeText: values.closingTimeText,
            fullDayKeywords: fullDayKeywords,
            isCalendarSyncEnabled: isCalendarSyncEnabled,
            defaultBreakMinutes: values.defaultBreakMinutes,
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
}

// バイト先編集画面
struct EditWorkPlaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let workPlace: WorkPlace

    @State private var name: String
    @State private var hourlyWage: String
    @State private var nightHourlyWage: String
    @State private var transportationCost: String
    @State private var closingDay: Int
    @State private var payday: Int
    @State private var openingTimeText: String
    @State private var closingTimeText: String
    @State private var fullDayKeywords: String
    @State private var isCalendarSyncEnabled: Bool
    @State private var defaultBreakMinutes: String
    @State private var memo: String

    @State private var showAlert = false
    @State private var alertMessage = ""

    private let dayOptions = Array(1...31)

    init(workPlace: WorkPlace) {
        self.workPlace = workPlace
        _name = State(initialValue: workPlace.name)
        _hourlyWage = State(initialValue: String(workPlace.hourlyWage))
        _nightHourlyWage = State(initialValue: String(workPlace.nightHourlyWage))
        _transportationCost = State(initialValue: String(workPlace.transportationCost))
        _closingDay = State(initialValue: workPlace.closingDay)
        _payday = State(initialValue: workPlace.payday)
        _openingTimeText = State(initialValue: workPlace.openingTimeText)
        _closingTimeText = State(initialValue: workPlace.closingTimeText)
        _fullDayKeywords = State(initialValue: workPlace.fullDayKeywords)
        _isCalendarSyncEnabled = State(initialValue: workPlace.isCalendarSyncEnabled)
        _defaultBreakMinutes = State(initialValue: String(workPlace.defaultBreakMinutes))
        _memo = State(initialValue: workPlace.memo)
    }

    var body: some View {
        WorkPlaceFormView(
            title: "バイト先編集",
            name: $name,
            hourlyWage: $hourlyWage,
            nightHourlyWage: $nightHourlyWage,
            transportationCost: $transportationCost,
            closingDay: $closingDay,
            payday: $payday,
            openingTimeText: $openingTimeText,
            closingTimeText: $closingTimeText,
            fullDayKeywords: $fullDayKeywords,
            isCalendarSyncEnabled: $isCalendarSyncEnabled,
            defaultBreakMinutes: $defaultBreakMinutes,
            memo: $memo,
            buttonTitle: "変更を保存",
            dayOptions: dayOptions
        ) {
            updateWorkPlace()
        }
        .alert("保存できません", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func updateWorkPlace() {
        guard let values = validateFormValues(
            name: name,
            hourlyWage: hourlyWage,
            nightHourlyWage: nightHourlyWage,
            transportationCost: transportationCost,
            defaultBreakMinutes: defaultBreakMinutes,
            openingTimeText: openingTimeText,
            closingTimeText: closingTimeText,
            setError: { message in
                alertMessage = message
                showAlert = true
            }
        ) else {
            return
        }

        workPlace.name = values.name
        workPlace.hourlyWage = values.hourlyWage
        workPlace.nightHourlyWage = values.nightHourlyWage
        workPlace.transportationCost = values.transportationCost
        workPlace.closingDay = closingDay
        workPlace.payday = payday
        workPlace.openingTimeText = values.openingTimeText
        workPlace.closingTimeText = values.closingTimeText
        workPlace.fullDayKeywords = fullDayKeywords
        workPlace.isCalendarSyncEnabled = isCalendarSyncEnabled
        workPlace.defaultBreakMinutes = values.defaultBreakMinutes
        workPlace.memo = memo

        do {
            try modelContext.save()
            dismiss()
        } catch {
            alertMessage = "保存中にエラーが発生しました。"
            showAlert = true
        }
    }
}

// 追加・編集共通フォーム
struct WorkPlaceFormView: View {
    let title: String

    @Binding var name: String
    @Binding var hourlyWage: String
    @Binding var nightHourlyWage: String
    @Binding var transportationCost: String
    @Binding var closingDay: Int
    @Binding var payday: Int
    @Binding var openingTimeText: String
    @Binding var closingTimeText: String
    @Binding var fullDayKeywords: String
    @Binding var isCalendarSyncEnabled: Bool
    @Binding var defaultBreakMinutes: String
    @Binding var memo: String

    let buttonTitle: String
    let dayOptions: [Int]
    let onSave: () -> Void

    var body: some View {
        Form {
            Section("バイト先情報") {
                TextField("バイト先名 例：ROOTS渋谷", text: $name)
            }

            Section("給料設定") {
                TextField("通常時給 例：1200", text: $hourlyWage)
                    .keyboardType(.numberPad)

                TextField("深夜時給 例：1500 / 0なら通常時給×1.25", text: $nightHourlyWage)
                    .keyboardType(.numberPad)

                TextField("交通費 例：500 / なしなら0", text: $transportationCost)
                    .keyboardType(.numberPad)
            }

            Section("シフト読み取り設定") {
                TextField("開店時間 例：12:10 / 1210", text: $openingTimeText)
                    .keyboardType(.numbersAndPunctuation)

                TextField("閉店時間 例：23:00 / 2300", text: $closingTimeText)
                    .keyboardType(.numbersAndPunctuation)

                TextField("全日キーワード", text: $fullDayKeywords)

                Text("全日・オーラス・OLなどを、この開店〜閉店時間に変換します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("休憩設定") {
                TextField("標準休憩時間（分）例：60", text: $defaultBreakMinutes)
                    .keyboardType(.numberPad)
            }

            Section("給料日設定") {
                Picker("締め日", selection: $closingDay) {
                    ForEach(dayOptions, id: \.self) { day in
                        Text(day == 31 ? "月末" : "\(day)日").tag(day)
                    }
                }

                Picker("給料日", selection: $payday) {
                    ForEach(dayOptions, id: \.self) { day in
                        Text(day == 31 ? "月末" : "\(day)日").tag(day)
                    }
                }
            }

            Section("連携設定") {
                Toggle("標準カレンダーに追加する", isOn: $isCalendarSyncEnabled)
            }

            Section("メモ") {
                TextField("メモ 例：土日は時給UP、交通費は往復など", text: $memo, axis: .vertical)
                    .lineLimit(3...5)
            }

            Section {
                Button {
                    onSave()
                } label: {
                    Text(buttonTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WorkPlaceFormValues {
    let name: String
    let hourlyWage: Int
    let nightHourlyWage: Int
    let transportationCost: Int
    let defaultBreakMinutes: Int
    let openingTimeText: String
    let closingTimeText: String
}

private func validateFormValues(
    name: String,
    hourlyWage: String,
    nightHourlyWage: String,
    transportationCost: String,
    defaultBreakMinutes: String,
    openingTimeText: String,
    closingTimeText: String,
    setError: (String) -> Void
) -> WorkPlaceFormValues? {
    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

    guard !trimmedName.isEmpty else {
        setError("バイト先名を入力してください。")
        return nil
    }

    guard let wage = Int(hourlyWage), wage > 0 else {
        setError("通常時給は1円以上の数字で入力してください。")
        return nil
    }

    let trimmedNightHourlyWage = nightHourlyWage.trimmingCharacters(in: .whitespacesAndNewlines)
    let nightWage: Int

    if trimmedNightHourlyWage.isEmpty || trimmedNightHourlyWage == "0" {
        nightWage = WorkPlaceFormHelper.defaultNightHourlyWage(for: wage)
    } else if let parsedNightWage = Int(trimmedNightHourlyWage), parsedNightWage > 0 {
        nightWage = parsedNightWage
    } else {
        setError("深夜時給は0以上の数字で入力してください。0にすると通常時給×1.25で自動設定されます。")
        return nil
    }

    guard let transportation = Int(transportationCost), transportation >= 0 else {
        setError("交通費は0以上の数字で入力してください。")
        return nil
    }

    guard let breakValue = Int(defaultBreakMinutes), breakValue >= 0 else {
        setError("休憩時間は0以上の数字で入力してください。")
        return nil
    }

    guard let normalizedOpeningTime = WorkPlaceFormHelper.normalizeTimeInput(openingTimeText) else {
        setError("開店時間を正しく入力してください。例：12:10 / 1210")
        return nil
    }

    guard let normalizedClosingTime = WorkPlaceFormHelper.normalizeTimeInput(closingTimeText) else {
        setError("閉店時間を正しく入力してください。例：23:00 / 2300")
        return nil
    }

    return WorkPlaceFormValues(
        name: trimmedName,
        hourlyWage: wage,
        nightHourlyWage: nightWage,
        transportationCost: transportation,
        defaultBreakMinutes: breakValue,
        openingTimeText: normalizedOpeningTime,
        closingTimeText: normalizedClosingTime
    )
}

enum WorkPlaceFormHelper {
    static func defaultNightHourlyWage(for hourlyWage: Int) -> Int {
        Int((Double(hourlyWage) * 1.25).rounded())
    }

    static func normalizeTimeInput(_ input: String) -> String? {
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

        if digits.count <= 2,
           let hour = Int(digits),
           hour >= 0,
           hour <= 29 {
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
