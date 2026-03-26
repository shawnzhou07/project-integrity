# Veritas Data Model Reference

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

## Entities

### Platform

Represents an online poker platform (e.g., PokerStars Ontario, GGPoker).

| Attribute | Type | Optional | Default | Description | Locked After Verification |
|-----------|------|----------|---------|-------------|--------------------------|
| `id` | UUID | Yes | — | Unique identifier | N/A |
| `name` | String | Yes | — | Platform display name (e.g., "PokerStars Ontario") | No |
| `currency` | String | Yes | — | Platform currency code (e.g., "CAD", "USD") | No |
| `createdAt` | Date | Yes | — | Creation timestamp | No |
| `defaultTableSize` | Int16 | No | 6 | Default table size for new sessions on this platform | No |
| `currentBalance` | Double | Yes | 0.0 | **Legacy attribute — never read or written by the app.** Balance is computed, not stored. See `currentBalance` computed property. | N/A |

**Note:** The `currentBalance` attribute exists in the Core Data schema but is not exposed as `@NSManaged` in `CoreDataModels.swift`. The app exclusively uses the computed `currentBalance` property defined in `BusinessLogic.swift`.

### OnlineCash

Represents a single online cash game session on a platform.

| Attribute | Type | Optional | Default | Description | Locked After Verification |
|-----------|------|----------|---------|-------------|--------------------------|
| `id` | UUID | Yes | — | Unique identifier | No |
| `startTime` | Date | Yes | — | Session start timestamp | **Yes** |
| `endTime` | Date | Yes | — | Session end timestamp; nil = session is active | **Yes** |
| `duration` | Double | Yes | 0.0 | Stored duration in hours (legacy); prefer `computedDuration` | No |
| `gameType` | String | Yes | — | e.g., "No Limit Hold'em", "Pot Limit Omaha" | No |
| `blinds` | String | Yes | — | Display string e.g., "$0.25/$0.50" | No |
| `smallBlind` | Double | Yes | 0.0 | Small blind amount in platform currency | No |
| `bigBlind` | Double | Yes | 0.0 | Big blind amount in platform currency | No |
| `straddle` | Double | Yes | 0.0 | Straddle amount (0 = no straddle) | No |
| `ante` | Double | Yes | 0.0 | Ante amount (0 = no ante) | No |
| `breakTime` | Double | Yes | 0.0 | Break duration in minutes | No |
| `tableSize` | Int16 | Yes | 9 | Max players at the table | No |
| `tables` | Int16 | Yes | — | Number of tables played simultaneously | No |
| `balanceBefore` | Double | Yes | 0.0 | Account balance before session started | **Yes** |
| `balanceAfter` | Double | Yes | 0.0 | Account balance after session ended | **Yes** |
| `netProfitLoss` | Double | Yes | 0.0 | Net result in platform currency (`balanceAfter − balanceBefore`) | No |
| `netProfitLossBase` | Double | Yes | 0.0 | Net result in base currency | No |
| `exchangeRateToBase` | Double | Yes | 1.0 | Exchange rate: platform currency → base currency at session time | No |
| `handsCount` | Int32 | Yes | 0 | Actual hands played (0 = use estimate) | No |
| `notes` | String | Yes | — | Free-form session notes | No |
| `isVerified` | Bool | Yes | false | Whether this session has been verified and locked | No (the flag itself) |

### LiveCash

Represents a single live (casino or home game) cash game session.

| Attribute | Type | Optional | Default | Description | Locked After Verification |
|-----------|------|----------|---------|-------------|--------------------------|
| `id` | UUID | Yes | — | Unique identifier | No |
| `startTime` | Date | Yes | — | Session start timestamp | **Yes** |
| `endTime` | Date | Yes | — | Session end timestamp; nil = session is active | **Yes** |
| `duration` | Double | Yes | 0.0 | Stored duration in hours (legacy); prefer `computedDuration` | No |
| `gameType` | String | Yes | — | e.g., "No Limit Hold'em" | No |
| `blinds` | String | Yes | — | Display string e.g., "$1/$2" | No |
| `smallBlind` | Double | Yes | 0.0 | Small blind in session currency | No |
| `bigBlind` | Double | Yes | 0.0 | Big blind in session currency | No |
| `straddle` | Double | Yes | 0.0 | Straddle amount | No |
| `ante` | Double | Yes | 0.0 | Ante amount | No |
| `breakTime` | Double | Yes | 0.0 | Break duration in minutes | No |
| `tableSize` | Int16 | Yes | 9 | Max players at the table | No |
| `location` | String | Yes | — | Legacy location name string (fallback when locationEntity is nil) | No |
| `currency` | String | Yes | — | Session currency code (e.g., "USD" for USD game) | No |
| `exchangeRateToBase` | Double | Yes | 0.0 | Single rate (legacy); prefer the dual rates below | No |
| `exchangeRateBuyIn` | Double | Yes | 0.0 | Exchange rate at buy-in time (session currency → base) | **Yes** |
| `exchangeRateCashOut` | Double | Yes | 0.0 | Exchange rate at cash-out time (session currency → base) | **Yes** |
| `buyIn` | Double | Yes | 0.0 | Buy-in amount in session currency | **Yes** |
| `cashOut` | Double | Yes | 0.0 | Cash-out amount in session currency | **Yes** |
| `tips` | Double | Yes | 0.0 | Tips paid (excluded from net result calculation) | No |
| `netProfitLoss` | Double | Yes | 0.0 | Net result in session currency (`cashOut − buyIn`) | No |
| `netProfitLossBase` | Double | Yes | 0.0 | Net result in base currency | No |
| `handsCount` | Int32 | Yes | 0 | Actual hands played (0 = use estimate) | No |
| `notes` | String | Yes | — | Free-form session notes | No |
| `isVerified` | Bool | Yes | false | Whether this session has been verified and locked | No (the flag itself) |

### Location

Represents a named live game venue. No GPS coordinates — name only.

| Attribute | Type | Optional | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | UUID | Yes | — | Unique identifier |
| `name` | String | Yes | — | Venue name (e.g., "Casino Niagara") |
| `createdAt` | Date | Yes | — | Creation timestamp |

### Deposit

Represents a deposit made to a platform. Permanent on save — cannot be deleted.

| Attribute | Type | Optional | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | UUID | Yes | — | Unique identifier |
| `date` | Date | Yes | — | Deposit date |
| `amountSent` | Double | Yes | 0.0 | Amount sent in **base currency** (what left the bank account) |
| `amountReceived` | Double | Yes | 0.0 | Amount received in **platform currency** (what arrived on the platform) |
| `isForeignExchange` | Bool | Yes | true | Whether this deposit involved a currency exchange |
| `effectiveExchangeRate` | Double | Yes | 0.0 | The exchange rate applied (platform currency per base currency unit) |
| `processingFee` | Double | Yes | 0.0 | Any processing fee charged |
| `method` | String | Yes | — | Payment method; editable after save |

### Withdrawal

Represents a withdrawal request from a platform. Permanent on save (record persists even in pending state).

| Attribute | Type | Optional | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | UUID | Yes | — | Unique identifier |
| `date` | Date | Yes | — | Date withdrawal was requested |
| `amountRequested` | Double | Yes | 0.0 | Amount requested in **platform currency** |
| `amountReceived` | Double | Yes | 0.0 | Amount received in **base currency** (set only when status = "received") |
| `isForeignExchange` | Bool | Yes | true | Whether this withdrawal involved a currency exchange |
| `effectiveExchangeRate` | Double | Yes | 0.0 | The exchange rate applied on receipt |
| `processingFee` | Double | Yes | 0.0 | Any processing fee |
| `method` | String | Yes | — | Withdrawal method; editable after save |
| `notes` | String | Yes | — | Optional notes |
| `withdrawalStatus` | String | Yes | — | State machine: `"pending"` or `"received"`. Nil treated as `"received"` for legacy records. |
| `receivedDate` | Date | Yes | — | Date the withdrawal was received (set when marking as received) |

### Adjustment

Represents a manual balance correction for a platform.

| Attribute | Type | Optional | Default | Description |
|-----------|------|----------|---------|-------------|
| `id` | UUID | Yes | — | Unique identifier |
| `name` | String | Yes | — | Short description (editable after save) |
| `amount` | Double | Yes | 0.0 | Amount in platform currency (signed: positive = credit, negative = debit) |
| `date` | Date | Yes | — | Adjustment date (locked after save) |
| `currency` | String | Yes | — | Always matches the linked platform's currency (auto-locked) |
| `exchangeRateToBase` | Double | Yes | 1.0 | Exchange rate to base currency at adjustment time |
| `amountBase` | Double | Yes | 0.0 | Amount expressed in base currency |
| `isOnline` | Bool | Yes | false | Whether this is an online platform adjustment |
| `location` | String | Yes | — | Optional location reference (for display only) |
| `notes` | String | Yes | — | Extended notes (editable after save) |

---

## Relationships

| Entity | Relationship | Destination | Cardinality | Inverse | Delete Rule |
|--------|-------------|-------------|-------------|---------|-------------|
| Platform | deposits | Deposit | to-many | platform | Cascade |
| Platform | withdrawals | Withdrawal | to-many | platform | Cascade |
| Platform | onlineSessions | OnlineCash | to-many | platform | Cascade |
| Platform | adjustments | Adjustment | to-many | platform | Cascade |
| Deposit | platform | Platform | to-one | deposits | Nullify |
| Withdrawal | platform | Platform | to-one | withdrawals | Nullify |
| OnlineCash | platform | Platform | to-one | onlineSessions | Nullify |
| Adjustment | platform | Platform | to-one | adjustments | Nullify |
| Location | sessions | LiveCash | to-many | locationEntity | Nullify |
| LiveCash | locationEntity | Location | to-one | sessions | Nullify |

**Note on Cascade:** Deleting a Platform cascades to delete all its deposits, withdrawals, online sessions, and adjustments. Platform deletion is blocked in the UI if any records exist.

**Note on Location deletion:** `PersistenceController.deleteLocation(_:context:)` manually nils out `locationEntity` on all attached `LiveCash` sessions before deleting the `Location`, preserving the legacy `location` String as a display fallback.

---

## Computed Properties

### Platform.currentBalance

```swift
// With anchor (most recent verified OnlineCash session):
balance = anchor.balanceAfter
        + Σ deposits.amountReceived      (date > anchor.endTime)
        - Σ withdrawals.amountRequested  (date > anchor.endTime, status: pending or received)
        + Σ adjustments.effectiveAmount  (date > anchor.endTime)

// Without anchor:
balance = Σ deposits.amountReceived
        - Σ withdrawals.amountRequested  (status: pending or received)
        + Σ adjustments.effectiveAmount
```

### Platform.netResult (Base Currency)

```swift
weightedAvgDepositRate = totalDepositsSentBase / totalDepositsReceivedPlatformCurrency

// For each withdrawal:
//   "received" status → amountReceived
//   FX withdrawal (pending) → amountRequested × effectiveExchangeRate
//   Non-FX withdrawal (pending) → amountRequested × weightedAvgDepositRate

netResult = withdrawalsContributionBase
          + (currentBalance × weightedAvgDepositRate)
          - totalDepositsSentBase
```

### Platform.netResultInPlatformCurrency

```swift
netResultInPlatformCurrency = totalWithdrawalsRequested + currentBalance - totalDepositsReceived
```

### OnlineCash.computedDuration

```swift
computedDuration = max(0, (endTime - startTime).hours - breakTime / 60)
```

### OnlineCash.effectiveHands

```swift
// Uses handsCount if > 0, otherwise estimates:
effectiveHands = computedDuration × handsPerHourOnline × max(1, tables)
```

### OnlineCash.bbWon / bbPer100

```swift
bbWon = netProfitLoss / bigBlind
bbPer100 = (bbWon / effectiveHands) × 100
```

### LiveCash.computedDuration

Same formula as OnlineCash, single-table only (no `tables` multiplier).

### LiveCash.netResult / netResultBase

```swift
netResult = cashOut - buyIn                   // in session currency, excludes tips

netResultBase:
  if exchangeRateBuyIn > 0 && exchangeRateCashOut > 0:
    = (cashOut × exchangeRateCashOut) - (buyIn × exchangeRateBuyIn)
  else:
    = netResult × exchangeRateToBase
```

### LiveCash.effectiveHands

```swift
effectiveHands = computedDuration × handsPerHourLive
```

---

## Model Version History

| Version | File | Changes |
|---------|------|---------|
| DataModel 2 | DataModel 2.xcdatamodel | Early schema — base entities |
| DataModel 3 | DataModel 3.xcdatamodel | Incremental schema changes |
| DataModel 4 | DataModel 4.xcdatamodel | Incremental schema changes |
| DataModel 5 | DataModel 5.xcdatamodel | Incremental schema changes |
| DataModel 6 | DataModel 6.xcdatamodel | Incremental schema changes |
| DataModel 7 | DataModel 7.xcdatamodel | Incremental schema changes |
| DataModel 8 | DataModel 8.xcdatamodel | **Current active version.** Includes `tables` on OnlineCash, `receivedDate` on Withdrawal, `withdrawalStatus` on Withdrawal, `exchangeRateBuyIn`/`exchangeRateCashOut` on LiveCash, `handsCount` on both session types, Location entity. |

**Process for schema changes:** Always use Xcode Editor → Add Model Version to create a new version. Never edit the active version directly. Lightweight migration handles all additive changes automatically.

---

## UserDefaults Keys (Complete Reference)

| Key | Type | Default | Purpose | In Settings UI |
|-----|------|---------|---------|---------------|
| `hasSeenTutorial` | Bool | false | Root routing gate — tutorial shown | No |
| `hasCompletedOnboarding` | Bool | false | Root routing gate — onboarding complete | No |
| `baseCurrency` | String | "CAD" | Base reporting currency (set once during onboarding) | No |
| `exchangeRateInputMode` | String | "direct" | "direct" = Mode A, "amounts" = Mode B | Yes |
| `handsPerHourOnline` | Int | 85 | Estimate for hands/hour in online sessions | Yes |
| `handsPerHourLive` | Int | 25 | Estimate for hands/hour in live sessions | Yes |
| `showAdjustmentsInStats` | Bool | true | Default toggle state for Include Adjustments | No |
| `defaultRateUSDToBase` | Double | 1.36 | Pre-filled exchange rate USD → base | Yes |
| `defaultRateEURToBase` | Double | 1.47 | Pre-filled exchange rate EUR → base | Yes |
| `defaultRateUSDToEUR` | Double | 0.92 | Pre-filled exchange rate USD → EUR | Yes |
| `didMigrateHandsCount_v1` | Bool | false | One-time migration guard | No |
| `chartXAxis` | String | "sessions" | Persisted chart X axis selection | No |
| `chartYAxis` | String | "netResult" | Persisted chart Y axis selection | No |
| `chartDateRange` | String | "allTime" | Persisted chart date range | No |
