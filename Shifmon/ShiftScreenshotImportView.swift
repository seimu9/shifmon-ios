//
//  ShiftScreenshotImportView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import PhotosUI
import Vision
import UIKit

struct ShiftImportCandidate: Identifiable {
    let id = UUID()
    let date: Date
    let startTimeText: String
    let endTimeText: String

    var displayDateText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd(E)"
        return formatter.string(from: date)
    }
}

struct RecognizedTextBox: Identifiable {
    let id = UUID()
    let text: String
    let boundingBox: CGRect

    var topBasedY: CGFloat {
        1.0 - boundingBox.midY
    }

    var centerX: CGFloat {
        boundingBox.midX
    }
}

struct ShiftScreenshotImportView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var recognizedText = ""
    @State private var candidates: [ShiftImportCandidate] = []
    @State private var isRecognizing = false
    @State private var errorMessage: String?


    private var screenshotCandidatesText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd"

        return candidates
            .map { candidate in
                "\(formatter.string(from: candidate.date)) \(candidate.startTimeText)-\(candidate.endTimeText)"
            }
            .joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                descriptionSection
                imagePickerSection

                if let selectedImage {
                    imagePreviewSection(selectedImage)
                }


                if !candidates.isEmpty {
                    NavigationLink {
                        TextShiftImportView(initialText: screenshotCandidatesText)
                    } label: {
                        Label("抽出候補を一括登録画面へ", systemImage: "text.viewfinder")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                    .buttonStyle(.borderedProminent)
                }

                candidateSection
                recognizedTextSection
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("スクショ読み取り")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) {
            loadSelectedImage()
        }
    }

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("シフト表のスクショを読み取る")
                .font(.title3)
                .fontWeight(.bold)

            Text("ジョブカンの月間カレンダー形式を、文字と位置情報から解析します。")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("文字の順番ではなく、7列カレンダー上の位置から日付を推定します。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var imagePickerSection: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Label("スクショを選択する", systemImage: "photo.on.rectangle.angled")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
        }
        .buttonStyle(.borderedProminent)
    }

    private func imagePreviewSection(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("選択した画像")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var candidateSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("抽出したシフト候補")
                    .font(.headline)

                Spacer()

                if !candidates.isEmpty {
                    Text("\(candidates.count)件")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if candidates.isEmpty {
                Text("まだシフト候補はありません。ジョブカンの月間カレンダースクショを選択してください。")
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

                            HStack {
                                Label(candidate.startTimeText, systemImage: "clock")
                                Text("〜")
                                Text(candidate.endTimeText)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }

                Text("※ 現段階では候補表示のみです。次の実装で確認・修正・一括登録に対応します。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var recognizedTextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("OCR生テキスト")
                    .font(.headline)

                Spacer()

                if isRecognizing {
                    ProgressView()
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if recognizedText.isEmpty {
                Text("まだ文字は読み取られていません。スクショを選択してください。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                Text(recognizedText)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private func loadSelectedImage() {
        guard let selectedItem else { return }

        errorMessage = nil
        recognizedText = ""
        candidates = []
        selectedImage = nil
        isRecognizing = true

        Task {
            do {
                guard let imageData = try await selectedItem.loadTransferable(type: Data.self),
                      let image = UIImage(data: imageData) else {
                    await MainActor.run {
                        isRecognizing = false
                        errorMessage = "画像の読み込みに失敗しました。"
                    }
                    return
                }

                await MainActor.run {
                    selectedImage = image
                }

                recognizeText(from: image)
            } catch {
                await MainActor.run {
                    isRecognizing = false
                    errorMessage = "画像の読み込み中にエラーが発生しました。"
                }
            }
        }
    }

    private func recognizeText(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            isRecognizing = false
            errorMessage = "画像の解析に失敗しました。"
            return
        }

        let request = VNRecognizeTextRequest { request, error in
            DispatchQueue.main.async {
                isRecognizing = false

                if let error {
                    errorMessage = "文字認識に失敗しました: \(error.localizedDescription)"
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []

                let boxes = observations.compactMap { observation -> RecognizedTextBox? in
                    guard let text = observation.topCandidates(1).first?.string else {
                        return nil
                    }

                    return RecognizedTextBox(
                        text: text,
                        boundingBox: observation.boundingBox
                    )
                }

                let sortedBoxes = boxes.sorted { lhs, rhs in
                    if abs(lhs.topBasedY - rhs.topBasedY) > 0.015 {
                        return lhs.topBasedY < rhs.topBasedY
                    } else {
                        return lhs.centerX < rhs.centerX
                    }
                }

                recognizedText = sortedBoxes
                    .map { $0.text }
                    .joined(separator: "\n")

                candidates = JobcanGridShiftParser.parse(from: boxes)

                if recognizedText.isEmpty {
                    errorMessage = "文字を読み取れませんでした。別のスクショで試してください。"
                } else if candidates.isEmpty {
                    errorMessage = "文字は読み取れましたが、シフト候補を抽出できませんでした。"
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        request.recognitionLanguages = ["ja-JP", "en-US"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    isRecognizing = false
                    errorMessage = "文字認識処理に失敗しました。"
                }
            }
        }
    }
}

enum JobcanGridShiftParser {
    static func parse(from boxes: [RecognizedTextBox]) -> [ShiftImportCandidate] {
        guard let yearMonth = extractYearMonth(from: boxes) else {
            return []
        }

        let calendar = Calendar.current

        guard let firstDay = makeDate(year: yearMonth.year, month: yearMonth.month, day: 1) else {
            return []
        }

        guard let dayRange = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let daysInMonth = dayRange.count
        let leadingEmptyCount = calendar.component(.weekday, from: firstDay) - 1
        let rowCount = Int(ceil(Double(leadingEmptyCount + daysInMonth) / 7.0))

        let gridTop: CGFloat = 0.42
        let gridBottom: CGFloat = 0.88
        let gridHeight = gridBottom - gridTop
        let rowHeight = gridHeight / CGFloat(rowCount)

        var groupedTimes: [Int: [(time: String, y: CGFloat)]] = [:]

        for box in boxes {
            let timeTexts = normalizedTimes(from: box.text)

            guard !timeTexts.isEmpty else {
                continue
            }

            let y = box.topBasedY

            guard y >= gridTop && y <= gridBottom else {
                continue
            }

            let column = clamp(Int(box.centerX * 7.0), minValue: 0, maxValue: 6)
            let row = clamp(Int((y - gridTop) / rowHeight), minValue: 0, maxValue: rowCount - 1)
            let day = row * 7 + column - leadingEmptyCount + 1

            guard day >= 1 && day <= daysInMonth else {
                continue
            }

            for timeText in timeTexts {
                groupedTimes[day, default: []].append((time: timeText, y: y))
            }
        }

        var candidates: [ShiftImportCandidate] = []

        for day in groupedTimes.keys.sorted() {
            let times = groupedTimes[day, default: []]
                .sorted { $0.y < $1.y }
                .map { $0.time }

            let uniqueTimes = removeDuplicateTimes(times)

            guard uniqueTimes.count >= 2 else {
                continue
            }

            guard let date = makeDate(year: yearMonth.year, month: yearMonth.month, day: day) else {
                continue
            }

            candidates.append(
                ShiftImportCandidate(
                    date: date,
                    startTimeText: uniqueTimes[0],
                    endTimeText: uniqueTimes[1]
                )
            )
        }

        return candidates.sorted { $0.date < $1.date }
    }

    private static func extractYearMonth(from boxes: [RecognizedTextBox]) -> (year: Int, month: Int)? {
        let text = boxes.map { normalize($0.text) }.joined(separator: " ")
        let pattern = "(\\d{4})年\\s*(\\d{1,2})月"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)

        guard let match = regex.firstMatch(in: text, range: range),
              let yearRange = Range(match.range(at: 1), in: text),
              let monthRange = Range(match.range(at: 2), in: text),
              let year = Int(text[yearRange]),
              let month = Int(text[monthRange]) else {
            return nil
        }

        return (year, month)
    }

    private static func normalizedTimes(from rawText: String) -> [String] {
        let text = normalize(rawText)
            .replacingOccurrences(of: " ", with: "")

        let pattern = "(\\d{1,2}):(\\d{2})"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match in
            guard let hourRange = Range(match.range(at: 1), in: text),
                  let minuteRange = Range(match.range(at: 2), in: text),
                  let hour = Int(text[hourRange]),
                  let minute = Int(text[minuteRange]),
                  hour >= 0 && hour <= 23,
                  minute >= 0 && minute <= 59 else {
                return nil
            }

            return String(format: "%d:%02d", hour, minute)
        }
    }

    private static func normalize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "：", with: ":")
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

    private static func makeDate(year: Int, month: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day

        return Calendar.current.date(from: components)
    }

    private static func removeDuplicateTimes(_ times: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []

        for time in times {
            if !seen.contains(time) {
                seen.insert(time)
                result.append(time)
            }
        }

        return result
    }

    private static func clamp(_ value: Int, minValue: Int, maxValue: Int) -> Int {
        Swift.max(minValue, Swift.min(value, maxValue))
    }
}
