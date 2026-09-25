import SwiftData

enum GarageIQSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [Vehicle.self, MaintenanceRecord.self, MaintenanceReminder.self, ChatConversation.self]
    }
}

enum GarageIQMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [GarageIQSchemaV1.self] }
    static var stages: [MigrationStage] { [] }
}
