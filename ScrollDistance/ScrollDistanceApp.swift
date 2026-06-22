import SwiftUI

@main
struct ScrollDistanceApp: App {
    @StateObject private var meter = ScrollMeter()

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(meter)
        } label: {
            Text(meter.label)
        }
        .menuBarExtraStyle(.window)
    }
}
