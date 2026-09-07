import SwiftUI

struct RemindersView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Maintenance Reminders",
                systemImage: "bell",
                description: Text("Upcoming date and mileage reminders will appear here.")
            )
            .navigationTitle("Reminders")
        }
    }
}

#Preview {
    RemindersView()
}
