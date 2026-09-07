import SwiftUI

struct MaintenanceView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Maintenance History",
                systemImage: "wrench.and.screwdriver",
                description: Text("Service records for your selected vehicle will appear here.")
            )
            .navigationTitle("Maintenance")
        }
    }
}

#Preview {
    MaintenanceView()
}
