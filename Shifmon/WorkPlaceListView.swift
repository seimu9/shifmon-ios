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

        let newWorkPlace = WorkPlace(
            name: trimmedName,
            hourlyWage: wage,
            defaultBreakMinutes: breakValue,
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
