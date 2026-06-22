import ServiceManagement
import SwiftUI

struct MenuContentView: View {
    @EnvironmentObject private var meter: ScrollMeter
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Scrolled")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(meter.label)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }

            Picker("Units", selection: $meter.unit) {
                Text("Metric").tag(DistanceUnit.metric)
                Text("Imperial").tag(DistanceUnit.imperial)
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    setLaunchAtLogin(newValue)
                }

            Divider()

            HStack {
                Button("Reset") { meter.reset() }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
        .padding(16)
        .frame(width: 240)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
