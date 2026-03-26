# Changelog

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

> **Usage note:** CHANGELOG.md is updated **once per build**, not per coding session. When preparing a new build, add a single versioned entry summarizing everything that changed since the last build. Do not update this file mid-session — save it for build time.

---

## [Unreleased] — Current Build

### Core Features Implemented

The following features are confirmed present in the codebase:

**Onboarding & Tutorial**
- Tutorial carousel (6 slides): Welcome, Two States, Why Verification Matters, Exchange Rates, Platform Balance, You're Ready
- Onboarding flow (4 steps): Welcome, Base Currency selection, Exchange Rate mode selection, Platform selection
- Tutorial replayable from Settings

**Session Tracking**
- Live cash session entry: game type, blinds, table size, location, currency, exchange rates (Mode A or B), buy-in, cash-out, tips, notes, break time
- Online cash session entry: platform, game type, blinds, table size, tables count, balance before/after, exchange rate, notes, break time
- Active session floating bar (60pt, above tab bar) with live elapsed timer
- Cross-tab active session navigation via `ActiveSessionCoordinator`
- Session list grouped by month (gold headers), with gold border for verified sessions
- Pull-to-refresh on all scrollable screens
- Suggested blind levels from session history (`SuggestedBlindsHelper`)

**Session Verification System**
- Permanent field locking on verification: startTime, endTime, buyIn/cashOut (live), balanceBefore/balanceAfter (online)
- One-unverified-at-a-time enforcement with alert and navigation option
- Verified badge (gold) on session detail; gold lock icon on locked fields with glow
- Verification cannot be undone

**Platform Management**
- Platform list with computed balance and net result
- Platform detail: balance card, action buttons (Deposit/Withdraw/Adjust/Analytics), sessions, deposits, withdrawals, adjustments sections
- Add platform (from list or onboarding)
- Platform deletion blocked if any records exist
- Online platform statistics: platform-level statistics derived from associated sessions

**Deposits**
- Deposit creation with FX toggle, Mode A/B exchange rate entry
- Deposits are permanent (cannot be deleted)
- Only `method` field editable after save

**Withdrawals**
- Two-stage withdrawal system: pending → received
- Failed withdrawal = silent delete, balance restored
- Mark as received with `amountReceived` and `receivedDate`
- Status badge (pending: orange, received: green)

**Adjustments**
- Platform-linked adjustments with signed amounts
- Affects platform balance immediately
- Affects Statistics net result only when "Include Adjustments" toggle ON
- Adjustments list and detail screens

**Locations**
- Location entity (name only, no GPS)
- Location picker sheet for live session entry
- Location detail with session history and aggregate stats
- Location deletion (sessions retain legacy string fallback)

**Statistics Screen**
- Net result header (44pt bold) with Include Adjustments toggle
- Performance grid: Hourly Rate, Avg Net Result, Net Result BB, BB/Hour, BB/100
- Volume grid: Sessions, Hours, Hands, Avg Session, Avg Buy-In, Total Tips
- Results grid: Win Rate, Winning/Losing sessions, Biggest Win/Loss, Longest Session, Win/Lose Streaks
- Platform Breakdown with per-platform net result and Analytics shortcut
- Two floating action buttons (Charts, Calendar) that shift above floating session bar

**Filtering**
- Full filter sheet (accordion) with 8 sections: Date Range, Session Type, Location, Platform, Game Type, Blind Level, Result, Verification
- Filter active count badge on toolbar button
- FilterState persisted per screen instance (Sessions and Stats have independent filter states)
- Charts have separate persisted filter state (ChartFilterState → UserDefaults)

**Online Platform Analytics**
- BB/100, $/100, BB/Hour, $/Hour summary cards
- BB ↔ $ view toggle
- Per-session breakdown table

**Charts Screen**
- Swift Charts integration
- X/Y axis selection (Sessions/Date; Net Result/Hourly Rate/BB/100)
- Fullscreen mode
- Date range filter

**Calendar Screen**
- Monthly heatmap showing daily net result
- Smart number formatting (3 significant digits, k/m suffix, no trailing zeros)
- Month navigation

**Data Export/Import**
- JSON export (exportVersion: 1) with all entities
- JSON import hard-blocked if any data exists
- Full data reset before import
- Export includes: platforms, live sessions, online sessions, deposits, withdrawals, adjustments, locations

**Settings**
- Base currency display (permanent, set in onboarding)
- Exchange rate input mode (Mode A / Mode B)
- Hands per hour settings (online: 85 default, live: 25 default)
- Default exchange rate pre-fills (USD→base, EUR→base, USD→EUR)
- Export / Import / Reset All Data

**UI & Design**
- Dark mode only (#000000 background, #0D0D0D surface)
- Gold accent (#C9B47A) throughout
- Smart bottom padding (`smartBottomPadding()`) on all screens
- Veritas logo (spiral truth symbol in gold)
- SF Pro typography with inline navigation bar titles
- Verified session gold border (opacity 0.45) on session list rows

**Architecture**
- MVVM with Core Data
- `ActiveSessionCoordinator` for cross-tab navigation
- `FilterState` (ObservableObject) for filter state management
- `ChartFilterState` with UserDefaults persistence
- One-time `handsCount` backfill migration at startup
- Lightweight Core Data migration enabled (7 model versions)
- Zero third-party dependencies

### Known Issues / In Progress

- `currentBalance` attribute exists in Core Data schema (DataModel 8) but is never read or written — it is a legacy attribute superseded by the computed property. No migration needed to remove it; it is simply ignored.
- Diagnostic `print` statements remain in `Platform.currentBalance` for debugging balance computation. These should be removed before App Store submission.
- No automated test targets are configured in the project.

---

## Future Roadmap

- Hand history logging with AI text parser
- Player tracking feature
- Tournament session tracking
- iCloud backup / CloudKit sync
- Apple Watch companion app
- Home screen widget
- Maestro automated UI test suite
- App Store submission
