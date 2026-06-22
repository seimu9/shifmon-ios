//
//  ContentView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import SwiftData

// シフト情報を保存するデータモデル
@Model
final class WorkShift {
    var id: UUID
    var workplaceName: String
    var startTime: Date
    var endTime: Date
    var hourlyWage: Int
    var breakMinutes: Int
    var memo: String
    var createdAt: Date

    init(
        workplaceName: String,
        startTime: Date,
        endTime: Date,
        hourlyWage: Int,
        breakMinutes: Int,
        memo: String = ""
    ) {
        self.id = UUID()
        self.workplaceName = workplaceName
        self.startTime = startTime
        self.endTime = endTime
        self.hourlyWage = hourlyWage
        self.breakMinutes = breakMinutes
        self.memo = memo
        self.createdAt = Date()
    }

    // 休憩時間を引いた実働時間（分）
    var workMinutes: Int {
        let totalMinutes = Int(endTime.timeIntervalSince(startTime) / 60)
        return max(0, totalMinutes - breakMinutes)
    }

    // 見込み給料
    var estimatedPay: Int {
        let hours = Double(workMinutes) / 60.0
        return Int(hours * Double(hourlyWage))
    }
}

struct ContentView: View {
    @Query(sort: \WorkShift.startTime) private var shifts: [WorkShift]

    private var currentMonthShifts: [WorkShift] {
        shifts.filter { shift in
            Calendar.current.isDate(shift.startTime, equalTo: Date(), toGranularity: .month)
            && Calendar.current.isDate(shift.startTime, equalTo: Date(), toGranularity: .year)
        }
    }

    private var monthlyPay: Int {
        currentMonthShifts.reduce(0) { $0 + $1.estimatedPay }
    }

    private var monthlyWorkMinutes: Int {
        currentMonthShifts.reduce(0) { $0 + $1.workMinutes }
    }

    private var nextShift: WorkShift? {
        shifts
            .filter { $0.startTime >= Date() }
            .sorted { $0.startTime < $1.startTime }
            .first
    }

    private var recentShifts: [WorkShift] {
        Array(shifts.sorted { $0.startTime > $1.startTime }.prefix(3))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    summarySection

                    nextShiftSection

                    actionButtons

                    if !recentShifts.isEmpty {
                        registeredShiftsSection
                    }

                    monsterSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("シフモン")
        }
    }

    // アプリ上部のメインメッセージ
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("働く予定を、ちょっと楽しみに。")
                .font(.title2)
                .fontWeight(.bold)

            Text("シフトを入れると、給料もシフモンも成長していきます。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 今月の給料・勤務時間のサマリー
    private var summarySection: some View {
        HStack {
            SummaryCard(
                title: "今月の見込み給料",
                value: yenText(monthlyPay),
                systemImage: "yensign.circle.fill"
            )

            SummaryCard(
                title: "勤務時間",
                value: workHourText(monthlyWorkMinutes),
                systemImage: "clock.fill"
            )
        }
    }

    // 次のシフト表示
    private var nextShiftSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("次のシフト")
                .font(.headline)

            HStack {
                Image(systemName: "calendar.badge.clock")
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    if let nextShift {
                        Text(nextShift.workplaceName)
                            .font(.headline)

                        Text("\(dateTimeText(nextShift.startTime)) 〜 \(timeText(nextShift.endTime))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("未登録")
                            .font(.headline)

                        Text("まずはシフトを追加してみよう")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // 主要ボタン
    private var actionButtons: some View {
        VStack(spacing: 12) {
            NavigationLink {
                AddShiftView()
            } label: {
                Label("シフトを追加する", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)

            NavigationLink {
                ShiftListView()
            } label: {
                Label("シフト一覧を見る", systemImage: "list.bullet")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)

            NavigationLink {
                WorkPlaceListView()
            } label: {
                Label("バイト先を管理する", systemImage: "building.2.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)

            NavigationLink {
                CalendarMonthView()
            } label: {
                Label("カレンダーを見る", systemImage: "calendar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
        }
    }

    // 登録済みシフトの簡易表示
    private var registeredShiftsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("登録済みシフト")
                    .font(.headline)

                Spacer()

                NavigationLink {
                    ShiftListView()
                } label: {
                    Text("すべて見る")
                        .font(.subheadline)
                }
            }

            ForEach(recentShifts, id: \.id) { shift in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(shift.workplaceName)
                            .font(.headline)

                        Text("\(dateTimeText(shift.startTime)) 〜 \(timeText(shift.endTime))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(yenText(shift.estimatedPay))
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // キャラクター育成の仮エリア
    private var monsterSection: some View {
        VStack(spacing: 12) {
            Text("今日のシフモン")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                Image(systemName: "pawprint.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("まだ生まれたばかり")
                    .font(.headline)

                Text("シフトをこなすと経験値がたまり、シフモンが成長します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    private func yenText(_ amount: Int) -> String {
        FormatHelper.yenText(amount)
    }

    private func workHourText(_ minutes: Int) -> String {
        FormatHelper.workHourText(minutes)
    }

    private func dateTimeText(_ date: Date) -> String {
        FormatHelper.dateTimeText(date)
    }

    private func timeText(_ date: Date) -> String {
        FormatHelper.timeText(date)
    }
}

// シフト追加画面
struct AddShiftView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkPlace.createdAt, order: .reverse) private var workPlaces: [WorkPlace]

    @State private var workplaceName = ""
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
    @State private var hourlyWage = "1200"
    @State private var breakMinutes = "0"
    @State private var memo = ""
    @State private var selectedWorkPlaceID: UUID?

    @State private var showAlert = false
    @State private var alertMessage = ""

    var body: some View {
        Form {
            Section("勤務情報") {
                if !workPlaces.isEmpty {
                    Picker("登録済みバイト先", selection: $selectedWorkPlaceID) {
                        Text("選択なし").tag(UUID?.none)

                        ForEach(workPlaces, id: \.id) { workPlace in
                            Text(workPlace.name).tag(Optional(workPlace.id))
                        }
                    }
                    .pickerStyle(.menu)
                }

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
                    saveShift()
                } label: {
                    Text("保存する")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("シフト追加")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            applyAutomaticBreakTime()
        }
        .onChange(of: startTime) {
            applyAutomaticBreakTime()
        }
        .onChange(of: endTime) {
            applyAutomaticBreakTime()
        }
        .onChange(of: selectedWorkPlaceID) {
            applySelectedWorkPlace()
        }
        .alert("保存できません", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private func applySelectedWorkPlace() {
        guard let selectedWorkPlaceID,
              let workPlace = workPlaces.first(where: { $0.id == selectedWorkPlaceID }) else {
            return
        }

        workplaceName = workPlace.name
        hourlyWage = String(workPlace.hourlyWage)

        // 休憩時間はバイト先設定ではなく、勤務時間から自動計算する
        applyAutomaticBreakTime()
    }

    private func applyAutomaticBreakTime() {
        let autoBreakMinutes = BreakRuleHelper.automaticBreakMinutes(
            startTime: startTime,
            endTime: endTime
        )
        breakMinutes = String(autoBreakMinutes)
    }

    private func saveShift() {
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

        guard let breakValue = Int(breakMinutes), breakValue >= 0 else {
            alertMessage = "休憩時間は0以上の数字で入力してください。"
            showAlert = true
            return
        }

        let newShift = WorkShift(
            workplaceName: finalWorkplaceName,
            startTime: startTime,
            endTime: endTime,
            hourlyWage: wage,
            breakMinutes: breakValue,
            memo: memo
        )

        modelContext.insert(newShift)

        do {
            try modelContext.save()

            CalendarEventManager.shared.addShiftToCalendar(
                workplaceName: finalWorkplaceName,
                startTime: startTime,
                endTime: endTime,
                memo: memo
            )

            dismiss()
        } catch {
            alertMessage = "保存中にエラーが発生しました。"
            showAlert = true
        }
    }
}

// シフト一覧画面
struct ShiftListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkShift.startTime, order: .reverse) private var shifts: [WorkShift]

    var body: some View {
        List {
            if shifts.isEmpty {
                ContentUnavailableView(
                    "シフトがありません",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("まずはシフトを追加してみよう")
                )
            } else {
                ForEach(shifts, id: \.id) { shift in
                    NavigationLink {
                        EditShiftView(shift: shift)
                    } label: {
                        ShiftRowView(shift: shift)
                    }
                }
                .onDelete(perform: deleteShifts)
            }
        }
        .navigationTitle("シフト一覧")
        .toolbar {
            EditButton()
        }
    }

    private func deleteShifts(at offsets: IndexSet) {
        for index in offsets {
            let shift = shifts[index]
            modelContext.delete(shift)
        }

        do {
            try modelContext.save()
        } catch {
            print("削除に失敗しました: \(error.localizedDescription)")
        }
    }
}

// シフト一覧の1行
struct ShiftRowView: View {
    let shift: WorkShift

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(shift.workplaceName)
                    .font(.headline)

                Spacer()

                Text(FormatHelper.yenText(shift.estimatedPay))
                    .font(.subheadline)
                    .fontWeight(.bold)
            }

            Text("\(FormatHelper.dateTimeText(shift.startTime)) 〜 \(FormatHelper.timeText(shift.endTime))")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                Label(FormatHelper.workHourText(shift.workMinutes), systemImage: "clock")
                Label("時給 \(FormatHelper.yenText(shift.hourlyWage))", systemImage: "yensign.circle")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if !shift.memo.isEmpty {
                Text(shift.memo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 6)
    }
}

// 給料や勤務時間を表示するカード
struct SummaryCard: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// 日付・金額・勤務時間の表示をまとめるヘルパー
// 労働時間から休憩時間を自動計算するヘルパー
enum BreakRuleHelper {
    static func automaticBreakMinutes(startTime: Date, endTime: Date) -> Int {
        let totalMinutes = Int(endTime.timeIntervalSince(startTime) / 60)

        // シフモン内ルール：
        // 6時間以上〜8時間未満：45分
        // 8時間以上：60分
        if totalMinutes >= 8 * 60 {
            return 60
        } else if totalMinutes >= 6 * 60 {
            return 45
        } else {
            return 0
        }
    }
}

enum FormatHelper {
    static func yenText(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0

        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }

    static func workHourText(_ minutes: Int) -> String {
        let hours = Double(minutes) / 60.0

        if hours.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(hours))時間"
        } else {
            return String(format: "%.1f時間", hours)
        }
    }

    static func dateTimeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d(E) HH:mm"
        return formatter.string(from: date)
    }

    static func timeText(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: WorkShift.self, inMemory: true)
}
