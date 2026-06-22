//
//  TextShiftImportView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import SwiftData

// テキストから抽出したシフト候補
struct TextShiftCandidate: Identifiable {
    let id = UUID()
    let date: Date
    let startTimeText: String?
    let endTimeText: String?
    let sourceLine: String

    var displayDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd(E)"
        return formatter.string(from: date)
    }

    var displayTimeText: String {
        let start = startTimeText ?? "未定"
        let end = endTimeText ?? "未定"
        return "\(start) 〜 \(end)"
    }
}

// LINE・メモなどのテキストからシフト候補を読み取る画面
struct TextShiftImportView: View {
    @Query(sort: \WorkPlace.createdAt, order: .reverse) private var workPlaces: [WorkPlace]

    @State private var inputText = """
一応ここに7月前半の出勤可能日置いときます！

3 全日
6 1710-
7 1410-2000
8 オーラス

11 -1600
12 1700-2200
13 -2000
14 ol
"""
    @State private var targetMonth = Date()
    @State private var selectedWorkPlaceID: UUID?

    private var selectedWorkPlace: WorkPlace? {
        guard let selectedWorkPlaceID else { return workPlaces.first }
        return workPlaces.first { $0.id == selectedWorkPlaceID }
    }

    private var candidates: [TextShiftCandidate] {
        TextShiftParser.parse(
            from: inputText,
            targetMonth: targetMonth,
            workPlace: selectedWorkPlace
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                descriptionSection
                workPlaceSection
                targetMonthSection
                inputSection
                candidateSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("テキスト読み取り")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if selectedWorkPlaceID == nil {
                selectedWorkPlaceID = workPlaces.first?.id
            }
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LINE・メモのシフト文を読み取る")
                .font(.title3)
                .fontWeight(.bold)

            Text("1410-2000、14:10-20:00、17-23、-1600、全日、オーラス、OL、ol などに対応します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("全日系ワードは、選択したバイト先の開店時間〜閉店時間として読み取ります。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var workPlaceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("対象バイト先")
                .font(.headline)

            if workPlaces.isEmpty {
                Text("先にバイト先管理から、開店時間・閉店時間を登録してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("対象バイト先", selection: $selectedWorkPlaceID) {
                    ForEach(workPlaces, id: \.id) { workPlace in
                        Text(workPlace.name).tag(Optional(workPlace.id))
                    }
                }
                .pickerStyle(.menu)

                if let selectedWorkPlace {
                    Text("全日：\(selectedWorkPlace.openingTimeText) 〜 \(selectedWorkPlace.closingTimeText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("キーワード：\(selectedWorkPlace.fullDayKeywords)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var targetMonthSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("対象年月")
                .font(.headline)

            DatePicker(
                "対象年月",
                selection: $targetMonth,
                displayedComponents: [.date]
            )

            Text("日付だけの行は、この対象年月を使って候補を作ります。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("貼り付けテキスト")
                .font(.headline)

            TextEditor(text: $inputText)
                .frame(minHeight: 240)
                .padding(8)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("抽出した候補")
                    .font(.headline)

                Spacer()

                Text("\(candidates.count)件")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if candidates.isEmpty {
                Text("候補がありません。日付と時間、または全日系ワードが含まれるテキストを貼り付けてください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 10) {
                    ForEach(candidates) { candidate in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(candidate.displayDateText)
                                .font(.headline)

                            Label(candidate.displayTimeText, systemImage: "clock")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text("元テキスト：\(candidate.sourceLine)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
}

// テキストからシフト候補を抽出するパーサー
enum TextShiftParser {
    static func parse(
        from text: String,
        targetMonth: Date,
        workPlace: WorkPlace?
    ) -> [TextShiftCandidate] {
        let normalizedText = normalize(text)
        let inferredYearMonth = extractYearMonth(from: normalizedText, fallback: targetMonth)

        let lines = normalizedText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var candidates: [TextShiftCandidate] = []

        for line in lines {
            guard let parsed = extractDayAndBody(from: line, defaultYearMonth: inferredYearMonth) else {
                continue
            }

            let timeRange: (start: String?, end: String?)?

            if isFullDayText(parsed.body, workPlace: workPlace),
               let workPlace {
                timeRange = (
                    start: workPlace.openingTimeText,
                    end: workPlace.closingTimeText
                )
            } else {
                timeRange = extractTimeRange(from: parsed.body, workPlace: workPlace)
            }

            guard let timeRange else {
                continue
            }

            guard let date = makeDate(
                year: parsed.year,
                month: parsed.month,
                day: parsed.day
            ) else {
                continue
            }

            candidates.append(
                TextShiftCandidate(
                    date: date,
                    startTimeText: timeRange.start,
                    endTimeText: timeRange.end,
                    sourceLine: line
                )
            )
        }

        return candidates.sorted { $0.date < $1.date }
    }

    private static func isFullDayText(_ body: String, workPlace: WorkPlace?) -> Bool {
        let normalizedBody = normalize(body)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        let defaultKeywords = ["全日", "オーラス", "ol", "通し", "通し勤務", "openlast", "open-last"]

        let customKeywords = workPlace?.fullDayKeywordList ?? []
        let keywords = defaultKeywords + customKeywords

        return keywords.contains { keyword in
            let normalizedKeyword = normalize(keyword)
                .lowercased()
                .replacingOccurrences(of: " ", with: "")

            return !normalizedKeyword.isEmpty && normalizedBody.contains(normalizedKeyword)
        }
    }

    private static func extractYearMonth(from text: String, fallback: Date) -> (year: Int, month: Int) {
        let currentYear = Calendar.current.component(.year, from: fallback)
        let fallbackMonth = Calendar.current.component(.month, from: fallback)

        if let match = firstMatch(text, pattern: "(\\d{4})年\\s*(\\d{1,2})月"),
           match.count >= 3,
           let year = Int(match[1]),
           let month = Int(match[2]) {
            return (year, month)
        }

        if let match = firstMatch(text, pattern: "(\\d{1,2})月"),
           match.count >= 2,
           let month = Int(match[1]) {
            return (currentYear, month)
        }

        return (currentYear, fallbackMonth)
    }

    private static func extractDayAndBody(
        from line: String,
        defaultYearMonth: (year: Int, month: Int)
    ) -> (year: Int, month: Int, day: Int, body: String)? {
        if let match = firstMatch(line, pattern: "^(\\d{4})[/-](\\d{1,2})[/-](\\d{1,2})\\s*(.*)$"),
           match.count >= 5,
           let year = Int(match[1]),
           let month = Int(match[2]),
           let day = Int(match[3]) {
            return (year, month, day, match[4])
        }

        if let match = firstMatch(line, pattern: "^(\\d{1,2})[/-](\\d{1,2})\\s*(.*)$"),
           match.count >= 4,
           let month = Int(match[1]),
           let day = Int(match[2]) {
            return (defaultYearMonth.year, month, day, match[3])
        }

        if let match = firstMatch(line, pattern: "^(\\d{1,2})\\s*日?\\s*(.*)$"),
           match.count >= 3,
           let day = Int(match[1]) {
            return (defaultYearMonth.year, defaultYearMonth.month, day, match[2])
        }

        return nil
    }

    private static func extractTimeRange(
        from text: String,
        workPlace: WorkPlace?
    ) -> (start: String?, end: String?)? {
        let normalized = normalize(text)
            .replacingOccurrences(of: " ", with: "")

        let separators = ["〜", "～", "-", "ー", "－", "–", "—", "~"]

        for separator in separators {
            if let range = normalized.range(of: separator) {
                let left = String(normalized[..<range.lowerBound])
                let right = String(normalized[range.upperBound...])

                let start: String?
                let end: String?

                if left.isEmpty {
                    // 例：-1600 / 〜16:00
                    // 開始側が空なら、バイト先の開店時間を使う
                    start = workPlace?.openingTimeText
                } else {
                    start = extractLastTime(from: left)
                }

                if right.isEmpty || isLastText(right) {
                    // 例：1710- / 17:10〜 / 1710-ラスト
                    // 終了側が空、またはラスト系ワードなら、バイト先の閉店時間を使う
                    end = workPlace?.closingTimeText
                } else {
                    end = extractFirstTime(from: right)
                }

                if start != nil || end != nil {
                    return (start, end)
                }
            }
        }

        let times = extractAllTimes(from: normalized)

        if times.count >= 2 {
            return (times[0], times[1])
        }

        if times.count == 1 {
            return (times[0], workPlace?.closingTimeText)
        }

        return nil
    }

    private static func isLastText(_ text: String) -> Bool {
        let normalizedText = normalize(text)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        let keywords = [
            "ラスト",
            "last",
            "close",
            "closing",
            "cl",
            "締め",
            "閉店",
            "クローズ"
        ]

        return keywords.contains { keyword in
            normalizedText.contains(keyword.lowercased())
        }
    }

    private static func extractFirstTime(from text: String) -> String? {
        extractAllTimes(from: text).first
    }

    private static func extractLastTime(from text: String) -> String? {
        extractAllTimes(from: text).last
    }

    private static func extractAllTimes(from text: String) -> [String] {
        var results: [String] = []

        let patterns = [
            "\\d{1,2}:\\d{1,2}",
            "\\d{1,2}時\\d{0,2}分?",
            "(?<!\\d)\\d{3,4}(?!\\d)",
            "(?<!\\d)\\d{1,2}(?!\\d)"
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            let matches = regex.matches(in: text, range: range)

            for match in matches {
                guard let tokenRange = Range(match.range, in: text) else {
                    continue
                }

                let token = String(text[tokenRange])

                if let time = normalizeTimeToken(token),
                   !results.contains(time) {
                    results.append(time)
                }
            }

            if !results.isEmpty {
                break
            }
        }

        return results
    }

    private static func normalizeTimeToken(_ token: String) -> String? {
        let text = normalize(token)
            .replacingOccurrences(of: "分", with: "")
            .replacingOccurrences(of: "時", with: ":")

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

        guard !digits.isEmpty else {
            return nil
        }

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

        if digits.count <= 2 {
            guard let hour = Int(digits),
                  hour >= 0,
                  hour <= 29 else {
                return nil
            }

            return String(format: "%d:00", hour)
        }

        return nil
    }

    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        return Calendar.current.date(from: components)
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "：", with: ":")
            .replacingOccurrences(of: "－", with: "-")
            .replacingOccurrences(of: "ー", with: "-")
            .replacingOccurrences(of: "〜", with: "-")
            .replacingOccurrences(of: "～", with: "-")
            .replacingOccurrences(of: "０", with: "0")
            .replacingOccurrences(of: "１", with: "1")
            .replacingOccurrences(of: "２", with: "2")
            .replacingOccurrences(of: "３", with: "3")
            .replacingOccurrences(of: "４", with: "4")
            .replacingOccurrences(of: "５", with: "5")
            .replacingOccurrences(of: "６", with: "6")
            .replacingOccurrences(of: "７", with: "7")
            .replacingOccurrences(of: "８", with: "8")
            .replacingOccurrences(of: "９", with: "9")
    }

    private static func firstMatch(_ text: String, pattern: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }

        var results: [String] = []

        for index in 0..<match.numberOfRanges {
            guard let matchRange = Range(match.range(at: index), in: text) else {
                results.append("")
                continue
            }

            results.append(String(text[matchRange]))
        }

        return results
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
