import SwiftUI

private struct AppearanceSettingsModifier: ViewModifier {
    @State private var showingSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Settings", systemImage: "gearshape") { showingSettings = true }
                }
            }
            .sheet(isPresented: $showingSettings) { AppearanceSettingsView() }
    }
}

extension View {
    func appearanceSettings() -> some View {
        modifier(AppearanceSettingsModifier())
    }
}
