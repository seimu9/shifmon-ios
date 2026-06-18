//
//  ContentView.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerSection

                    summarySection

                    nextShiftSection

                    actionButtons

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
        VStack(spacing: 12) {
            HStack {
                SummaryCard(
                    title: "今月の見込み給料",
                    value: "¥0",
                    systemImage: "yensign.circle.fill"
                )

                SummaryCard(
                    title: "勤務時間",
                    value: "0時間",
                    systemImage: "clock.fill"
                )
            }
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
                    Text("未登録")
                        .font(.headline)

                    Text("まずはシフトを追加してみよう")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
            Button {
                // TODO: シフト追加画面へ遷移する
            } label: {
                Label("シフトを追加する", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)

            Button {
                // TODO: カレンダー画面へ遷移する
            } label: {
                Label("カレンダーを見る", systemImage: "calendar")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.bordered)
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

#Preview {
    ContentView()
}
