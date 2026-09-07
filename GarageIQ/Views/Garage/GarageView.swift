import SwiftUI

struct GarageView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Your Garage",
                systemImage: "car",
                description: Text("This is where you will add and manage your vehicles.")
            )
            .navigationTitle("Garage")
        }
    }
}

#Preview {
    GarageView()
}
