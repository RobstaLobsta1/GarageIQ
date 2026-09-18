import SwiftUI

struct AppearanceSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Label("Dark", systemImage: "moon.fill")
                        Spacer()
                        Image(systemName: "checkmark")
                            .foregroundStyle(GarageTheme.accent)
                            .accessibilityHidden(true)
                    }
                    .listRowBackground(GarageTheme.surface)
                } header: {
                    Text("Appearance")
                } footer: {
                    Text("GarageIQ uses dark appearance across every screen.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(GarageTheme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
