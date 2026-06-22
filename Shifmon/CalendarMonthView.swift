//
//  CalendarMonthView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import SwiftData

// 月間カレンダー画面
struct CalendarMonthView: View {
    @Query(sort: \WorkShift.startTime) private var shifts: [WorkShift]
    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let weekDays = ["日", "月", "火", "水", "木", "金", "土"]
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthShifts: [WorkShift] {
        shifts.filter { shift in
            calendar.isDate(shift.startTime, equalTo: displayedMonth, toGranularity: .month)
            && calendar.isDate(shift.startTime, equalTo: displayedMonth, toGranularity: .year)
        }
    }

    private var monthlyPay: Int {
        monthShifts.reduce(0) { $0 + $1.estimatedPay }
    }

    private var monthlyWorkMinutes: Int {
        monthShifts.reduce(0) { $0 + $1.workMinutes }
    }

    private var calendarDays: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let leadingEmptyCount = firstWeekday - 1

        var days: [Date?] = Array(repeating: nil, count: leadingEmptyCount)

        for day in dayRange {
            var components = calendar.dateComponents([.year, .month], from: monthStart)
            components.day = day
            days.append(calendar.date(from: components))
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                monthHeader

                monthSummary

                weekDayHeader

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Array(calendarDays.enumerated()), id: \.offset) { _, date in
                        CalendarDayCell(
                            date: date,
                            shifts: shiftsForDate(date)
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("月間カレンダー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                moveMonth(by: -1)
            } label: {
                Label("前月", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
                    .font(.headline)
            }

            Spacer()

            Text(monthTitle(displayedMonth))
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button {
                moveMonth(by: 1)
            } label: {
                Label("翌月", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
                    .font(.headline)
            }
        }
        .padding(.horizontal, 4)
    }

    private var monthSummary: some View {
        HStack {
            SummaryCard(
                title: "この月の見込み給料",
                value: FormatHelper.yenText(monthlyPay),
                systemImage: "yensign.circle.fill"
            )

            SummaryCard(
                title: "勤務時間",
                value: FormatHelper.workHourText(monthlyWorkMinutes),
                systemImage: "clock.fill"
            )
        }
    }

    private var weekDayHeader: some View {
        HStack(spacing: 6) {
            ForEach(weekDays, id: \.self) { day in
                Text(day)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(day == "日" ? .red : day == "土" ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func shiftsForDate(_ date: Date?) -> [WorkShift] {
        guard let date else { return [] }

        return shifts
            .filter { calendar.isDate($0.startTime, inSameDayAs: date) }
            .sorted { $0.startTime < $1.startTime }
    }

    private func moveMonth(by value: Int) {
        displayedMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }
}

// カレンダー1日分のセル
struct CalendarDayCell: View {
    let date: Date?
    let shifts: [WorkShift]

    private let calendar = Calendar.current

    var body: some View {
        Group {
            if let date {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(calendar.component(.day, from: date))")
                        .font(.caption)
                        .fontWeight(calendar.isDateInToday(date) ? .bold : .regular)
                        .foregroundStyle(calendar.isDateInToday(date) ? .blue : .primary)

                    if shifts.isEmpty {
                        Spacer(minLength: 0)
                    } else {
                        ForEach(Array(shifts.prefix(2)), id: \.id) { shift in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(shift.workplaceName)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .lineLimit(1)

                                Text(FormatHelper.timeText(shift.startTime))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        if shifts.count > 2 {
                            Text("+\(shifts.count - 2)件")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(6)
                .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                .background(Color(.secondarySystemGroupedBackground))
                .overlay {
                    if calendar.isDateInToday(date) {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue, lineWidth: 2)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Color.clear
                    .frame(minHeight: 96)
            }
        }
    }
}
