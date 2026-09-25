# GarageIQ

CPSC 411 iOS project for managing vehicles, maintenance history, scheduled maintenance, and AI-assisted vehicle care. Built with Swift, SwiftUI, and SwiftData for iOS 17+, with no third-party iOS dependencies.

## Current features

- **Garage:** add, edit, and delete vehicles with nickname, year, make, model, trim, confirmed odometer, optional VIN and license plate. Deleting a vehicle also deletes its service records and reminders, while retaining chat history.
- **Maintenance:** select a vehicle and add, edit, or delete service records. Each record stores service type, date, historical mileage, optional cost, shop, and notes. History sorts newest first; historical mileage does not change the current odometer.
- **Reminders:** create date-based, mileage-based, or combined schedules with optional repeat intervals. Completing a reminder records the actual service and advances recurring deadlines. Optional local notifications alert before projected or dated deadlines.
- **Dashboard:** vehicle status and one-tap odometer updates, an upcoming-maintenance calendar, an adaptive mileage graph with confidence ranges, and month-to-date costs.
- **Chat:** streamed AI replies, saved conversations, vehicle/garage analysis, and reviewed proposals to add, update, or delete vehicles, create reminders, and record past services.

The Chat navigation title stays fixed while you scroll through the conversation, keeping the screen title visible above your messages.

GarageIQ uses a charcoal dark appearance across every screen, with lavender accents. **Settings** (the gear icon on every main tab) shows the active Dark appearance.

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

The native launch screen displays the GarageIQ brand on a charcoal background while iOS starts the app. A matching SwiftUI startup animation then slides the G in from the left, the Q from the right, and bounces the I down from the top above the Q before revealing the app. The animation runs once per UI startup, lasts about two seconds, and is skipped when Reduce Motion is enabled.

## Architecture

`GarageIQApp` attaches one versioned on-disk SwiftData container with an explicit migration plan containing `Vehicle`, `MaintenanceRecord`, `MaintenanceReminder`, and `ChatConversation`. Views observe data through `@Query` and save using the environment model context. Saves are explicit, with rollback and error feedback.

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
│   ├── Reminders/               Schedule form and active schedule list
│   └── Settings/                Appearance settings and shared gear modifier
├── ViewModels/                  Form drafts and monthly cost calculation
├── Services/                    Streaming chat, analysis, Keychain sessions
├── Utilities/                   Shared adaptive theme colors
└── Resources/                   App icon, logo assets, and launch storyboard
```

Xcode’s project navigator mirrors these folders. Settings and theme colors have their own files; MainTabView contains tab navigation only. The legacy backend is listed separately from the app source.

## Maintenance and driving behavior

Service type and a nonnegative whole-number mileage are required. Blank cost means unknown; zero means a known free service. Costs use Decimal, with up to twelve whole digits and two fractional digits, and are displayed as dollars. Receipt attachments are not implemented.

Vehicle use and expected weekly or monthly miles are required when adding or editing a vehicle. Existing vehicles are preserved and prompted to complete missing profiles. Estimates use miles / 7 or miles / 30.4375 per day as a starting prior and adapt to measured driving. Actual mileage stays separate; manual confirmations are retained in an optional SwiftData Data field, with the previous confirmation backfilled on the next update. Service records provide additional dated readings without overwriting the confirmed odometer. Forecasts and mileage-based service dates share the adaptive rate. No location tracking, background task, or continuous AI requests are required.

Mileage schedules use estimated mileage when enabled, otherwise confirmed mileage. A combined schedule means whichever deadline comes first. Completing a schedule opens a prefilled service form. Saving creates the actual record and completes a one-time reminder; recurring deadlines advance from the recorded service date and odometer. Optional alerts are requested only when the user enables them.

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

The latest Debug simulator build passed. The backend's 24 automated tests passed; three tests in the legacy backend also passed. Provider requests are mocked, so these checks do not establish live AI answer quality or end-to-end saving behavior.

Manual verification should cover:

- Vehicle and service add/edit/delete, form validation, cancellation, cascade deletion, and persistence after relaunch.
- Date-only, mileage-only, and combined schedules; recurrence, completion, deletion, and existing-store migration.
- Mileage accrual, rate changes, odometer corrections, zero driving, and month-to-date cost updates.
- Chat streaming, Stop/retry, saved conversations, proposal dismissal, stale targets, and saving each proposal once.
- Past-service proposals with missing details, ambiguous vehicles, unknown versus zero costs, and history after relaunch.
- Direct routine guidance, uncertain manufacturer specifications, sparse history, and relevant safety symptoms using real provider replies.

Next work includes schedule editing, richer notification timing controls, UI test coverage, and migration verification on physical devices. Public backend use also needs stronger identity and persistent quota controls. Deployment completion has not been verified in this repository.


## Dashboard mileage graph

Choose a vehicle and a three-month, six-month, or one-year forecast horizon. The visible timeline starts today and ends at the selected three-month, six-month, or one-year forecast horizon. Older acquisition and service readings remain saved and continue informing the model without stretching the chart’s date axis. Readings from before the current owner’s tracking start do not count toward learning that owner’s driving rate. White points are actual odometer confirmations, mint diamonds are completed service readings, orange squares are upcoming deadlines, the dashed lavender line is predicted mileage, and the shaded band shows forecast uncertainty. The separate expected-driving line was removed to avoid presenting two nearly identical projections; measured-versus-normal driving remains in the comparison summary. Tap or drag across dates to inspect readings, costs, deadlines, and projected mileage.

**Automatic** starts with the user's driving profile and adapts whenever saved odometer or service readings change. The latest recent reading and the closest prior reading at least seven days earlier (within the last 180 days) produce a measured rate. Automatic blends it with the profile: measured weight = interval days / (interval days + 7). Without a profile it uses the measured rate directly. **Driving profile** and **Recorded history** let users inspect each rate separately. The comparison identifies measured driving more than 20% above or below the entered expectation. Short intervals do not establish a rate, decreasing mileage pauses learning, and rates above 1,000 miles/day are excluded. A single repeated mileage does not erase a nonzero profile forecast.

Adding, editing, or deleting service records recalculates the graph and service timing. Backdated records cannot replace a newer reading; future records are excluded. Actual odometer confirmations are retained across launches. The chat snapshot includes recent confirmations, observed/adaptive rates and the driving comparison so the assistant can tailor service advice to vehicle use and changed habits. Learning is local statistical adaptation; GPT is not continuously retrained and receives updated context on each chat request.

Upcoming markers use whichever of the date deadline or forecast mileage deadline comes first. Reached deadlines appear at Today. With no valid rate, the graph shows recorded readings and explains how to enable projections; schedules without a projectable point remain available in Reminders. A selected zero rate produces a flat forecast and no future mileage-only deadline.

The simulator build passed. Nine standalone calculation tests cover new/edit/deleted service inputs, historical records, learned rates, profile overrides, sparse or inconsistent history, deadline precedence, zero driving, and invalid/overflow data. Run with full Xcode selected:

```sh
sh Tests/MileageForecast/run.sh
sh Tests/VehicleMileagePersistence/run.sh
```

A SwiftData store-reopen check also verifies retained odometer readings, required profiles, and service-driven recalculation.

On-device checks remain: select two vehicles, add/edit/delete records (including via Chat), verify the graph updates without cross-vehicle data, inspect all marker types, test small-screen/Dynamic Type layouts, and check deadlines and sparse-history states. The optional odometerHistoryData field supports preserving confirmations; verify migration with an existing installation before release. Prior confirmations overwritten by older app versions cannot be recovered.

The dashboard maintenance calendar supports month navigation and selecting a day to see all due services across vehicles. Lavender highlights identify scheduled dates; orange dots identify forecast mileage dates. For schedules with both deadlines, it displays whichever comes first. Mileage-only schedules without a valid forecast remain listed below the calendar, and overdue schedules remain highlighted on their original due days. Complete and manage schedules in Reminders; repeating schedules show the next deadline.

Chat vehicle creation is conversational. The assistant reuses details already stated in ordinary language and asks one short follow-up for missing driving habits, normally vehicle use and typical miles per day. It converts daily driving into the stored weekly rate and creates a complete proposal; users never configure the forecast in a form. If an older deployed API returns an incomplete proposal, the app asks the missing question in chat and keeps Save disabled. The adaptive forecast treats the entered routine as a starting baseline and learns from later odometer and service readings, so occasional trips affect the model without requiring manual configuration.

Chat requests provide the device's validated local date, local timestamp with UTC offset, and IANA time-zone identifier as trusted assistant context. Relative phrases such as "today," "yesterday," and "last year on this date" are resolved without asking the user for the clock. Vehicle proposals can include an acquisition date and acquisition odometer. GarageIQ preserves that historical reading, derives a weekly baseline from the acquisition/current mileage interval, uses Mixed use only when no clearer purpose was stated, and continues adapting the forecast from later service and odometer readings.

Chat sends each user message verbatim. Product rules live in the backend system instructions and tool contract; the iOS client no longer appends hidden vehicle-creation directions to short replies. Prior assistant messages and review-proposal fields remain in ordered history so references and one-word follow-ups retain their conversational meaning.

## Reliability updates

The dashboard now puts the current vehicle and odometer action first. Forecast confidence progresses from Learning to Moderate and High as dated readings span longer intervals. The SwiftData schema is explicitly versioned so future model changes can ship with migration stages instead of silently changing the store.
