import SwiftUI
import SwiftData

@main
struct GarageIQApp: App {
    private let container: ModelContainer

    init() {
        do {
            let schema = Schema(versionedSchema: GarageIQSchemaV1.self)
            container = try ModelContainer(for: schema, migrationPlan: GarageIQMigrationPlan.self)
        } catch {
            fatalError("Unable to open GarageIQ data: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            StartupView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}
