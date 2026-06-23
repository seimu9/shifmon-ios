//
//  ShifmonApp.swift
//  Shifmon
//
//  Created by seimu9.
//

import SwiftUI
import SwiftData

@main
struct ShifmonApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            WorkShift.self,
            WorkPlace.self
        ])
    }
}
