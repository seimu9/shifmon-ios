//
//  Item.swift
//  Shifmon
//
//  Created by 広野成夢 on 2026/06/19.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
