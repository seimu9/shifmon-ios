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
    var id: UUID = UUID()
    var workplaceName: String = ""
    var startTime: Date = Date()
    var endTime: Date = Date()
    var hourlyWage: Int = 1200
    var nightHourlyWage: Int = 1500
    var transportationCost: Int = 0
    var breakMinutes: Int = 0
    var memo: String = ""
    var createdAt: Date = Date()
    var calendarEventIdentifier: String?

    init(
        workplaceName: String,
        startTime: Date,
        endTime: Date,
        hourlyWage: Int,
        nightHourlyWage: Int = 0,
        transportationCost: Int = 0,
        breakMinutes: Int,
        memo: String = ""
    ) {
        self.id = UUID()
        self.workplaceName = workplaceName
        self.startTime = startTime
        self.endTime = endTime
        self.hourlyWage = hourlyWage
        self.nightHourlyWage = nightHourlyWage > 0 ? nightHourlyWage : WorkPlace.defaultNightHourlyWage(for: hourlyWage)
        self.transportationCost = transportationCost
        self.breakMinutes = breakMinutes
        self.memo = memo
        self.createdAt = Date()
        self.calendarEventIdentifier = nil
    }

    // 休憩時間を引いた実働時間（分）
    var workMinutes: Int {
        let totalMinutes = Int(endTime.timeIntervalSince(startTime) / 60)
        return max(0, totalMinutes - breakMinutes)
    }

    var effectiveNightHourlyWage: Int {
        nightHourlyWage > 0 ? nightHourlyWage : WorkPlace.defaultNightHourlyWage(for: hourlyWage)
    }

    var rawWorkMinutes: Int {
        max(0, Int(endTime.timeIntervalSince(startTime) / 60))
    }

    var nightWorkMinutes: Int {
        guard rawWorkMinutes > 0, workMinutes > 0 else { return 0 }

        // 深夜時間は22:00〜5:00。
        // 休憩時間は、まず通常時間から引いた扱いにする。
        // 例：14:00〜23:00 / 休憩60分
        // 通常 7時間、深夜 1時間 として計算する。
        let rawNightMinutes = Self.nightMinutesBetween(startTime: startTime, endTime: endTime)

        return min(workMinutes, max(0, rawNightMinutes))
    }

    var regularWorkMinutes: Int {
        max(0, workMinutes - nightWorkMinutes)
    }

    // 見込み給料：通常給 + 深夜給 + 交通費
    var estimatedPay: Int {
        guard workMinutes > 0 else {
            return transportationCost
        }

        let regularPay = Double(regularWorkMinutes) * Double(hourlyWage) / 60.0
        let nightPay = Double(nightWorkMinutes) * Double(effectiveNightHourlyWage) / 60.0

        return Int((regularPay + nightPay).rounded()) + transportationCost
    }

    private static func nightMinutesBetween(startTime: Date, endTime: Date) -> Int {
        guard endTime > startTime else { return 0 }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startTime)
        let endDay = calendar.startOfDay(for: endTime)
        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day ?? 0

        var totalMinutes = 0

        for offset in -1...(dayCount + 1) {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startDay),
                  let nightStart = calendar.date(bySettingHour: 22, minute: 0, second: 0, of: day),
                  let nextDay = calendar.date(byAdding: .day, value: 1, to: day),
                  let nightEnd = calendar.date(bySettingHour: 5, minute: 0, second: 0, of: nextDay) else {
                continue
            }

            let overlapStart = max(startTime, nightStart)
            let overlapEnd = min(endTime, nightEnd)

            if overlapEnd > overlapStart {
                totalMinutes += Int(overlapEnd.timeIntervalSince(overlapStart) / 60)
            }
        }

        return totalMinutes
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

            NavigationLink {
                ShiftScreenshotImportView()
            } label: {
                Label("スクショから読み取る", systemImage: "doc.viewfinder")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)

            NavigationLink {
                TextShiftImportView()
            } label: {
                Label("テキストから読み取る", systemImage: "text.badge.checkmark")
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
            Text("登録済みシフト")
                .font(.headline)

            ForEach(recentShifts, id: \.id) { shift in
                ShiftRowView(shift: shift)
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

    @State private var selectedWorkPlaceID: UUID?
    @State private var workplaceName = ""
    @State private var startTime = Date()
    @State private var endTime = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
    @State private var hourlyWage = "1200"
    @State private var nightHourlyWage = "1500"
    @State private var transportationCost = "0"
    @State private var breakMinutes = "0"
    @State private var memo = ""

    @State private var showAlert = false
    @State private var alertMessage = ""

    private var selectedWorkPlace: WorkPlace? {
        guard let selectedWorkPlaceID else { return nil }
        return workPlaces.first { $0.id == selectedWorkPlaceID }
    }

    var body: some View {
        Form {
            Section("勤務情報") {
                if !workPlaces.isEmpty {
                    Picker("登録済みバイト先", selection: $selectedWorkPlaceID) {
                        Text("手入力").tag(Optional<UUID>.none)

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

                TextField("深夜時給 例：1500 / 0なら通常時給×1.25", text: $nightHourlyWage)
                    .keyboardType(.numberPad)

                TextField("交通費 例：500 / なしなら0", text: $transportationCost)
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
            if selectedWorkPlaceID == nil {
                selectedWorkPlaceID = workPlaces.first?.id
            }

            applySelectedWorkPlaceSettings()
            applyAutomaticBreakTime()
        }
        .onChange(of: selectedWorkPlaceID) {
            applySelectedWorkPlaceSettings()
        }
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

    private func applySelectedWorkPlaceSettings() {
        guard let selectedWorkPlace else { return }

        workplaceName = selectedWorkPlace.name
        hourlyWage = String(selectedWorkPlace.hourlyWage)
        nightHourlyWage = String(selectedWorkPlace.effectiveNightHourlyWage)
        transportationCost = String(selectedWorkPlace.transportationCost)
        breakMinutes = String(selectedWorkPlace.defaultBreakMinutes)
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

        let newShift = WorkShift(
            workplaceName: finalWorkplaceName,
            startTime: startTime,
            endTime: endTime,
            hourlyWage: wage,
            nightHourlyWage: nightWage,
            transportationCost: transportation,
            breakMinutes: breakValue,
            memo: memo
        )

        modelContext.insert(newShift)

        do {
            try modelContext.save()

            if selectedWorkPlace?.isCalendarSyncEnabled ?? true {
                CalendarEventManager.shared.addShiftToCalendar(
                    workplaceName: finalWorkplaceName,
                    startTime: startTime,
                    endTime: endTime,
                    memo: memo
                ) { eventIdentifier in
                    if let eventIdentifier {
                        newShift.calendarEventIdentifier = eventIdentifier
                        try? modelContext.save()
                    }
                }
            }

            dismiss()
        } catch {
            alertMessage = "保存中にエラーが発生しました。\n\(error.localizedDescription)"
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
            CalendarEventManager.shared.deleteCalendarEvent(identifier: shift.calendarEventIdentifier)
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


// MARK: - 給料内訳

extension WorkShift {
    var regularEstimatedPay: Int {
        Int((Double(regularWorkMinutes) * Double(hourlyWage) / 60.0).rounded())
    }

    var nightEstimatedPay: Int {
        Int((Double(nightWorkMinutes) * Double(effectiveNightHourlyWage) / 60.0).rounded())
    }

    var workPayWithoutTransportation: Int {
        regularEstimatedPay + nightEstimatedPay
    }
}

struct ShiftRowView: View {
    let shift: WorkShift

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(shift.workplaceName)
                        .font(.headline)

                    Text("\(PayBreakdownFormatHelper.dateTimeText(shift.startTime)) 〜 \(PayBreakdownFormatHelper.timeText(shift.endTime))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("実働 \(PayBreakdownFormatHelper.workHourText(shift.workMinutes))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(PayBreakdownFormatHelper.yenText(shift.estimatedPay))
                        .font(.headline)
                        .fontWeight(.bold)
                        .monospacedDigit()

                    Text("見込み")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            PayBreakdownView(shift: shift)
        }
    }
}

struct PayBreakdownView: View {
    let shift: WorkShift

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if shift.regularWorkMinutes > 0 {
                PayBreakdownLine(
                    title: "通常",
                    detail: "\(PayBreakdownFormatHelper.workHourText(shift.regularWorkMinutes)) × \(PayBreakdownFormatHelper.yenText(shift.hourlyWage))/h",
                    amount: PayBreakdownFormatHelper.yenText(shift.regularEstimatedPay)
                )
            }

            if shift.nightWorkMinutes > 0 {
                PayBreakdownLine(
                    title: "深夜",
                    detail: "\(PayBreakdownFormatHelper.workHourText(shift.nightWorkMinutes)) × \(PayBreakdownFormatHelper.yenText(shift.effectiveNightHourlyWage))/h",
                    amount: PayBreakdownFormatHelper.yenText(shift.nightEstimatedPay)
                )
            }

            if shift.transportationCost > 0 {
                PayBreakdownLine(
                    title: "交通費",
                    detail: "1勤務あたり",
                    amount: PayBreakdownFormatHelper.yenText(shift.transportationCost)
                )
            }
        }
        .padding(10)
        .background(Color(.tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct PayBreakdownLine: View {
    let title: String
    let detail: String
    let amount: String

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .frame(width: 44, alignment: .leading)

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            Text(amount)
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }
}

enum PayBreakdownFormatHelper {
    static func yenText(_ amount: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        formatter.maximumFractionDigits = 0

        return formatter.string(from: NSNumber(value: amount)) ?? "¥\(amount)"
    }

    static func workHourText(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if remainingMinutes == 0 {
            return "\(hours)時間"
        } else if hours == 0 {
            return "\(remainingMinutes)分"
        } else {
            return "\(hours)時間\(remainingMinutes)分"
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
