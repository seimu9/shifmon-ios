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

    // 画面更新しても同じ候補を識別できるようにするキー
    var importKey: String {
        "\(displayDateText)-\(startTimeText ?? "nil")-\(endTimeText ?? "nil")-\(sourceLine)"
    }
}

// LINE・メモなどのテキストからシフト候補を読み取る画面
struct TextShiftImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkPlace.createdAt, order: .reverse) private var workPlaces: [WorkPlace]
    @Query(sort: \WorkShift.startTime) private var existingShifts: [WorkShift]

    @State private var inputText: String
    @State private var targetMonth = Date()
    @State private var selectedWorkPlaceID: UUID?
    @State private var selectedCandidateKeys: Set<String> = []

    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""

    @State private var lastRegisteredCount = 0

    private static let defaultInputText = """
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

    init(initialText: String? = nil) {
        let trimmedText = initialText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trimmedText.isEmpty {
            _inputText = State(initialValue: Self.defaultInputText)
        } else {
            _inputText = State(initialValue: trimmedText)
        }
    }

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

    private var selectedCandidates: [TextShiftCandidate] {
        candidates.filter { selectedCandidateKeys.contains($0.importKey) }
    }

    private var selectableCandidates: [TextShiftCandidate] {
        candidates.filter { !isDuplicateCandidate($0) }
    }

    private var selectedRegistrableCandidates: [TextShiftCandidate] {
        selectedCandidates.filter { !isDuplicateCandidate($0) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                descriptionSection
                workPlaceSection
                targetMonthSection
                inputSection
                candidateSection
                bulkRegisterSection
                postRegisterActionSection
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
            syncSelectionWithCandidates(selectAll: true)
        }
        .onChange(of: inputText) {
            syncSelectionWithCandidates(selectAll: true)
        }
        .onChange(of: targetMonth) {
            syncSelectionWithCandidates(selectAll: true)
        }
        .onChange(of: selectedWorkPlaceID) {
            syncSelectionWithCandidates(selectAll: true)
        }
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
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

            Text("チェックを外した候補は一括登録されません。")
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

                Text("\(selectedRegistrableCandidates.count)/\(candidates.count)件 選択中")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !candidates.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        selectAllCandidates()
                    } label: {
                        Label("すべて選択", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        deselectAllCandidates()
                    } label: {
                        Label("すべて解除", systemImage: "circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
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
                        candidateRow(candidate)
                    }
                }
            }
        }
    }

    private func candidateRow(_ candidate: TextShiftCandidate) -> some View {
        let isSelected = selectedCandidateKeys.contains(candidate.importKey)
        let isDuplicate = isDuplicateCandidate(candidate)

        return Button {
            toggleCandidate(candidate)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: isDuplicate ? "checkmark.seal.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.title3)
                    .foregroundStyle(isDuplicate ? Color.orange : (isSelected ? Color.blue : Color.secondary))
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 6) {
                    Text(candidate.displayDateText)
                        .font(.headline)

                    Label(candidate.displayTimeText, systemImage: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("元テキスト：\(candidate.sourceLine)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if isDuplicate {
                        Label("登録済みのためスキップ", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(isDuplicate ? 0.65 : 1.0)
        }
        .buttonStyle(.plain)
    }

    private var bulkRegisterSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                registerSelectedCandidates()
            } label: {
                Label("選択した候補を一括登録", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedRegistrableCandidates.isEmpty || selectedWorkPlace == nil)

            Text("登録するとShifmon内に保存され、iPhone標準カレンダーにも追加されます。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }


    private var postRegisterActionSection: some View {
        Group {
            if lastRegisteredCount > 0 {
                VStack(alignment: .leading, spacing: 12) {
                    Text("登録完了")
                        .font(.headline)

                    Text("\(lastRegisteredCount)件のシフトを登録しました。確認画面に移動できます。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    NavigationLink {
                        ShiftListView()
                    } label: {
                        Label("シフト一覧で確認", systemImage: "list.bullet.rectangle")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.bordered)

                    NavigationLink {
                        CalendarMonthView()
                    } label: {
                        Label("カレンダーで確認", systemImage: "calendar")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func syncSelectionWithCandidates(selectAll: Bool) {
        let keys = Set(selectableCandidates.map { $0.importKey })

        if selectAll {
            selectedCandidateKeys = keys
        } else {
            selectedCandidateKeys = selectedCandidateKeys.intersection(keys)
        }
    }

    private func selectAllCandidates() {
        selectedCandidateKeys = Set(selectableCandidates.map { $0.importKey })
    }

    private func deselectAllCandidates() {
        selectedCandidateKeys.removeAll()
    }

    private func toggleCandidate(_ candidate: TextShiftCandidate) {
        if isDuplicateCandidate(candidate) {
            alertTitle = "登録済みです"
            alertMessage = "同じバイト先・同じ開始時刻・同じ終了時刻のシフトがすでに登録されています。"
            showAlert = true
            return
        }

        if selectedCandidateKeys.contains(candidate.importKey) {
            selectedCandidateKeys.remove(candidate.importKey)
        } else {
            selectedCandidateKeys.insert(candidate.importKey)
        }
    }

    private func registerSelectedCandidates() {
        guard let selectedWorkPlace else {
            alertTitle = "登録できません"
            alertMessage = "先に対象バイト先を選択してください。"
            showAlert = true
            return
        }

        let targets = selectedRegistrableCandidates

        guard !targets.isEmpty else {
            alertTitle = "登録できません"
            alertMessage = "登録する候補を選択してください。"
            showAlert = true
            return
        }

        var registeredCount = 0
        var skippedCount = 0

        for candidate in targets {
            guard let startText = candidate.startTimeText,
                  let endText = candidate.endTimeText,
                  let startTime = makeDateTime(baseDate: candidate.date, timeText: startText),
                  var endTime = makeDateTime(baseDate: candidate.date, timeText: endText) else {
                skippedCount += 1
                continue
            }

            if endTime <= startTime {
                endTime = Calendar.current.date(byAdding: .day, value: 1, to: endTime) ?? endTime
            }

            let breakMinutes = BreakRuleHelper.automaticBreakMinutes(
                startTime: startTime,
                endTime: endTime
            )

            let newShift = WorkShift(
                workplaceName: selectedWorkPlace.name,
                startTime: startTime,
                endTime: endTime,
                hourlyWage: selectedWorkPlace.hourlyWage,
                nightHourlyWage: selectedWorkPlace.effectiveNightHourlyWage,
                transportationCost: selectedWorkPlace.transportationCost,
                breakMinutes: breakMinutes,
                memo: "テキスト読み取りから登録\n元テキスト：\(candidate.sourceLine)"
            )

            modelContext.insert(newShift)

            if selectedWorkPlace.isCalendarSyncEnabled {
                CalendarEventManager.shared.addShiftToCalendar(
                    workplaceName: selectedWorkPlace.name,
                    startTime: startTime,
                    endTime: endTime,
                    memo: newShift.memo
                ) { eventIdentifier in
                    if let eventIdentifier {
                        newShift.calendarEventIdentifier = eventIdentifier
                        try? modelContext.save()
                    }
                }
            }

            registeredCount += 1
        }

        do {
            try modelContext.save()

            lastRegisteredCount = registeredCount
            syncSelectionWithCandidates(selectAll: false)

            alertTitle = "登録しました"
            if skippedCount == 0 {
                alertMessage = "\(registeredCount)件のシフトを登録しました。"
            } else {
                alertMessage = "\(registeredCount)件を登録しました。\n\(skippedCount)件は開始・終了時刻が不足していたためスキップしました。"
            }
            showAlert = true
        } catch {
            alertTitle = "登録に失敗しました"
            alertMessage = "保存中にエラーが発生しました。"
            showAlert = true
        }
    }

    private func isDuplicateCandidate(_ candidate: TextShiftCandidate) -> Bool {
        guard let selectedWorkPlace,
              let dateTimes = makeDateTimes(for: candidate) else {
            return false
        }

        return existingShifts.contains { shift in
            shift.workplaceName == selectedWorkPlace.name
            && isSameMinute(shift.startTime, dateTimes.startTime)
            && isSameMinute(shift.endTime, dateTimes.endTime)
        }
    }

    private func makeDateTimes(for candidate: TextShiftCandidate) -> (startTime: Date, endTime: Date)? {
        guard let startText = candidate.startTimeText,
              let endText = candidate.endTimeText,
              let startTime = makeDateTime(baseDate: candidate.date, timeText: startText),
              var endTime = makeDateTime(baseDate: candidate.date, timeText: endText) else {
            return nil
        }

        if endTime <= startTime {
            endTime = Calendar.current.date(byAdding: .day, value: 1, to: endTime) ?? endTime
        }

        return (startTime, endTime)
    }

    private func isSameMinute(_ lhs: Date, _ rhs: Date) -> Bool {
        Calendar.current.compare(lhs, to: rhs, toGranularity: .minute) == .orderedSame
    }

    private func makeDateTime(baseDate: Date, timeText: String) -> Date? {
        let parts = timeText.split(separator: ":").map(String.init)

        guard let hourText = parts[safe: 0],
              let minuteText = parts[safe: 1],
              let rawHour = Int(hourText),
              let minute = Int(minuteText),
              rawHour >= 0,
              rawHour <= 29,
              minute >= 0,
              minute <= 59 else {
            return nil
        }

        let additionalDays = rawHour / 24
        let hour = rawHour % 24

        var components = Calendar.current.dateComponents([.year, .month, .day], from: baseDate)
        components.hour = hour
        components.minute = minute

        guard let date = Calendar.current.date(from: components) else {
            return nil
        }

        if additionalDays > 0 {
            return Calendar.current.date(byAdding: .day, value: additionalDays, to: date)
        } else {
            return date
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
            .filter { !isNoiseLine($0) }

        var candidates: [TextShiftCandidate] = []
        var seenCandidateKeys: Set<String> = []

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

            let candidateKey = "\(parsed.year)-\(parsed.month)-\(parsed.day)-\(timeRange.start ?? "")-\(timeRange.end ?? "")"

            if seenCandidateKeys.contains(candidateKey) {
                continue
            }

            seenCandidateKeys.insert(candidateKey)

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

    private static func isNoiseLine(_ line: String) -> Bool {
        let normalizedLine = normalize(line)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")

        if normalizedLine.isEmpty {
            return true
        }

        let noiseWords = [
            "テキスト読み取り",
            "すべて選択",
            "すべて解除",
            "抽出した候補",
            "選択中",
            "登録済み",
            "元テキスト",
            "シフト候補",
            "一括登録",
            "月度"
        ]

        if noiseWords.contains(where: { normalizedLine.contains($0.lowercased()) }) {
            return true
        }

        // 例：12:10 / 10:00〜23:00 のような「時刻だけの行」は、
        // 日付行ではないので除外する
        if firstMatch(normalizedLine, pattern: "^\\d{1,2}:\\d{1,2}([\\-〜～~]\\d{1,2}:\\d{1,2})?$") != nil {
            return true
        }

        // 例：984 / 202607 みたいな数字だけの行は誤爆しやすいので除外
        if firstMatch(normalizedLine, pattern: "^\\d{3,}$") != nil {
            return true
        }

        return false
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
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // 例：2026/7/14(火) 1410-2000
        if let match = firstMatch(trimmedLine, pattern: "^(\\d{4})[/-](\\d{1,2})[/-](\\d{1,2})(?:\\([^)]*\\))?\\s*(.*)$"),
           match.count >= 5,
           let year = Int(match[1]),
           let month = Int(match[2]),
           let day = Int(match[3]) {
            return (year, month, day, match[4])
        }

        // 例：7/14(火) 1410-2000
        if let match = firstMatch(trimmedLine, pattern: "^(\\d{1,2})[/-](\\d{1,2})(?:\\([^)]*\\))?\\s*(.*)$"),
           match.count >= 4,
           let month = Int(match[1]),
           let day = Int(match[2]) {
            return (defaultYearMonth.year, month, day, match[3])
        }

        // 例：
        // 14 1410-2000
        // 14日 14:10-20:00
        // 14(火) 全日
        // 14ol
        //
        // ただし 12:10 や 984 は日付として扱わない
        if let match = firstMatch(trimmedLine, pattern: "^(\\d{1,2})(?![:\\d])\\s*(?:日)?(?:\\([^)]*\\))?\\s*(.*)$"),
           match.count >= 3,
           let day = Int(match[1]) {
            let body = match[2].trimmingCharacters(in: .whitespacesAndNewlines)

            // 10時〜23時 のような時刻行を「10日」と誤認しないための保険
            if body.hasPrefix("時") || body.hasPrefix(":") {
                return nil
            }

            return (defaultYearMonth.year, defaultYearMonth.month, day, body)
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
                    start = workPlace?.openingTimeText
                } else {
                    start = extractLastTime(from: left)
                }

                if right.isEmpty || isLastText(right) {
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
        guard (1...12).contains(month),
              (1...31).contains(day) else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Calendar.current
        components.year = year
        components.month = month
        components.day = day

        guard let date = Calendar.current.date(from: components) else {
            return nil
        }

        let checked = Calendar.current.dateComponents([.year, .month, .day], from: date)

        guard checked.year == year,
              checked.month == month,
              checked.day == day else {
            return nil
        }

        return date
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
