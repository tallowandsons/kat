import SwiftUI

struct ScheduleSettingsView: View {
    @Bindable var settingsStore: SettingsStore

    var body: some View {
        Form {
            Section("Active days") {
                ForEach(Weekday.mondayFirstOrder, id: \.self) { weekday in
                    Toggle(weekday.displayName, isOn: weekdayBinding(weekday))
                }
            }
            Section("Active hours") {
                DatePicker("From", selection: windowStartBinding, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: windowEndBinding, displayedComponents: .hourAndMinute)
            }
        }
        .padding()
    }

    private func weekdayBinding(_ weekday: Weekday) -> Binding<Bool> {
        Binding(
            get: { settingsStore.scheduleConfig.activeWeekdays.contains(weekday) },
            set: { isOn in
                if isOn {
                    settingsStore.scheduleConfig.activeWeekdays.insert(weekday)
                } else {
                    settingsStore.scheduleConfig.activeWeekdays.remove(weekday)
                }
            }
        )
    }

    private var windowStartBinding: Binding<Date> {
        Binding(
            get: { settingsStore.scheduleConfig.windowStart.asDate() },
            set: { settingsStore.scheduleConfig.windowStart = TimeOfDay(from: $0) }
        )
    }

    private var windowEndBinding: Binding<Date> {
        Binding(
            get: { settingsStore.scheduleConfig.windowEnd.asDate() },
            set: { settingsStore.scheduleConfig.windowEnd = TimeOfDay(from: $0) }
        )
    }
}
