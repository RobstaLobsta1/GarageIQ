# GarageIQ — Phase 1

Native SwiftUI foundation for the CPSC 411 project. Targets iOS 17+, uses SwiftData, and has no third-party dependencies. Only the foundation is implemented.

## Open and build

1. Open `GarageIQ.xcodeproj` with Xcode 15 or newer.
2. Choose the GarageIQ scheme and an installed iPhone simulator.
3. Press Command-B to build, then Command-R to run.
4. Confirm Dashboard, Maintenance, Reminders, and Garage each open their placeholder screen.

For a device, set your signing team and a unique bundle identifier in the target's Signing & Capabilities settings. The current identifier is `com.example.GarageIQ`.

Command-line build from this folder on a Mac with Xcode selected:

```sh
xcodebuild -project GarageIQ.xcodeproj -scheme GarageIQ -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Build status: NOT VERIFIED. The creation environment has no Xcode, Swift compiler, or iOS SDK. The project plist, scheme XML, source membership, and file references were checked; these checks do not replace compilation. Complete the build and simulator checks above before Phase 2. No persistence relaunch test has been performed; that belongs with vehicle entry in Phase 2.

## Folder and file guide

```text
GarageIQ/
├── GarageIQ.xcodeproj/
│   ├── project.pbxproj
│   └── xcshareddata/xcschemes/GarageIQ.xcscheme
├── GarageIQ/
│   ├── App/GarageIQApp.swift
│   ├── Models/
│   │   ├── Vehicle.swift
│   │   ├── MaintenanceRecord.swift
│   │   └── MaintenanceReminder.swift
│   ├── Views/
│   │   ├── MainTabView.swift
│   │   ├── Dashboard/DashboardView.swift
│   │   ├── Maintenance/MaintenanceView.swift
│   │   ├── Reminders/RemindersView.swift
│   │   └── Garage/GarageView.swift
│   ├── ViewModels/.gitkeep
│   ├── Services/.gitkeep
│   ├── Utilities/.gitkeep
│   └── Resources/Assets.xcassets/Contents.json
├── .gitignore
└── README.md
```

- **GarageIQApp.swift** is the entry point. It creates the main window and attaches one on-disk SwiftData container containing all three model types. Descendant views can later access its model context to save and query data.
- **Vehicle.swift** stores vehicle identity, specifications, mileage, optional VIN and plate, creation date, and relationships to records and reminders.
- **MaintenanceRecord.swift** stores service type, service date, mileage, optional cost, shop, notes, and its vehicle relationship. `Decimal?` distinguishes an unknown cost from zero without binary floating-point currency arithmetic. Receipt support is deferred.
- **MaintenanceReminder.swift** stores title, optional due date and mileage, notes, completion state, notification preference, and vehicle relationship. Notifications default to disabled; no permission request or scheduling occurs.
- **MainTabView.swift** assembles the four tabs with SF Symbols. Each screen owns a NavigationStack for future navigation.
- **DashboardView.swift** shows the overview placeholder.
- **MaintenanceView.swift** shows the service-history placeholder.
- **RemindersView.swift** shows the reminders placeholder.
- **GarageView.swift** shows the vehicle-management placeholder.
- **ViewModels, Services, Utilities** are reserved folders. Their `.gitkeep` files preserve empty directories. No artificial view models are needed for static screens.
- **Assets.xcassets/Contents.json** starts the asset catalog. App icons can be added before distribution.
- **project.pbxproj** defines the native iOS app target and its source files, resources, and Debug/Release settings. The shared **GarageIQ.xcscheme** supports build and run without a project generator.
- **.gitignore** excludes local Xcode state and build output.

## Swift concepts to understand

- `struct ...: View` describes a lightweight SwiftUI view. Its `body: some View` returns a concrete view composition while hiding that composition's long type name.
- `@main` identifies the app entry point. `WindowGroup` hosts its interface.
- `@Model` is a macro that adds SwiftData persistence and observation to a class. Models use reference semantics, so relationships refer to model objects rather than copied structs.
- `@Attribute(.unique)` makes the UUID an app-level unique identifier.
- `@Relationship` explicitly describes the inverse association. A vehicle has many records/reminders; each child points back to a vehicle. Cascade deletion means deleting a vehicle also deletes its children. Deleting a child does not delete the vehicle.
- A type ending in `?` is optional: it can contain a value or `nil`. Child relationships are optional for persistence lifecycle handling, but the initializers require a vehicle when creating a child.
- `init` assigns initial values. Default arguments let callers omit values such as empty notes or today's date.
- `.modelContainer(for:)` sets up storage and makes a model context available through the SwiftUI environment. Later phases can use `@Query` to fetch models and `@Environment(\.modelContext)` for mutations.
- `#Preview` provides an Xcode canvas preview. These placeholders do not query data, so their previews need no model container yet.

Model initializers are intentionally just data initialization. Vehicle form validation, nondecreasing mileage updates, reminder deadline validation (at least one deadline), selection, and CRUD behavior are deferred to their requested phases. No sample records are inserted. No AI service or network integration is implemented.

Apple references: [SwiftData persistence](https://developer.apple.com/documentation/swiftdata/preserving-your-apps-model-data-across-launches) and [model relationships](https://developer.apple.com/documentation/swiftdata/defining-data-relationships-with-enumerations-and-model-classes/).
