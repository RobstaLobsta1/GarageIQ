# GarageIQ

CPSC 411 iOS project for managing vehicles, maintenance history, scheduled maintenance, and AI-assisted vehicle care. Built with Swift, SwiftUI, and SwiftData for iOS 17+, with no third-party iOS dependencies.

## Current features

- **Garage:** add, edit, and delete vehicles with nickname, year, make, model, trim, confirmed odometer, optional VIN and license plate. Deleting a vehicle also deletes its service records and reminders, while retaining chat history.
- **Maintenance:** select a vehicle and add, edit, or delete service records. Each record stores service type, date, historical mileage, optional cost, shop, and notes. History sorts newest first; historical mileage does not change the current odometer.
- **Reminders:** create date-based, mileage-based, or combined schedules with optional repeat intervals. Mark complete or delete after confirmation. These are in-app schedules; phone notifications are not implemented.
- **Dashboard:** month-to-date maintenance costs across all vehicles, driving estimates, and up to three active schedules.
- **Chat:** streamed AI replies, saved conversations, vehicle/garage analysis, and reviewed proposals to add, update, or delete vehicles, create reminders, and record past services.

The Chat navigation title stays fixed while you scroll through the conversation.

## Open and build

1. Open `GarageIQ.xcodeproj` in Xcode 15 or newer.
2. Select the GarageIQ scheme and an installed iPhone simulator.
3. Build with Command-B and run with Command-R.
4. Add a vehicle in Garage or through a reviewed Chat proposal, then record maintenance and create schedules.

For a physical device, select your signing team and a unique bundle identifier. The current project identifier is `com.example.GarageIQ`.

From this repository root, with Xcode selected:

```sh
xcodebuild -project GarageIQ.xcodeproj -scheme GarageIQ -configuration Debug -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The Debug simulator build succeeded during the latest service-record update. On-device behavior, persistence after relaunch, and migration of existing stores still require verification. Earlier sandbox-related compiler macro failures were resolved by running the verification build outside the agent sandbox.

## Architecture

`GarageIQApp` attaches one on-disk SwiftData container containing `Vehicle`, `MaintenanceRecord`, `MaintenanceReminder`, and `ChatConversation`. Views observe data through `@Query` and save using the environment model context. Saves are explicit, with rollback and error feedback.

Vehicle and maintenance forms use value-type drafts for validation; Cancel leaves saved models untouched. Chat conversations store a Codable transcript as Data, including proposal fields and saved/dismissed status. Accepted proposals and their transcript status save together. Pending changes to an existing vehicle are rejected if the target was removed or its tracked fields changed after the proposal was generated.

```text
GarageIQ/
├── App/                         App entry point and persistent container
├── Models/                      Vehicles, records, reminders, conversations
├── Views/
│   ├── MainTabView.swift         Chat, Dashboard, Maintenance, Reminders, Garage
│   ├── Assistant/               Chat and retained legacy analysis view
│   ├── Dashboard/               Driving estimates, costs, upcoming schedules
│   ├── Garage/                  Vehicle list and shared add/edit form
│   ├── Maintenance/             Vehicle selection, history, service form
│   └── Reminders/               Schedule form and active schedule list
├── ViewModels/                  Form drafts and monthly cost calculation
├── Services/                    Streaming chat, analysis, Keychain sessions
└── Resources/                   Asset catalog
```

## Maintenance and driving behavior

Service type and a nonnegative whole-number mileage are required. Blank cost means unknown; zero means a known free service. Costs use Decimal, with up to twelve whole digits and two fractional digits, and are displayed as dollars. Receipt attachments are not implemented.

Driving estimates are optional. Enter total typical weekly or monthly miles in Garage; estimates accrue from a dated baseline using miles / 7 or miles / 30.4375 per day. Confirmed mileage stays separate. Manual profile-rate changes preserve accrued estimated distance, while an odometer correction or confirmation resets the baseline. Estimates require no location tracking or background task.

Mileage schedules use estimated mileage when enabled, otherwise confirmed mileage. A combined schedule means whichever deadline comes first. Completing a one-time schedule hides it. Repeating deadlines advance from completion time and the current estimated or confirmed mileage; nonrepeating dimensions are cleared. Completion does not create a service record—record actual work separately.

## AI backend

The active backend is the separate [GarageIQ-API repository](https://github.com/RobstaLobsta1/GarageIQ-API), intended for Render hosting. The app currently points to `https://garageiq-api.onrender.com` for chat, analysis, and anonymous session issuance. Session tokens are stored in Keychain; the OpenAI key and session-signing secret stay on the backend. The GPT model is selected by Render's `OPENAI_MODEL` environment variable, not by the iOS app. Its deployed value is not confirmed by this repository.

The `Backend/` folder is an older local development implementation. It uses a development-token authentication flow and does not implement the current reviewed actions; use GarageIQ-API for the current app. Changing a chat endpoint alone does not redirect session issuance, which remains hardcoded to Render.

Sending chat shares the conversation and a snapshot of all saved vehicles' specifications, confirmed/estimated mileage, driving profiles, service dates/types/mileages, and active schedule deadlines. Saved VIN, plate, costs, shops, and notes are excluded from the snapshot. Text typed in chat and fields contained in past proposals can still be included in the conversation sent to the backend and OpenAI.

The assistant gives direct general maintenance explanations and typical intervals with assumptions. Manufacturer-specific requirements remain unverified unless a source is supplied; manufacturer reference retrieval is not implemented. Maintenance documentation is distinct from mechanical condition, and the assistant cannot certify roadworthiness. Advice does not authorize saved changes.

### Past service records through Chat

Example: “Record an oil change for my Civic on March 12, 2025 at 45,000 miles, costing $89.95.”

The assistant gathers the target vehicle, service type, actual date, and historical odometer. Cost, shop, and notes are optional. Review the card and tap **Save service** or **Dismiss**. Saving adds a maintenance record without changing the vehicle odometer or completing a reminder. Saved or dismissed proposals cannot be applied again. Existing records can be edited or deleted in Maintenance; those operations are not available through Chat.

Both the updated API and a rebuilt iOS app are needed for this action. Backend instruction-only updates require an API deployment but no app rebuild.

## Verification and remaining work

The latest Debug simulator build passed. The backend's 12 automated tests passed; three tests in the legacy backend also passed. Provider requests are mocked, so these checks do not establish live AI answer quality or end-to-end saving behavior.

Manual verification should cover:

- Vehicle and service add/edit/delete, form validation, cancellation, cascade deletion, and persistence after relaunch.
- Date-only, mileage-only, and combined schedules; recurrence, completion, deletion, and existing-store migration.
- Mileage accrual, rate changes, odometer corrections, zero driving, and month-to-date cost updates.
- Chat streaming, Stop/retry, saved conversations, proposal dismissal, stale targets, and saving each proposal once.
- Past-service proposals with missing details, ambiguous vehicles, unknown versus zero costs, and history after relaunch.
- Direct routine guidance, uncertain manufacturer specifications, sparse history, and relevant safety symptoms using real provider replies.

Next work includes schedule editing, a completion flow that records actual maintenance, local notifications, iOS test coverage, and migration verification. Public backend use also needs stronger identity and persistent quota controls. Deployment completion has not been verified in this repository.
