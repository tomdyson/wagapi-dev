# Mobile App Spec

## Summary

This document defines the v1 scope and technical design for an Expo-based iPhone-first mobile app that edits Wagtail instances with `wagtail-write-api` enabled.

The app is a schema-driven editor for editors working on the go. It is not a full mobile Wagtail admin. The primary demo goal is to show that a phone can connect to an arbitrary `wagtail-write-api` site, open a known page, edit standard fields safely, upload/select images, save drafts, and publish when permitted.

## Product Goals

- Edit known Wagtail pages from iPhone.
- Work against arbitrary Wagtail sites with `wagtail-write-api` enabled.
- Use runtime schema discovery rather than hardcoded page models.
- Prefer safe draft editing over full CMS feature parity.
- Deliver a polished demo that feels credible as a generic editor.

## Non-Goals

- Full Wagtail admin replacement.
- StreamField editing in v1.
- Tree management UI for browsing large content hierarchies.
- Move, copy, delete, and unpublish flows in v1.
- Offline sync, background sync, or conflict resolution.
- Username/password login in v1.

## V1 Scope

### Supported user

- Editors creating or updating pages on the go.

### Supported content flow

- Connect to a Wagtail site with base URL and bearer token.
- Open a page by ID or URL path.
- Load the page detail and type schema.
- Edit supported standard fields.
- Browse or upload images for image chooser fields.
- Save draft changes.
- Publish if the authenticated user has `publish` permission.
- Restore unsaved local edits for a page if the app is reopened.

### Deferred content flow

- StreamField editing.
- Revision browsing and restore.
- Unpublish, move, copy, delete.
- General page-tree browsing.
- Document chooser support.

## Core API Constraints

The app is designed around the existing `wagtail-write-api` behavior:

- Authentication uses `Authorization: Bearer <token>`.
- `GET /schema/page-types/` lists page types and parent/child constraints.
- `GET /schema/page-types/{type}/` returns JSON Schema for `create_schema`, `patch_schema`, `read_schema`, and `streamfield_blocks`.
- `GET /pages/{id}/` returns the latest draft by default.
- `GET /pages/?path=/some/path/` can resolve a known URL path to a page.
- `PATCH /pages/{id}/` creates a new revision and saves draft changes.
- `POST /pages/{id}/publish/` publishes the latest revision.
- `GET /images/` and `POST /images/` support image browsing and upload.
- `meta.user_permissions` on page detail is the source of truth for action gating.

## UX Principles

- iPhone-first layout and control density.
- Known-page editing is faster than browsing.
- Draft vs published status must always be visible.
- Save and publish actions must be obvious and permission-aware.
- Unsupported fields must be clearly marked, not silently dropped.
- Unsaved local edits must feel safe and recoverable.

## Primary User Flows

### 1. Connect to a site

User enters:

- API base URL, e.g. `https://cms.example.com/api/write/v1`
- bearer token

App validates the connection by calling a lightweight authenticated endpoint, preferably `GET /schema/page-types/`.

On success:

- store credentials securely
- cache available page types
- take the user to the open-page flow

### 2. Open a known page

User chooses one of:

- open by page ID
- open by URL path

If path is used, the app resolves it via `GET /pages/?path=...`.

Then the app:

- fetches page detail
- reads `meta.type`
- fetches that type schema
- builds an editable form for supported fields
- loads any saved local unsaved edits for that page

### 3. Edit page

The editor displays:

- page title and type
- draft/live status
- supported editable fields
- unsupported fields with explanation
- persistent save action
- publish action when permitted

### 4. Upload or choose image

For image chooser fields, the user can:

- search existing images
- pick an existing image
- upload a new image from photo library

Uploaded images become selectable immediately after successful upload.

### 5. Save draft

Saving issues a `PATCH /pages/{id}/` request with only the changed supported fields.

On success:

- clear local unsaved draft for fields covered by the save
- refresh page detail
- refresh status indicators

### 6. Publish

If `meta.user_permissions` includes `publish`, the user can publish.

The app calls `POST /pages/{id}/publish/`.

On success:

- refresh page detail
- show updated draft/live status

## Supported Field Contract

The app is generic, but only for a defined supported field matrix in v1.

### Fully supported

- `string`
- `text`
- `boolean`
- `integer`
- `float`
- `date`
- `datetime`
- enum/choice values derived from schema `enum`
- nullable variants of the above
- image chooser fields represented as image IDs

### Conditionally supported

- arrays of simple objects for orderable child items, only when the object schema is shallow and all child properties are themselves supported scalar fields

### Rich text support

For rich text fields outside StreamField:

- present a Markdown editor UI
- submit values as `{ "format": "markdown", "content": "..." }`
- treat server-returned strings as initial text if necessary

### Unsupported in v1

- any StreamField
- nested `object` schemas beyond a shallow orderable use case
- nested arrays
- page chooser
- document chooser
- custom chooser types
- arbitrary polymorphic structures

When unsupported fields are present:

- show them in a dedicated read-only section
- explain that v1 does not support editing that field type yet
- do not include them in PATCH payloads unless they are preserved from untouched state by explicit implementation

## Technical Spec

### Stack

- Expo (latest stable SDK at implementation time)
- React Native
- TypeScript
- Expo Router for navigation
- TanStack Query for server data fetching and cache management
- Zustand for local app/session/editor state
- Expo SecureStore for credentials
- Expo ImagePicker for photo-library image selection
- AsyncStorage for local unsaved draft persistence and lightweight caches
- `zod` for runtime validation of API responses where useful

### Why this stack

- Expo speeds iPhone-first delivery and native capability access.
- Expo Router keeps navigation file-based and simple.
- TanStack Query is well-suited to authenticated API reads, mutation flows, retry control, and cache invalidation.
- Zustand is enough for transient editor state without introducing form-heavy global complexity.
- SecureStore is the right place for bearer tokens.

## App Architecture

### Layers

#### 1. API layer

Thin functions around HTTP requests:

- `getPageTypes()`
- `getPageTypeSchema(type)`
- `getPageById(id)`
- `getPageByPath(path)`
- `patchPage(id, payload)`
- `publishPage(id)`
- `listImages(params)`
- `uploadImage(file, title?)`

Responsibilities:

- inject auth header
- normalize base URL handling
- parse API errors into app-friendly error objects
- keep request/response types explicit

#### 2. Domain layer

Transforms raw API responses into editor-friendly state:

- field capability detection
- supported vs unsupported field partitioning
- initial form value normalization
- dirty field tracking
- PATCH payload building from changed values only

#### 3. Persistence layer

- secure credential storage via SecureStore
- local unsaved page drafts via AsyncStorage
- optional recent page shortcuts cache

Draft persistence key shape:

`draft:{connectionId}:{pageId}`

#### 4. UI layer

Screens, reusable field components, action bars, error states, and modal flows.

## Data Models

### Connection

```ts
type Connection = {
  id: string;
  name: string;
  baseUrl: string;
  tokenRef: string;
  createdAt: string;
  updatedAt: string;
};
```

`tokenRef` points to a SecureStore entry rather than storing the token in plain local state.

### Page reference

```ts
type PageRefInput =
  | { kind: "id"; value: number }
  | { kind: "path"; value: string };
```

### Supported field descriptor

```ts
type FieldKind =
  | "text"
  | "textarea"
  | "markdown"
  | "boolean"
  | "number"
  | "date"
  | "datetime"
  | "select"
  | "image"
  | "simple-list-object";

type SupportedFieldDescriptor = {
  name: string;
  label: string;
  kind: FieldKind;
  required: boolean;
  nullable: boolean;
  readOnly: boolean;
  enumOptions?: Array<{ label: string; value: string }>;
  objectFields?: SupportedFieldDescriptor[];
};
```

### Unsupported field descriptor

```ts
type UnsupportedFieldDescriptor = {
  name: string;
  reason:
    | "streamfield"
    | "nested-object"
    | "nested-array"
    | "page-chooser"
    | "document-chooser"
    | "unknown-schema";
};
```

### Editor state

```ts
type EditorState = {
  pageId: number;
  pageType: string;
  live: boolean;
  hasUnpublishedChanges: boolean;
  permissions: string[];
  initialValues: Record<string, unknown>;
  currentValues: Record<string, unknown>;
  dirtyFields: string[];
  supportedFields: SupportedFieldDescriptor[];
  unsupportedFields: UnsupportedFieldDescriptor[];
  lastSavedAt?: string;
  restoredDraft: boolean;
};
```

## Schema Interpretation Rules

The app should not trust that all JSON Schema can be rendered generically. It should classify fields defensively.

### Rules

1. Ignore infrastructure fields such as `id`, `type`, and `parent` in page edit mode.
2. Determine required fields from the schema `required` array.
3. Handle nullable values via `anyOf` containing `null`.
4. Render enums as select controls.
5. Treat rich text fields as Markdown-capable only when the schema or known API field metadata indicates rich text semantics.
6. If a field resolves to StreamField or `streamfield_blocks` applies, mark unsupported.
7. For arrays, support only shallow arrays of objects with supported scalar child fields.
8. Preserve unknown fields from the server in memory if needed for future compatibility, but do not claim they are editable.

## Screen Spec

### Connection Setup

Purpose:

- enter base URL and token
- validate and save connection

UI:

- `Name` optional text input
- `Base URL` input
- `Token` secure text input
- `Test connection` button
- `Save connection` button

Validation:

- require HTTPS by default unless running in dev mode or user explicitly confirms local HTTP
- normalize trailing slashes
- ensure URL points at API root, not site root

### Open Page

Purpose:

- open a known page quickly

UI:

- segmented control: `Page ID` / `URL Path`
- input field
- recent pages list if available
- `Open` button

Behavior:

- if path is provided, resolve to page via `GET /pages/?path=...`
- handle 0 or >1 results cleanly

### Page Editor

Purpose:

- edit the page safely

UI sections:

- page header
- status badge: draft / live / live with draft changes
- supported fields form
- unsupported fields section
- action bar

Action bar:

- `Save Draft`
- `Publish` when permitted
- dirty-state indicator

### Image Picker Modal

Purpose:

- choose or upload an image for image fields

UI:

- search input
- existing image results with thumbnails
- `Upload from Photos`
- upload progress indicator

## Field Component Spec

### Text field

- single-line input
- used for title, slug, short strings

### Textarea field

- multiline input
- used for long plain text

### Markdown field

- multiline editor
- monospace or editing-friendly font
- optional lightweight preview toggle later, not required for v1

### Boolean field

- switch control

### Number field

- numeric keyboard
- separate integer vs float validation

### Date field

- iOS date picker where practical
- otherwise validated text input using ISO date

### Datetime field

- iOS date/time picker where practical
- serialize to ISO datetime string

### Select field

- native picker or action sheet pattern

### Image field

- thumbnail if selected
- `Choose image` action
- `Remove image` action when nullable

### Simple list object field

- repeated card rows for shallow orderable items
- add/remove/reorder if needed for that specific shallow schema
- defer if no real example requires it

## Mutation Rules

### Save draft

PATCH payload rules:

- include only dirty supported fields
- omit unsupported fields
- keep field names exactly as the API expects
- for rich text, send markdown wrapper object
- for image fields, send selected image ID or `null`

### Publish

- publish is a separate mutation via `POST /pages/{id}/publish/`
- only enable if `publish` permission is present

### Error handling

Map API errors to user-facing messages:

- `401`: invalid token or expired session
- `403`: permission denied
- `404`: page not found
- `422`: invalid field or page-type constraint error
- network failure: unreachable server or TLS issue

## Draft Persistence

Local unsaved drafts are required, but only locally on the device.

### Rules

- persist editor state after field changes with debounce
- restore on reopening the same page under the same connection
- clear persisted draft after successful save
- if server data changed since draft was persisted, prefer asking the user whether to restore the local draft or discard it

Minimal v1 simplification:

- compare against page `latest_revision` metadata if exposed later
- if not available, restore local draft with a warning that server content may have changed

## Security

- Store bearer tokens only in SecureStore.
- Never log full tokens.
- Redact auth headers in debug logging.
- Do not cache tokens in AsyncStorage.
- Consider app-level biometric unlock later, but not required for v1.

## Demo Strategy

To make the demo impressive, optimize for a reliable happy path:

- fast connection setup
- obvious known-page opening
- clean form rendering for standard fields
- photo library upload working smoothly
- visible draft/publish state
- clear unsupported StreamField messaging rather than broken UI

The demo should show a site with at least one page type that has:

- title
- slug
- plain text or rich text body
- boolean or date field
- image chooser field

## Implementation Milestones

### Milestone 1: Scaffold and connection flow

- create Expo app
- add navigation and state libraries
- implement connection setup and secure storage
- test authenticated schema fetch

### Milestone 2: Page loading

- implement open-by-ID and open-by-path
- fetch page detail and page type schema
- display basic page header and status

### Milestone 3: Schema-driven editor

- classify supported vs unsupported fields
- render v1 supported fields
- track dirty state
- persist local unsaved draft

### Milestone 4: Save and publish

- build PATCH payloads from dirty fields
- implement save draft
- implement publish action and permission gating
- refresh page detail after mutations

### Milestone 5: Image support

- image search/list modal
- image chooser field integration
- photo-library upload flow

### Milestone 6: Demo polish

- error states
- loading states
- unsupported field messaging
- iPhone layout polish

## Open Questions For Implementation

- Whether to support multiple saved connections in v1 or keep a single-site demo flow.
- Whether rich text fields can be detected entirely from schema without additional heuristics from real API responses.
- Whether any target demo models include shallow orderable child objects that should be supported in the first pass.
- Whether to add a limited “recent pages” list even though broad browsing is not a v1 priority.

## Recommended Next Step

Build the app around a narrow contract: "schema-driven mobile editing for supported standard fields." The implementation should aggressively separate supported and unsupported capabilities so that future StreamField work can be added without rewriting the editor architecture.
