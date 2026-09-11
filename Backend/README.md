# Local live AI backend

This is a real OpenAI Responses API integration, not mock output. Node.js 22+ is required. No npm dependencies are used. It is not deployed and live requests have not yet been tested with an API key.

1. Create `Backend/.env` privately (ignored by Git):

```text
OPENAI_API_KEY=your-private-openai-key
OPENAI_MODEL=your-structured-output-capable-model-id
GARAGEIQ_ACCESS_TOKEN=your-random-token-at-least-32-characters
```

Generate the access token using `openssl rand -hex 32`. It is a separate local-development credential, not the OpenAI key. Select a model available to your OpenAI project that supports Responses structured outputs. Set API spending limits in your OpenAI project.

2. From Backend, start with `node --env-file=.env server.mjs`.
3. In an iPhone Simulator Debug build, open Dashboard → Assistant. Use `http://localhost:8080/analyze` and enter the backend access token. Select a vehicle, explain a typical driving week, and tap Analyze My Vehicle.

The server binds only to 127.0.0.1 by default. Physical-device access requires an HTTPS backend; localhost on a phone refers to the phone. Release builds require HTTPS. Do not expose this development server publicly: production needs user authentication, per-user quotas, persistent rate limiting and TLS. The shared development token is entered per session and is not embedded or persisted by the app.

Requests are limited to 64 KB, 30 per hour per server process, two concurrent analyses, and a 60-second provider timeout. Limits reset on restart. Upstream errors are sanitized; no prompts, keys, or responses are logged. `store: false` disables Responses storage but is not a promise of zero provider retention. Users initiate each request and see the data categories sent. No VIN, plate, saved notes, costs, or shops are transmitted.

The response uses strict JSON schema and nullable mileage ranges. Missing routine details should produce questions, not fabricated estimates. No manufacturer manual lookup is implemented, so recommendations are general suggestions to verify. The rating describes maintenance documentation, never mechanical health or safety. AI suggestions do not create maintenance records or schedules automatically. A user can explicitly apply a proposed weekly midpoint to their driving profile.

Validation performed: Node syntax, Swift syntax and project plist checks. Full iOS build, endpoint integration and model-quality evaluation need verification. Before relying on results, test sparse history, inconsistent odometers, estimated vs confirmed mileage, safety symptoms, user-text prompt injection, unavailable provider, refusal, and incomplete response cases.

API reference: https://developers.openai.com/api/docs/guides/structured-outputs

## Streaming chat

Dashboard's Assistant now opens GarageIQ Chat. Select a vehicle, enter the `/chat` URL and backend access token, then send a message. The Vehicle analysis toolbar link retains the structured analysis flow. OpenAI's Responses API streams through the server as newline-delimited JSON (`delta`, `done`, or `error`). The server cancels upstream work when the client disconnects and has a 75-second deadline. Shared request/auth limits also cover chat.

Messages and vehicle context are sent on each turn with `store:false`. ChatConversation stores completed message exchanges in SwiftData, separately for each vehicle. Saved conversations can be reopened or a new one started. This version supports up to 20 exchanges and a 64 KB payload; it reports limits rather than silently forgetting history. Failed/stopped replies are not saved as completed exchanges; the draft remains ready to resend. Chat offers advice only and cannot change vehicle data. Use Vehicle analysis to review/apply a structured driving estimate.

No OpenAI key was present in the backend environment or `.env` during implementation. Copy `.env.example` to `.env`, populate the three values privately, then start `node --env-file=.env server.mjs`. Never enter the OpenAI key in the app; the app asks for the separate backend access token. No live provider request has been performed. A ChatGPT subscription or this coding session does not supply a configured API key to this server.

Tests: `node --test chat.test.mjs` passed input-role/size validation, split UTF-8/SSE parsing, streamed completion, and incomplete-stream errors with a fake upstream. Node/Swift syntax and Xcode plist checks passed. Full simulator integration, SwiftData migration/relaunch, Stop behavior on-device, and real provider responses remain to be verified.

Streaming documentation: https://developers.openai.com/api/docs/guides/streaming-responses
