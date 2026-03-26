# Veritas Business Rules Reference

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

## Platform Balance Rules

### Computed Formula

The platform balance is **never stored** — it is derived at read time. See `Platform.currentBalance` in `BusinessLogic.swift`.

**With anchor (most recent verified OnlineCash session by endTime):**
```
balance = anchor.balanceAfter
        + Σ deposits.amountReceived      where deposit.date > anchor.endTime
        − Σ withdrawals.amountRequested  where withdrawal.date > anchor.endTime
                                         AND status ∈ {"pending", "received"}
        + Σ adjustments.effectiveAmount  where adjustment.date > anchor.endTime
```

**Without anchor (no verified sessions exist for this platform):**
```
balance = Σ deposits.amountReceived
        − Σ withdrawals.amountRequested  (status ∈ {"pending", "received"})
        + Σ adjustments.effectiveAmount
```

### Anchor Selection Logic

- Anchor = the `OnlineCash` session for this platform where `isVerified == true` and `endTime` is the maximum (most recent) among all verified sessions.
- Only verified sessions are eligible as anchors. Unverified or active sessions are never anchors.
- The anchor's `balanceAfter` encapsulates all session profits, deposits, and withdrawals up to that moment.

### Post-Anchor Record Inclusion

- Strictly `>` (greater than), never `>=` (greater than or equal to).
- A deposit, withdrawal, or adjustment with the same timestamp as the anchor `endTime` is treated as pre-anchor and excluded from the sum — it is considered already captured in `anchor.balanceAfter`.

### What Affects Balance

| Event | Effect |
|-------|--------|
| Deposit saved | `+amountReceived` (platform currency) |
| Withdrawal created (pending) | `−amountRequested` (platform currency) |
| Withdrawal marked received | No additional change — `amountRequested` already deducted |
| Withdrawal failed / deleted | Balance restored (record no longer exists) |
| Adjustment saved | `+amount` if credit, `−amount` if debit (in platform currency) |
| Online session verified | Becomes new anchor if most recent; `balanceAfter` replaces entire prior history |

### What Never Affects Balance

- Session profits (live or online) do not directly affect the balance
- The balance is only updated by verified session `balanceAfter` values (as anchor), deposits, withdrawals, and adjustments

### Negative Balance Prevention

The UI enforces that a withdrawal cannot be created if `amountRequested > platform.currentBalance`. A defensive warning is also logged if the computed balance goes negative (which would indicate a logic error).

---

## Net Result Rules

### Per-Session Net Result

**Live session (session currency):**
```
netResult = cashOut − buyIn          (tips excluded from net result)
```

**Live session (base currency):**
```
If exchangeRateBuyIn > 0 AND exchangeRateCashOut > 0:
    netResultBase = (cashOut × exchangeRateCashOut) − (buyIn × exchangeRateBuyIn)
Else (legacy single rate):
    netResultBase = netResult × exchangeRateToBase
```

**Online session (platform currency):**
```
netProfitLoss = balanceAfter − balanceBefore
```

**Online session (base currency):**
```
netProfitLossBase = netProfitLoss × exchangeRateToBase
```

### Platform Net Result in Base Currency

Uses the weighted average deposit cost basis:

```
weightedAvgDepositRate = totalDepositsSentBase / totalDepositsReceivedPlatformCurrency

For each withdrawal:
  status == "received":
    → contribute amountReceived (already in base currency)
  status == "pending" AND isForeignExchange AND effectiveExchangeRate > 0:
    → contribute amountRequested × effectiveExchangeRate
  status == "pending" (no FX rate):
    → contribute amountRequested × weightedAvgDepositRate (estimated)

platformNetResult = Σ withdrawalContributions
                  + (currentBalance × weightedAvgDepositRate)
                  − totalDepositsSentBase
```

Same-currency platforms: `weightedAvgDepositRate = 1.0`.

### Platform Net Result in Platform Currency

```
netResultPlatformCurrency = totalWithdrawalsRequested + currentBalance − totalDepositsReceived
```

### Statistics Total Net Result

The `StatsView` total net result is session-based only:
```
statsNetResult = Σ session.netResultBase (filtered by date, type, platform, etc.)
               + adjustmentsTotal (only when includeAdjustments toggle is ON)
```

- Deposits and withdrawals are **never** included in statistics calculations
- Only completed sessions with `endTime != nil` appear in stats

---

## Verification Rules

### Fields Locked on Verification

**Live sessions:**
- `startTime`, `endTime`
- `buyIn`, `cashOut`
- `exchangeRateBuyIn`, `exchangeRateCashOut`, `exchangeRateToBase`

**Online sessions:**
- `startTime`, `endTime`
- `balanceBefore`, `balanceAfter`

### Fields Always Editable (Even After Verification)

Both session types:
- `gameType`, `blinds` (smallBlind, bigBlind, straddle, ante)
- `tableSize`
- `notes`
- `handsCount`
- `breakTime`

Live sessions additionally:
- `tips`
- `location` / `locationEntity`

### One-Unverified-at-a-Time Enforcement

Before creating any new session, the app checks for sessions matching `isVerified == NO AND endTime != nil`. If any exist:
1. The add action is blocked
2. An alert appears: "You have an unverified session"
3. Options: OK (dismiss) or "Go to Unverified Session" (navigates to it)

This constraint applies across both live and online session types combined.

### Verification Cannot Be Undone

There is no UI path to un-verify a session. Once `isVerified = true` is saved to Core Data, those fields are permanently locked.

### Verified Session as Balance Anchor

When an online session is verified, it immediately becomes eligible as the platform balance anchor. If its `endTime` is later than any previous anchor, it becomes the new anchor and all post-anchor balance computation restarts from its `balanceAfter`.

---

## Session Financial Rules

### Duration

```
computedDuration = max(0, (endTime − startTime) / 3600 − breakTime / 60)
```

Duration is always non-negative. A zero duration is possible but treated as valid.

### BB Calculations

```
bbWon = netProfitLoss / bigBlind           (platform currency for online; session currency for live)
bbPer100 = (bbWon / effectiveHands) × 100
```

`effectiveHands`:
- If `handsCount > 0`: use `handsCount`
- Else, for online: `computedDuration × handsPerHourOnline × max(1, tables)`
- Else, for live: `computedDuration × handsPerHourLive`

### Hourly Rate

```
hourlyRate = totalNetResult / totalHours
```

Computed in `StatsResult.hourlyRate`. Returns 0 if `totalHours == 0`.

---

## Exchange Rate Rules

### Mode A — Direct Rate

User enters the rate (e.g., 1.36 for USD→CAD). The app computes:
```
baseEquivalent = amount × rate
```

### Mode B — Amounts

User enters both the foreign amount and the base amount. The app computes:
```
rate = baseAmount / foreignAmount
```

### Live Foreign Sessions — Dual Rates

Two rates stored separately:
- `exchangeRateBuyIn`: rate at the time chips were purchased
- `exchangeRateCashOut`: rate at the time chips were cashed out

Net result in base:
```
netResultBase = (cashOut × exchangeRateCashOut) − (buyIn × exchangeRateBuyIn)
```

### Same-Currency Sessions

When session currency equals base currency, `exchangeRateBuyIn = exchangeRateCashOut = exchangeRateToBase = 1.0`. No exchange rate fields are shown in the UI.

### Online Sessions

Online sessions do not use per-session exchange rate fields for balance tracking. The platform balance is computed in platform currency; net result conversion to base uses `netProfitLoss × exchangeRateToBase`.

---

## Deposit Rules

- **Permanent on save** — deposit records cannot be deleted
- Only the `method` field is editable after saving
- `amountSent` = amount in **base currency** that left the user's account
- `amountReceived` = amount in **platform currency** that arrived on the platform
- `isForeignExchange` toggle: when ON, exchange rate fields appear; when OFF, same-currency logic applies
- **Same-currency deposit:** `effectiveExchangeRate = 1.0`, `amountReceived = amountSent − processingFee`
- After saving, the deposit contributes `+amountReceived` to the platform balance

---

## Withdrawal Rules

- **Permanent on save** — the record persists in all states (only failed = delete)
- Only the `method` field is editable after saving
- `amountRequested` = amount in **platform currency** the user wants to withdraw
- `amountReceived` = amount in **base currency** actually received (only set on receipt)
- `effectiveExchangeRate` = rate applied when funds were received

### State Transitions

| Action | State | Balance Effect |
|--------|-------|---------------|
| Create withdrawal | `pending` | `−amountRequested` from balance |
| Mark as received | `received` | No change (already deducted); sets `amountReceived` and `receivedDate` |
| Mark as failed | Deleted | `+amountRequested` restored (record no longer exists) |

### Net Result Contribution of Pending Withdrawals

In platform net result calculation, a pending withdrawal with no FX rate contributes an estimated base value using the weighted average deposit rate:
```
pendingContribution = amountRequested × weightedAvgDepositRate
```

---

## Adjustment Rules

- Always linked to a platform
- Currency is auto-set to the linked platform's currency and cannot be changed
- Affects platform balance immediately upon save: positive `amount` = credit, negative = debit
- `amount` and `date` are **locked** after save; `name` and `notes` are editable
- Affects `StatsView` total net result only when the "Include Adjustments" toggle is ON
- Never affects session-based stats (hourly rate, win rate, BB metrics)
- `amountBase = amount × exchangeRateToBase`

### Effective Amount for Balance

```swift
if adjustment.currency == platformCurrency:
    effectiveAmount = adjustment.amount
else:
    effectiveAmount = adjustment.amountBase
```

---

## Data Import / Export Rules

### Export

- Format: JSON
- `exportVersion = 1`
- Includes all entities: platforms, live sessions, online sessions, deposits, withdrawals, adjustments, locations
- The export encodes `currentBalance` for human readability only — it is not used on import (balance is recomputed)
- Export date is included in the file

### Import

- **Hard-blocked** if any data exists in any entity (platforms, sessions, deposits, withdrawals, adjustments, locations)
- User must perform a full data reset before importing
- Platforms are matched by `name` string — if a platform name in the file matches an existing one, it is linked
- All other records receive new UUIDs on import
- `exportVersion` field is checked; version mismatches may block or warn

### Full Reset

Deletes all records in all entities in this order: adjustments, withdrawals, deposits, online sessions, live sessions, locations, platforms.

---

## Balance Discrepancy Rules

When editing `balanceBefore` on an online session that has already been linked to a platform, if the entered value differs from `platform.currentBalance` by more than `0.01`:

### Trigger Condition
- `balanceBefore` field is edited (not `balanceAfter`)
- Difference > 0.01 between entered value and `platform.currentBalance`

### Resolution Options

| Option | Action |
|--------|--------|
| Add Deposit | Opens deposit form pre-filled with the discrepancy amount |
| Record Withdrawal | Opens withdrawal form pre-filled with the discrepancy amount |
| Log Adjustment | Opens adjustment form pre-filled with the discrepancy amount |
| Set Balance to X | Creates an auto-adjustment for the exact difference |
| OK | Dismiss alert; no action taken |

### "Set Balance to X"

Creates an `Adjustment` record with:
```
amount = enteredBalanceBefore − platform.currentBalance
name = "Balance Adjustment"
date = now
```
This brings the platform balance in line with what the user entered, without requiring them to trace the discrepancy source.
