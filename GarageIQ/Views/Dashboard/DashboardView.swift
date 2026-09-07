import SwiftUI

struct DashboardView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Welcome to GarageIQ",
                systemImage: "gauge.with.dots.needle.67percent",
                description: Text("Your vehicle overview will appear here once vehicle management is added.")
            )
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
}
