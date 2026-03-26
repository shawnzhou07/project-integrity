# Veritas Architecture Reference

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

## App Structure

### Root View State Machine

`RootView` in `App.swift` is the entry point. It reads two `@AppStorage` flags and routes accordingly:

```
hasSeenTutorial == false  →  TutorialView
hasSeenTutorial == true AND hasCompletedOnboarding == false  →  OnboardingView
hasSeenTutorial == true AND hasCompletedOnboarding == true   →  MainTabView
```

**UserDefaults keys controlling root routing:**

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `hasSeenTutorial` | Bool | `false` | Whether the 6-slide tutorial has been dismissed |
| `hasCompletedOnboarding` | Bool | `false` | Whether onboarding (currency + platform setup) is complete |

All transitions use `.easeInOut(duration: 0.35)` opacity animation via `withAnimation`.

### Startup Migration

`App.swift` runs `migrateHandsCountIfNeeded()` at init time. This is a one-time data migration guarded by UserDefaults key `didMigrateHandsCount_v1`. It back-fills `handsCount` estimates for sessions that were saved with `handsCount == 0`, using the same formula as the entry forms (hours × handsPerHour × tables for online; hours × handsPerHour for live).

---

## Navigation

### Tab Structure

`MainTabView` hosts a `TabView` with 4 root destinations. Each tab is wrapped in its own `NavigationStack`, so push navigation is fully isolated per tab.

| Tab Index | Label | Icon | Root View |
|-----------|-------|------|-----------|
| 0 | Sessions | `rectangle.stack.fill` | `SessionsListView` |
| 1 | Stats | `chart.bar.fill` | `StatsView` |
| 2 | Platforms | `building.columns.fill` | `PlatformsListView` |
| 3 | More | `ellipsis` | `MoreView` |

### More Tab Navigation (Push)

`MoreView` provides `NavigationLink` push destinations:
- Locations → `LocationsListView`
- Charts → `ChartsView`
- Calendar → `CalendarView`
- Adjustments → `AdjustmentsListView`
- Settings → `SettingsView`

### Sheet vs Push Navigation

**Push navigation (NavigationLink):** Used for all drill-down flows — session detail, platform detail, analytics, location detail, adjustment detail, charts, calendar.

**Sheets:** Used for creation/entry flows that should feel modal:
- Add session (type picker → form)
- Add deposit / withdrawal / adjustment
- Filter sheet
- Tutorial replay (from Settings)
- Mark withdrawal received

**Full-screen cover:** `SessionEntryContainerView` is presented as a `.fullScreenCover` from `MainTabView` via `sessionCoordinator.isFormPresented`. This handles all new session entry flows (Live and Online).

### Cross-Tab Navigation

`ActiveSessionCoordinator` is an `ObservableObject` injected as an `@EnvironmentObject` into the entire app from `MainTabView`. It allows any view to:
- Switch the selected tab (`selectedTab: Int`)
- Open the session creation form (`isFormPresented: Bool`)
- Navigate to an active live session (`navigateToActiveLiveSession: LiveCash?`)
- Navigate to an active online session (`navigateToActiveOnlineSession: OnlineCash?`)
- Trigger adjustment creation for a specific platform (`adjustmentPlatformID: NSManagedObjectID?`)

---

## MVVM Pattern

### Data Observation

- `@FetchRequest` is used in all views that display Core Data lists. Changes are automatically propagated by Core Data's change tracking.
- `@ObservedObject` is used for individual `NSManagedObject` instances (e.g., `PlatformDetailView(platform:)`, `LiveSessionDetailView(session:)`).
- `@StateObject` is used for `FilterState`, `ChartFilterState`, and `ActiveSessionCoordinator` — objects that own their lifecycle.
- `@EnvironmentObject` is used to share `ActiveSessionCoordinator` and `FilterState` across the view hierarchy without prop drilling.

### State Management

- All form state is held in `@State` properties on the view.
- Filters are held in `FilterState` (ObservableObject) which is created with `@StateObject` and passed down.
- `ChartFilterState` is also `@StateObject` and persists chart axis selections to UserDefaults.
- `@AppStorage` is used for settings that need to persist: `baseCurrency`, `hasSeenTutorial`, `hasCompletedOnboarding`, `exchangeRateInputMode`, `handsPerHourOnline`, `handsPerHourLive`, etc.

### Save Pattern

After every mutation, the view calls `try viewContext.save()`. There is no deferred-save or batching pattern — saves are immediate and synchronous on the main context. This ensures the UI reflects data changes instantly.

---

## Core Data Stack

### Container Setup (`Persistence.swift`)

```swift
container = NSPersistentContainer(name: "DataModel")
description.shouldMigrateStoreAutomatically = true
description.shouldInferMappingModelAutomatically = true
container.viewContext.automaticallyMergesChangesFromParent = true
container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
```

- Container name: `DataModel` (resolves to `DataModel.xcdatamodeld`)
- Store type: SQLite (default), local only
- No CloudKit integration (`usedWithCloudKit="false"` in model)
- Lightweight migration enabled — new model versions can be added without custom mapping models, provided changes are lightweight (add optional attribute, add entity, add relationship)
- Merge policy: `NSMergeByPropertyObjectTrumpMergePolicy` — in-memory changes trump persistent store on conflict

### Context Usage

- **viewContext** (`container.viewContext`): All reads and writes happen on the main queue view context. No background contexts are used.
- `automaticallyMergesChangesFromParent = true` is set, though no parent context exists currently — this is forward-compatible for future background saving.

### Saving

`PersistenceController.save()` checks `ctx.hasChanges` before calling `ctx.save()`. Views call `try viewContext.save()` directly inline after mutations.

### Location Deletion

`PersistenceController.deleteLocation(_:context:)` handles the special case of deleting a location — it first nils out the `locationEntity` relationship on all attached `LiveCash` sessions (preserving the legacy `location` String field as a display fallback) before deleting the `Location` object.

---

## Computed Platform Balance

The balance is **never stored** in Core Data. It is computed on every access via the `currentBalance` computed property on `Platform`.

### Anchor Selection

The anchor is the **most recent verified `OnlineCash` session** for this platform, selected by maximum `endTime`:

```swift
var anchorSession: OnlineCash? {
    onlineSessionsArray
        .filter { $0.isVerified && $0.endTime != nil }
        .max(by: { ($0.endTime ?? .distantPast) < ($1.endTime ?? .distantPast) })
}
```

### Balance Formula With Anchor

```
balance = anchor.balanceAfter
        + Σ deposits.amountReceived     where deposit.date > anchor.endTime
        − Σ withdrawals.amountRequested where withdrawal.date > anchor.endTime
                                        AND status IN ("pending", "received")
        + Σ adjustments.effectiveAmount where adjustment.date > anchor.endTime
```

The strict `>` comparison (not `>=`) ensures that records at the exact same timestamp as the anchor are treated as pre-anchor and not double-counted.

### Balance Formula Without Anchor

If no verified session exists for this platform:

```
balance = Σ deposits.amountReceived
        − Σ withdrawals.amountRequested (status: pending or received)
        + Σ adjustments.effectiveAmount
```

### Why Computed, Not Stored

Storing the balance would require it to be updated on every deposit, withdrawal, adjustment, and session verification — creating race conditions, stale data on import/restore, and the possibility of manual corruption. Computing it on demand from immutable verified records guarantees mathematical consistency.

### Platform-Switch Corruption Bug (Prevented)

If a deposit or withdrawal were dated before the anchor session, storing a running balance would require retroactively updating historical snapshots. The computed approach sidesteps this entirely — the anchor absorbs all history, and only post-anchor records are summed.

---

## Platform Net Result Formula

### Net Result in Base Currency

Uses the weighted average deposit rate (cost basis):

```
weightedAvgDepositRate = totalDepositsSentBase / totalDepositsReceivedPlatformCurrency

For each withdrawal:
  - If status == "received": contribute amountReceived (base currency)
  - Else if isForeignExchange && effectiveExchangeRate > 0: contribute amountRequested × effectiveExchangeRate
  - Else: contribute amountRequested × weightedAvgDepositRate

netResult = withdrawalsContributionBase
          + (currentBalance × weightedAvgDepositRate)
          − totalDepositsSentBase
```

For same-currency platforms: `weightedAvgDepositRate = 1.0`.

### Net Result in Platform Currency

```
netResultInPlatformCurrency = totalWithdrawalsRequested + currentBalance − totalDepositsReceived
```

---

## Session Verification System

### What Locks on Verification

**Live sessions:** `startTime`, `endTime`, `buyIn`, `cashOut`, `exchangeRateBuyIn`, `exchangeRateCashOut`, `exchangeRateToBase`

**Online sessions:** `startTime`, `endTime`, `balanceBefore`, `balanceAfter`

These fields are rendered as read-only with a gold lock icon once `isVerified == true`. The UI never provides an edit path for these fields on verified sessions.

### What Remains Editable After Verification

`gameType`, `blinds` (smallBlind, bigBlind, straddle, ante), `tableSize`, `notes`, `handsCount`, `breakTime`, `tips` (live only), `location` / `locationEntity` (live only).

### One-Unverified-at-a-Time Enforcement

Before allowing a new session to be created, `SessionsListView` checks for any session matching `isVerified == NO AND endTime != nil`. If one exists, the add action is blocked and an alert is shown with an option to navigate to the unverified session.

### Verification Cannot Be Undone

There is no undo path once `isVerified = true` is saved. The UI does not provide any such action.

### Verification as Balance Anchor

When an online session is verified, it immediately becomes eligible as the anchor for `currentBalance` (since `anchorSession` filters by `isVerified == true`). If it has a later `endTime` than the previous anchor, it becomes the new anchor.

---

## Exchange Rate System

### Mode A — Direct Rate Entry

User types the exchange rate (e.g., `1.36` for USD→CAD). The app calculates the base currency equivalent. Stored as `exchangeRateInputMode = "direct"` in UserDefaults.

### Mode B — Amounts Entry

User types both the foreign amount and the base amount. The app back-calculates the effective rate. Stored as `exchangeRateInputMode = "amounts"`.

### Live Session Exchange Rates

Two separate rates are stored per live session:
- `exchangeRateBuyIn`: Rate applied when buying chips
- `exchangeRateCashOut`: Rate applied when cashing out

Net result in base currency: `(cashOut × exchangeRateCashOut) − (buyIn × exchangeRateBuyIn)`

If only a single `exchangeRateToBase` is set (legacy), net result uses: `netResult × exchangeRateToBase`.

### Online Session Exchange Rates

Online sessions do not have per-session exchange rate fields. Their net profit/loss is stored in platform currency (`netProfitLoss`) and base currency (`netProfitLossBase`). The base conversion uses the session-level `exchangeRateToBase` field.

### Default Rates (UserDefaults)

| Key | Default | Purpose |
|-----|---------|---------|
| `defaultRateUSDToBase` | 1.36 | USD → base (CAD) |
| `defaultRateEURToBase` | 1.47 | EUR → base (CAD) |
| `defaultRateUSDToEUR` | 0.92 | USD → EUR |

---

## Withdrawal State Machine

```
[Create withdrawal]
        │
        ▼
    pending ──────────────────────────► received
    (amountRequested set,               (amountReceived set,
     amountReceived = 0,                 receivedDate set,
     deducts from balance)               still deducts same amountRequested)
        │
        ▼
      failed
    (record deleted,
     balance restored)
```

- `pending` and `received` both deduct `amountRequested` from platform balance
- `received` additionally records `amountReceived` in base currency and `effectiveExchangeRate`
- `failed` = the withdrawal record is deleted entirely; balance is restored because the record no longer exists

---

## Data Persistence

### Storage

All data is local SQLite via Core Data. No iCloud sync, no CloudKit, no network dependency.

### JSON Export

`SettingsView` provides a full data export to JSON. The export structure is defined by `ExportData` (Codable) and includes:
- `exportVersion: Int` (currently 1)
- `exportDate: Date`
- `baseCurrency: String`
- All entities: platforms, liveSessions, onlineSessions, deposits, withdrawals, adjustments, locations

Export is performed on a background thread and shared via `UIActivityViewController`.

### JSON Import

Import is **hard-blocked** if any data exists in any entity. The user must perform a full reset first. Import matches platforms by `name` (String) and assigns new UUIDs to all records. The `exportVersion` field is used for forward compatibility.

---

## Notification Pattern

No `NotificationCenter` notifications are currently used in this codebase. Cross-view communication is handled exclusively through:
- `@EnvironmentObject` (ActiveSessionCoordinator)
- `@FetchRequest` reactive updates
- SwiftUI view model `@Published` properties

---

## Key UserDefaults Keys (Complete Reference)

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `hasSeenTutorial` | Bool | false | Root routing — tutorial gate |
| `hasCompletedOnboarding` | Bool | false | Root routing — onboarding gate |
| `baseCurrency` | String | "CAD" | Base currency for all profit reporting |
| `exchangeRateInputMode` | String | "direct" | "direct" = Mode A, "amounts" = Mode B |
| `handsPerHourOnline` | Int | 85 | Hands/hour estimate for online sessions |
| `handsPerHourLive` | Int | 25 | Hands/hour estimate for live sessions |
| `showAdjustmentsInStats` | Bool | true | Whether adjustments are included in stats total |
| `defaultRateUSDToBase` | Double | 1.36 | Default USD→base exchange rate |
| `defaultRateEURToBase` | Double | 1.47 | Default EUR→base exchange rate |
| `defaultRateUSDToEUR` | Double | 0.92 | Default USD→EUR exchange rate |
| `didMigrateHandsCount_v1` | Bool | false | One-time migration guard for handsCount backfill |
| `chartXAxis` | String | "sessions" | Persisted chart X axis selection |
| `chartYAxis` | String | "netResult" | Persisted chart Y axis selection |
| `chartDateRange` | String | "allTime" | Persisted chart date range |
