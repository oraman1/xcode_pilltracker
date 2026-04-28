//
//  pilltrackerApp.swift
//  pilltracker
//
//  Created by Imran Rahim on 26/04/2026.
//

import SwiftUI

@main
struct pilltrackerApp: App {
    @State private var store = MedicationStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
