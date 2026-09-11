# GarageIQ — Vehicle and Maintenance Management

Native SwiftUI foundation for the CPSC 411 project. Targets iOS 17+, uses SwiftData, and has no third-party dependencies. The foundation, vehicle management, and maintenance records are implemented.

## Open and build

1. Open `GarageIQ.xcodeproj` with Xcode 15 or newer.
2. Choose the GarageIQ scheme and an installed iPhone simulator.
3. Press Command-B to build, then Command-R to run.
4. Open Garage, add a vehicle, tap its row to edit, and swipe to edit or delete. Maintenance supports service records; Dashboard and Reminders remain placeholders.

For a device, set your signing team and a unique bundle identifier in the target's Signing & Capabilities settings. The current identifier is `com.example.GarageIQ`.

Command-line build from this folder on a Mac with Xcode selected:

```sh
xcodebuild -project GarageIQ.xcodeproj -scheme GarageIQ -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

Build status: NOT VERIFIED. Xcode 26.3 was located at `/Users/Robby/Downloads/Xcode.app`. A simulator build was attempted using an explicit `DEVELOPER_DIR`, but the agent sandbox blocked Swift macro plugin execution (`sandbox-exec: sandbox_apply: Operation not permitted`), causing SwiftData macro expansion failures. Simulator services were also unavailable in this environment. Run the build from Xcode to complete verification. The project plist, scheme XML, source membership, and file references were checked; these checks do not replace compilation. Complete the build and simulator checks below before proceeding. Persistence relaunch testing remains pending.

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
│   │   └── Garage/
│   │       ├── GarageView.swift
│   │       └── AddVehicleView.swift
│   ├── ViewModels/VehicleFormData.swift
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
- **MaintenanceView.swift** selects the vehicle whose history is displayed.
- **MaintenanceHistoryView.swift** queries records for that vehicle, sorts by service date descending, and offers add/edit/delete actions.
- **AddMaintenanceRecordView.swift** displays all service fields in a shared add/edit form.
- **MaintenanceFormData.swift** keeps draft fields separate from persistence and validates mileage, cost, and service type.
- **RemindersView.swift** shows the reminders placeholder.
- **GarageView.swift** fetches all saved vehicles, displays them newest-added first, opens add/edit sheets, and confirms deletion.
- **AddVehicleView.swift** shares one form for adding and editing, validates on Save, and reports persistence failures.
- **VehicleFormData.swift** holds a temporary value-type draft, validates required fields and numeric ranges, and applies valid changes to a model.
- **ViewModels, Services, Utilities** are reserved folders. Their `.gitkeep` files preserve empty directories. VehicleFormData separates form state and validation from the Garage views.
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
- `#Preview` provides an Xcode canvas preview. Garage, the editor, and main-tab previews use an in-memory model container so previews do not affect saved app data.

Model initializers only initialize data. The vehicle editor now validates trimmed make/model, year from 1900 through current year + 1, and whole-number mileage of at least zero. Blank VIN and plate become nil. Editing can correct mileage downward; the separate dashboard mileage-update action is not implemented. Maintenance record management is implemented as described below. Reminder and AI behavior remain deferred.

## SwiftData operations in vehicle management

- `@Query(sort: \Vehicle.dateAdded, order: .reverse)` fetches vehicles and keeps the list up to date with model changes.
- `@Environment(\.modelContext)` uses the context from the app's existing on-disk container.
- `insert` registers a new vehicle. Editing assigns fields on the existing model; no duplicate is inserted and its ID/dateAdded stay intact.
- `save()` explicitly persists additions, edits, and deletions and allows errors to be displayed before dismissing the editor.
- `delete` marks a vehicle for deletion. The existing cascade relationships also delete related records and reminders after saving.
- `rollback()` discards pending context changes if saving fails. Garage and Maintenance use synchronous save operations; revisit context isolation when adding concurrent editing flows in later phases.
- Cancel discards the form draft without ever changing the persisted model.

## Simulator verification checklist (not yet run)

1. Start with an empty store: verify the empty state and toolbar Add button.
2. Add two vehicles with different values in all fields. Verify both rows and their mileage.
3. Submit empty and whitespace-only make/model; verify inline errors and no saved vehicle.
4. Test years 1899, 1900, current year + 1, and current year + 2. Only the middle two are accepted.
5. Test blank, negative, decimal, alphabetic, and excessively large mileage text. Reject these; accept zero and positive whole numbers.
6. Reopen a saved vehicle: verify all eight fields. Save changes, including a lower mileage correction; verify no duplicate row.
7. Edit fields and Cancel or swipe down the sheet; verify the saved data is unchanged.
8. Leave VIN and plate blank and save; reopen to verify they remain blank.
9. Swipe Delete and cancel; verify the row remains. Confirm deletion; verify only the selected vehicle disappears.
10. Force-quit and relaunch: verify additions and edits persist and deleted vehicles stay deleted.
11. Confirm Dashboard and Reminders still show their existing placeholders.

Apple reference: [ModelContext](https://developer.apple.com/documentation/swiftdata/modelcontext).

## Maintenance records

Select a vehicle at the top of Maintenance. Add Service records a service for that vehicle; its association is shown in the form and retained when editing. Tap a history row to view/edit all fields, or swipe for Edit/Delete. The list sorts by service date descending. Deletion requires confirmation and removes only the record. If no vehicles exist, the tab directs the user to Garage.

The filtered `@Query` matches `record.vehicle?.id` to the selected vehicle's ID. Changing vehicles rebuilds the history query. New records use `MaintenanceRecord(vehicle: ...)` and `insert`; updates assign fields on the existing record. Both Save and Delete explicitly call `modelContext.save()` and report failures with rollback. Cancel discards the draft. Historical service mileage does not alter the vehicle's odometer.

Service type is required and accepts custom text. Mileage must be a nonnegative integer. Blank cost is nil (unknown), while zero is a known free service. Cost uses Decimal and requires a decimal point, up to two fractional digits, and at most twelve whole digits. Shop and notes may be blank. No notifications, receipt support, or AI functionality is added.

Maintenance verification:

- Swift syntax parsing, project file validation, source membership, and whitespace checks passed.
- Full SwiftUI/SwiftData compilation and simulator persistence testing remain pending because this session blocks Xcode's macro plugin sandbox (see build status above).
- In Simulator, create two vehicles and add different services for each; switch between them and confirm records do not leak across vehicles.
- Add records out of date order; confirm newest service dates appear first. Change a service date while editing and confirm the order updates.
- Edit each field, save, and reopen. Cancel a later edit and confirm saved values remain unchanged.
- Test blank service type, negative/nonnumeric mileage, and invalid cost; verify no record is created. Verify blank cost and zero cost are distinct.
- Cancel deletion, then confirm it; verify the vehicle and its other records remain. Relaunch and verify additions, edits, and deletions persist.

## Dashboard: monthly maintenance costs

Dashboard now contains one card for the current calendar month's maintenance costs through the current time, across all vehicles. It uses service dates, excludes future-dated records, sums Decimal costs, and distinguishes unknown costs from known zero costs. The card displays the month, total, service count, and count of records without costs. Amounts are displayed with a dollar sign and two decimal places; totals assume all entered costs are in dollars.

`DashboardView` observes records with `@Query`, so additions, edits, and deletions update the total. `MonthlyMaintenanceSummary` contains the calculation, and `MonthlyMaintenanceCostCard` renders it. A periodic timeline refreshes the date while the screen is open, including month rollover. No new model fields or data migrations are needed.

Verification: calculation tests cover exact decimal sums, missing versus zero cost, empty history, start-of-month inclusion, prior-month and future exclusion, and month rollover. Swift syntax and project plist checks passed. Full iOS build and visual verification remain pending under the previously documented environment limitation. On device, add/edit/delete a service dated this month and confirm the card updates; services from other months should not contribute.

## Scheduled maintenance

Dashboard now shows up to three active schedules and a Schedule Service button. The Reminders tab shows all active schedules and the same creation form. Choose a saved vehicle, title, first due date and/or odometer reading, optional repeat interval in months and/or miles, and notes. Both deadlines mean whichever comes first. No notification permission or local notification scheduling is implemented.

Dates and mileage are separate deadlines. A mileage deadline displays distance remaining based on the vehicle's stored odometer. A past date is highlighted; reached mileage is highlighted. Blank repeat intervals mean one-time maintenance. Months must be 1–1200 and repeat miles 1–10,000,000; due mileage must be a nonnegative whole number.

Mark Complete requires confirmation. For a one-time service, it sets completed=true and hides the schedule. For repeat schedules, it sets the next date to today plus the month interval and next mileage to current vehicle mileage plus the mile interval. Nonrepeating deadlines are cleared on renewal. Update the Garage odometer before completion. Schedule completion does not add a maintenance record or affect the monthly cost total; record actual work separately in Maintenance. Delete removes the schedule after confirmation.

The existing SwiftData model adds optional repeatMonths and repeatMiles fields, defaulting to nil for existing schedules. Saves are explicit, with rollback and error feedback. Verify migration with an existing store before shipping; no existing store was deleted or recreated.

Validation performed: Swift syntax parsing, Xcode project plist validation, and whitespace checks passed. Full SwiftData compilation, UI testing, and migration testing remain pending under the documented sandbox limitation. Simulator checks: create date-only, mileage-only, and combined schedules; reject blank titles/invalid numbers/no deadlines; verify empty Garage guidance; confirm repeating completion advances both deadlines, one-time completion hides the item, cancellation preserves it, and delete persists after relaunch. Verify the dashboard card updates alongside the full schedule list.
