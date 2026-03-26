# Veritas: Poker Bankroll Tracker

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

**Tagline:** *Precision Truth in Every Session*
**App Store Category:** Utilities
**Target User:** Serious poker players (live and online) who demand 100% accurate profit tracking
**Core Value Proposition:** Real exchange rates, permanent verification locks, and computed platform balances — not approximations.

---

## Overview

Veritas is a premium iOS poker bankroll tracker built around a single obsession: financial truth. Unlike apps that let you freely edit session results, Veritas introduces a verification system that permanently locks financial fields once a session is confirmed. Combined with real exchange rates recorded at buy-in and cash-out separately, and a platform balance that is computed from verified session anchors rather than stored, Veritas gives players a mathematically exact record of every dollar earned or lost.

---

## Core Differentiators

### Verification System
When a session ends, it is unverified by default. The player reviews all financial details and taps Verify. At that moment, `startTime`, `endTime`, `buyIn`, `cashOut`, `balanceBefore`, and `balanceAfter` are permanently locked — no edits ever. The record is sealed. Only one unverified session is permitted at a time, enforcing honest record-keeping.

### Real Exchange Rates
For live foreign currency sessions (e.g., USD game tracked in CAD), Veritas records the actual exchange rate at buy-in and again at cash-out separately. Net result in base currency is `(cashOut × cashOutRate) − (buyIn × buyInRate)`, not an approximation using today's market rate.

### Computed Platform Balance
The platform balance is **never stored**. It is derived at read time from the most recent verified session's `balanceAfter` (the anchor), plus post-anchor deposits, minus post-anchor withdrawals, plus post-anchor adjustments. This prevents any manual corruption of the balance figure and eliminates the platform-switch bug class entirely.

### Two-Stage Withdrawal System
Withdrawals have two states: `pending` (requested but not yet received) and `received` (cash in hand). Both states deduct from the platform balance using `amountRequested`. On receipt, `amountReceived` is recorded in base currency. A failed withdrawal is silently deleted, restoring balance.

### Weighted Average Deposit Net Result
Platform net result in base currency is calculated using the weighted average exchange rate across all deposits, not just the most recent rate. This gives the true cost-basis return on every dollar invested in the platform.

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Data Layer | Core Data (NSPersistentContainer, local only, no CloudKit) |
| Charts | Swift Charts |
| Architecture | MVVM + Combine |
| Minimum iOS | 16.0 |
| Location | Name-only (no CoreLocation, no GPS) |
| Dependencies | None — zero third-party libraries |

---

## Project Structure

```
project-integrity/
├── App.swift                          Entry point, RootView state machine, handsCount migration
├── ContentView.swift                  Legacy preview stub
├── Persistence.swift                  Core Data stack (NSPersistentContainer + lightweight migration)
├── DataModel.xcdatamodeld/            Core Data model — current version: DataModel 8
│   ├── DataModel 2.xcdatamodel/
│   ├── DataModel 3.xcdatamodel/
│   ├── DataModel 4.xcdatamodel/
│   ├── DataModel 5.xcdatamodel/
│   ├── DataModel 6.xcdatamodel/
│   ├── DataModel 7.xcdatamodel/
│   └── DataModel 8.xcdatamodel/       Active model version
├── Models/
│   ├── CoreDataModels.swift           NSManagedObject subclasses for all 7 entities
│   ├── BusinessLogic.swift            Computed properties, platform balance, stats computation
│   ├── FilterState.swift              ObservableObject for session and stats filtering
│   └── ChartFilterState.swift         ObservableObject for chart-specific filtering (persisted)
├── Utils/
│   ├── AppColors.swift                Color palette, hex initializer, smartBottomPadding function
│   ├── Formatters.swift               Currency, date, BB, duration, percentage formatters
│   ├── UserSettings.swift             UserDefaults singleton, platform templates, game type lists
│   ├── CurrencyInputField.swift       Reusable decimal input field enforcing 2dp max
│   └── SuggestedBlindsHelper.swift    Blind level suggestions from session history
└── Views/
    ├── MainTabView.swift              4-tab root shell + FloatingSessionBar injection
    ├── MoreView.swift                 Secondary navigation: Locations, Charts, Calendar, Adjustments, Settings
    ├── Sessions/                      Session list, live/online entry, detail, and verification views
    ├── Platforms/                     Platform list, detail, deposit/withdrawal forms, analytics
    ├── Stats/                         Statistics dashboard with performance, volume, results grids
    ├── Charts/                        Swift Charts visualization with fullscreen mode
    ├── Calendar/                      Monthly heatmap calendar with smart number formatting
    ├── Adjustments/                   Adjustment list, add, and detail views
    ├── Locations/                     Location management (name only, no GPS)
    ├── Filter/                        Advanced filter sheet (accordion, multi-section)
    ├── Settings/                      App preferences + JSON export/import
    └── Onboarding/                    Tutorial carousel (6 slides) + onboarding flow (4 steps)
```

---

## Setup Instructions

1. Clone the repository
2. Open `project-integrity.xcodeproj` in Xcode 15+
3. Select your development team under **Signing & Capabilities**
4. Personal Apple Developer account: `shawnzhou07@gmail.com` (independent distribution)
5. Build and run on an iOS 16+ simulator or physical device
6. No API keys, no environment variables, no external services required — 100% local

---

## App Store Metadata

| Field | Value |
|-------|-------|
| Name | Veritas: Poker Bankroll Tracker |
| Name length | 30 characters |
| Subtitle | Track Your Real Poker Profits |
| Subtitle length | 30 characters |
| Category | Utilities |
| Bundle ID | `com.shawnzhou.projectintegrity` |
| Keywords | poker, bankroll, tracker, cash game, sessions, live poker, online poker, poker stats, poker results, hand tracker |

---

## Build Notes

- **Core Data model versioning:** Current active model is `DataModel 8.xcdatamodel`
- **Schema changes:** Always create a new `.xcdatamodel` version using Xcode's Editor → Add Model Version. Never edit the current version directly.
- **Lightweight migration:** Enabled in `Persistence.swift` via `shouldMigrateStoreAutomatically = true` and `shouldInferMappingModelAutomatically = true`
- **Build commands:** Build via Xcode only — no npm/CLI build pipeline
- **No test targets** are currently configured in the project

---

## Documentation Maintenance

These documentation files must be kept current with the codebase at all times:

| File | Update When |
|------|-------------|
| UI_MASTER.md | Any UI component, color, spacing, typography, or interaction pattern changes |
| ARCHITECTURE.md | Navigation structure changes, new patterns introduced, Core Data stack changes, new notification names |
| SCREENS.md | New screens added, existing screen functionality changes, new actions or business rules on any screen |
| DATA_MODEL.md | Any Core Data entity changes (new attributes, removed attributes, new relationships), new UserDefaults keys, new computed properties, new model versions |
| BUSINESS_RULES.md | Any changes to financial formulas, verification rules, balance calculation logic, deposit/withdrawal/adjustment rules, import/export rules |
| CHANGELOG.md | Once per build/release only — summarize all changes since last build in a single versioned entry |
| GENERATE_ICONS.md | Any changes to app icon specifications or generation process |

### Changelog Format
CHANGELOG.md is updated once per build, not per coding session. When preparing a new build, add a single versioned entry summarizing everything that changed since the last build:

```
## [X.X.X] — YYYY-MM-DD
### Added
- New features or screens

### Changed
- Modified existing behavior

### Fixed
- Bug fixes

### Data Model
- Core Data changes requiring migration
```

All other .md files (UI_MASTER, ARCHITECTURE, SCREENS, DATA_MODEL, BUSINESS_RULES) should be updated during the coding session when the relevant change is made — not batched to release time.
