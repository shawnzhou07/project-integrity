# Veritas Screens Reference

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

## Tutorial Carousel

**File:** `Views/Onboarding/TutorialView.swift`
**Entry Points:** First app launch (RootView routes here when `hasSeenTutorial == false`); Settings → Replay Tutorial (presented as sheet with `isFromSettings: true`)
**Navigation away:** Skip button (any slide) or "Get Started" button (last slide) → sets `hasSeenTutorial = true` → RootView transitions to OnboardingView. When `isFromSettings: true`, calls `dismiss()` instead.

### Slides

| # | Title | Key Message |
|---|-------|------------|
| 1 | Welcome to Veritas | App name, tagline, "not just another tracker" — introduces the honest tracking premise |
| 2 | Two States. One Truth. | Explains unverified vs verified states with visual lock icon |
| 3 | Your Numbers. Locked. | Why verification matters — no editing after the fact |
| 4 | Real Exchange Rates. Real Profits. | Dual buy-in/cash-out rates; USD game tracked in CAD example |
| 5 | Your Online Bankroll. Perfectly Tracked. | Platform deposits, withdrawals, and FX-aware profit |
| 6 | You're Ready. | 3-step next steps; "Get Started" button |

**Controls:** Skip (hidden on last slide) | Dot indicators (gold = current) | Next → or Get Started

---

## Onboarding Flow

**File:** `Views/Onboarding/OnboardingView.swift`
**Entry Points:** RootView routes here when `hasSeenTutorial == true AND hasCompletedOnboarding == false`
**Navigation away:** Completing step 3 sets `hasCompletedOnboarding = true` → RootView transitions to MainTabView

### Step 0: Welcome
- Veritas logo, app name, subtitle, tagline, gold divider
- Single button: "Get Started" → advances to step 1

### Step 1: Base Currency (1 of 3)
- Header: "Base Currency" — "This setting is permanent. Choose carefully."
- Options: CAD 🇨🇦, USD 🇺🇸, EUR 🇪🇺 (selection cards with checkmark)
- Warning text in red: "This setting is permanent. Choose carefully."
- Continue → saves `baseCurrency` to UserDefaults, advances to step 2

### Step 2: Exchange Rate Input (2 of 3)
- Header: "Exchange Rate Input"
- Two mode cards:
  - **Enter Rate Directly** (Mode A): type rate → app calculates base equivalent
  - **Enter Amounts** (Mode B): type both amounts → app calculates rate
- Footer: "This can be changed later in Settings"
- Continue → saves `exchangeRateInputMode` to UserDefaults, advances to step 3

### Step 3: Select Platforms (3 of 3)
- Header: "Your Platforms" — multi-select
- Predefined options: PokerStars Ontario (CAD), GGPoker Ontario (CAD), ClubWPT Gold (USD), PokerStars (USD), GGPoker (USD)
- FX badge shown for platforms whose currency ≠ selected base currency
- Zero selection is allowed (user can add platforms later)
- "Start Tracking" → creates selected platforms in Core Data, sets `hasCompletedOnboarding = true`

**Business rules:** Base currency cannot be changed after onboarding. Platform templates can be skipped — platforms are always addable later.

---

## Sessions List

**File:** `Views/Sessions/SessionsListView.swift`
**Entry Point:** Tab 0 (Sessions)
**Data displayed:** All OnlineCash and LiveCash sessions grouped by month (descending). Each row shows: icon (desktopcomputer for online, building.columns for live), date, platform/location, game type + blinds, duration, net result in base currency.

### Actions
- **+** menu → "Cash Game" → triggers new session flow (blocked if active or unverified session exists)
- Filter button (toolbar) → opens `FilterSheetView` as sheet
- Pull to refresh → `viewContext.refreshAllObjects()`
- Tap row → push to `OnlineSessionDetailView` or `LiveSessionDetailView`

### Session Row Visual States
| State | Indicator |
|-------|----------|
| Active | Green filled circle (10pt) top-left of session icon; elapsed timer shown |
| Unverified (completed) | Gray `questionmark.circle.fill` beside title |
| Verified | 3pt gold (#C9B47A) left stripe on card |

Session rows use the shared `SessionRowView` component (`showDate: true`). Any visual changes to session rows must be made in `SessionRowView` only — never in the list view directly.

### Alerts
- **Active Session:** "You have an active session in progress." — OK only
- **Unverified Session:** "You have an unverified session." — OK or "Go to Unverified Session"

### Empty State
Spade icon at 48pt (gray), "No Sessions Yet", "Tap + to record your first session"

### Business Rules
- Sessions are grouped by month-year heading (gold section header)
- Filter state is independent per instance of SessionsListView (StateObject)
- Net result displayed in base currency regardless of session currency
- Active sessions show a live-updating timer

---

## Live Session Entry (New Session)

**Files:** `Views/Sessions/AddSessionView.swift`, `Views/Sessions/CashGameTypePickerView.swift`, `Views/Sessions/LiveSessionFormView.swift`, `Views/Sessions/SessionEntryContainerView.swift`
**Entry Point:** Sessions + button → Cash Game → type picker → Live → LiveSessionFormView
**Presented as:** Full-screen cover via `sessionCoordinator.isFormPresented`

### Fields
- Game type picker (No Limit Hold'em, PLO, etc.)
- Blind levels (SB/BB/straddle/ante)
- Table size
- Location (from Location entity list)
- Currency (CAD, USD, EUR)
- Exchange rate fields (if currency ≠ base currency, based on selected mode)
- Start time (defaults to now; editable)
- Buy-in amount
- Notes

### Actions
- Cancel → dismisses without saving
- Start Session → creates LiveCash record with `endTime = nil`, dismisses cover, floating session bar appears

---

## Live Session Entry View (Active Session)

**File:** `Views/Sessions/LiveSessionEntryView.swift`
**Entry Point:** Floating session bar tap → detail for active live session
**Purpose:** View and update an in-progress live session

### Fields shown while active
- Elapsed timer (live updating)
- Current buy-in, location, blinds
- Break time entry
- Notes

### Actions
- Cash Out → sets `endTime`, records `cashOut`, computes net result, saves
- Add Re-buy → increases buy-in amount
- Discard Session → deletes the session record entirely

---

## Live Session Detail

**File:** `Views/Sessions/LiveSessionDetailView.swift`
**Entry Points:** Session list row tap; floating bar tap for completed sessions; unverified session alert navigation
**Purpose:** View, edit, and verify a completed live session

### Editable Fields (always)
- Location, game type, blinds, table size, break time, notes, hands override, tips

### Editable Fields (only when unverified)
- Start time, end time, buy-in, cash-out
- Exchange rate fields (buy-in rate, cash-out rate; or Mode B amounts)

### Locked Fields (after verification)
- Start time, end time, buy-in, cash-out, exchange rates — shown with gold lock icon and glow

### Actions
- Save changes → `viewContext.save()`
- Verify → confirmation alert → sets `isVerified = true`, saves
- Delete → confirmation alert → deletes session record

### Verification Alert
"Are you sure? This will permanently lock the financial details of this session."
Buttons: Cancel | Verify

### Business Rules
- Duration displayed excludes break time
- Net result displayed in both session currency and base currency
- Exchange rate fields shown only when currency ≠ base currency
- If session is active (endTime == nil), shows active entry UI instead of detail

---

## Online Session Entry (New Session)

**File:** `Views/Sessions/OnlineSessionFormView.swift`
**Entry Point:** Sessions + → Cash Game → type picker → Online → platform picker → OnlineSessionFormView
**Presented as:** Full-screen cover

### Fields
- Platform selection (required)
- Game type
- Blind levels (SB/BB/straddle/ante)
- Table size, number of tables
- Balance before (pre-filled with `platform.currentBalance`)
- Exchange rate to base (if platform currency ≠ base currency)
- Notes

### Balance Discrepancy Check
If entered `balanceBefore` differs from `platform.currentBalance` by > 0.01, an alert fires with resolution options (Add Deposit, Record Withdrawal, Log Adjustment, Set Balance to X, OK).

### Actions
- Cancel → dismisses
- Start Session → creates OnlineCash with `endTime = nil`, floating bar appears

---

## Online Session Entry View (Active Session)

**File:** `Views/Sessions/OnlineSessionEntryView.swift`
**Entry Point:** Floating session bar tap for active online session
**Purpose:** View an in-progress online session

---

## Online Session Detail

**File:** `Views/Sessions/OnlineSessionDetailView.swift`
**Entry Points:** Session list row tap; floating bar navigation
**Purpose:** View, edit, and verify a completed online session

### Editable Fields (always)
- Game type, blinds, table size, tables count, break time, notes, hands override

### Editable Fields (only when unverified)
- Start time, end time, balance before, balance after

### Locked Fields (after verification)
- Start time, end time, balance before, balance after — shown with gold lock icon and glow

### Actions
- Save, Verify (with confirmation alert), Delete

### Business Rules
- `netProfitLoss = balanceAfter − balanceBefore` (shown in platform currency)
- `netProfitLossBase = netProfitLoss × exchangeRateToBase` (shown in base currency)
- Verified online sessions become balance anchors for their platform

---

## Floating Session Bar

**File:** `Views/Sessions/FloatingSessionBar.swift`
**Entry Point:** Always visible above the tab bar when any session has `startTime != nil AND endTime == nil`
**Purpose:** Persistent indicator of active session; quick navigation

### Display
- Shows session type icon, platform/location name, game type, elapsed time
- 60pt height, 8pt gap above tab bar
- Disappears when no active session

### Actions
- Tap → navigates to the active session's detail view via `ActiveSessionCoordinator`

---

## Statistics Screen

**File:** `Views/Stats/StatsView.swift`
**Entry Point:** Tab 1 (Stats)

### Data Displayed
- **Net Result header:** 44pt bold, profit color, with "Include Adjustments" toggle
- **Performance section:** Hourly Rate, Avg Net Result, Net Result (BB), BB/Hour, BB/100 Hands
- **Volume section:** Sessions count, Hours Played, Hands Played, Avg Session duration, Avg Buy-In, Total Tips
- **Results section:** Win Rate, Winning Sessions, Losing Sessions, Biggest Win, Biggest Loss, Longest Session, Win Streak, Lose Streak
- **Platform Breakdown:** Each platform row shows name and net result; row tap → platform detail

### Actions
- Filter button (toolbar) → `FilterSheetView` sheet
- Charts FAB (bottom trailing) → `ChartsView` push
- Calendar FAB (below Charts FAB) → `CalendarView` push
- Platform row tap → `PlatformDetailView` push
- Pull to refresh

### Business Rules
- Adjustments included only when toggle is ON
- Filters apply to sessions only (not to platform breakdown)
- FAB positions shift up when floating session bar is active
- Bottom padding uses `smartBottomPadding(isSessionActive:, isStatisticsScreen: true)`

---

## Analytics Screen

**File:** `Views/Platforms/OnlinePlatformAnalyticsView.swift` (struct: `AnalyticsView`)
**Entry Point:** Tab 2 (Analytics) only. Last-used source (Live vs platform) is restored from UserDefaults key `analyticsSelectedSource`.

### Source Selector
Horizontally scrollable pill row always visible at top, below nav bar:
- **Live pill** — always first, `font size 15 semibold`, gold background when selected; white text on `#1A1A1A` when unselected. Visually primary.
- **Platform pills** — one per Platform in Core Data, sorted by most recently played session. `font size 13 medium`, gold background when selected; `#8A8A8A` text on `#1A1A1A` when unselected.
- Exactly one source always selected. Last-used persisted to UserDefaults key `analyticsSelectedSource` (`"live"` or platform UUID string).

### Data Displayed
- 3 summary stat cards: Sessions, Hours, Hands
- BB/$ toggle (matched geometry animation)
- Performance card: primary metric (BB/100 or $/100) + hourly metric (BB/HOUR or $/HOUR), left gold stripe
- Axis selector tabs (horizontally scrollable, per-source axes)
- Breakdown table: axis column + BB/100 or $/100 + BB/HR or $/HR + TIME

### Per-Source Axes
| Source | Available Axes |
|--------|---------------|
| Live | Stakes, Location, Time of Day, Day of Week, Session Duration |
| Platform | Stakes, Time of Day, Day of Week, Session Duration, Tables Played |

### Per-Source Secondary Filters
| Source | Filter Options |
|--------|---------------|
| Live | Date Range, Stakes, Location, Time of Day, Day of Week, Session Duration |
| Platform | Date Range, Stakes, Time of Day, Day of Week, Session Duration, Tables Played |

Secondary filters reset to neutral when switching between Live and platforms or when leaving and re-entering the Analytics tab; they are not persisted across app restarts. The toolbar filter badge counts only filters applicable to the current source.

### Live BB Metrics
BB/100 and BB/HOUR are only shown when filtered sessions have `handsCount > 0`. Otherwise shows `—` with caption "Log hands to see BB metrics". $/HOUR is always available.

### Metrics Format
| Card | Format |
|------|--------|
| BB/100 | `35.7 BB` |
| $/100 | `12.50 CAD` |
| BB/Hour | `83.1 BB` |
| $/Hour | `45.00 CAD` |

---

## Charts Screen

**File:** `Views/Charts/ChartsView.swift`
**Entry Points:** Stats screen Charts FAB; More tab → Charts

### Features
- Swift Charts line/bar charts for net result over time
- X-axis options: Sessions, Date
- Y-axis options: Net Result, Hourly Rate, BB/100
- Date range filter (persisted via `ChartFilterState` to UserDefaults)
- Fullscreen mode (chart expands to fill screen)
- Filter integration with `FilterState`

### Actions
- Filter button → filter sheet
- Fullscreen toggle → chart expands
- Pull to refresh

---

## Calendar Screen

**File:** `Views/Calendar/CalendarView.swift`
**Entry Points:** Stats screen Calendar FAB; More tab → Calendar

### Features
- Monthly calendar heatmap showing net result per day
- Smart number formatting: max 3 significant digits with k/m suffix, trailing zeros stripped
- Tap day → session list for that day (day detail sheet)
- Swipe left/right to navigate months

### Calendar Day Detail Sheet
Session rows use the shared `SessionRowView` component (`showDate: false`). The date column is hidden since the date context is already provided by the tapped calendar day. Session appearance is always identical to the Sessions List screen.

---

## Shared Components

### SessionRowView
**File:** `Views/Sessions/SessionsListView.swift`
**Used in:** `SessionsListView`, `CalendarView` (day detail sheet)

Single source of truth for session row appearance. Any visual change to how a session row looks must be made here — never duplicated in individual screens.

| Parameter | Type | Purpose |
|-----------|------|---------|
| `showDate` | `Bool` | When `true`: renders a 44pt left date column (month abbr + day number). When `false`: card occupies full width. |
| `isVerified` | `Bool` | When `true`: shows 3pt gold left stripe on card edge. |
| `isUnverified` | `Bool` | When `true`: shows `questionmark.circle.fill` beside title. |

**Layout:** Card background #0D0D0D, corner radius 12, ~64pt height. Platform/location name (white 15pt semibold), game type + stakes (gray 13pt), net result (green/red 15pt semibold right-aligned), duration (gray 12pt right-aligned). Card padding 12pt horizontal, 10pt vertical.

---

## Platforms List

**File:** `Views/Platforms/PlatformsListView.swift`
**Entry Point:** Tab 3 (Platforms)

### Data Displayed
- Each platform row: name, net result (base currency), current balance (platform currency)
- Foreign platforms: net result (primary white) + balance (secondary gray)

### Actions
- + button → `AddPlatformView` sheet
- Tap row → `PlatformDetailView` push
- Pull to refresh

### Business Rules
- Balance displayed is computed (never stored)
- Cannot delete platform with existing records

---

## Platform Detail

**File:** `Views/Platforms/PlatformDetailView.swift`
**Entry Point:** Platforms list tap

### Sections
1. **Balance card:** Current balance (large), platform currency, net result in base currency
2. **Action buttons:** Deposit (red), Withdraw (green), Adjust (gold)
3. **Sessions section:** List of online sessions for this platform (NavigationLink to detail)
4. **Deposits section:** All deposits with date, amount sent, amount received, method
5. **Withdrawals section:** All withdrawals with status badge (pending/received), amounts, method
6. **Adjustments section:** All adjustments with name, amount, date
7. **Danger Zone:** Delete Platform button (blocked if any records exist)

### Actions
- Deposit → `DepositFormView` sheet
- Withdraw → `WithdrawalFormView` sheet
- Adjust → `AddAdjustmentView` sheet
- Withdrawal row tap → options sheet (Mark Received / Mark Failed)
- Delete Platform → confirmation alert (blocked if records exist)

### Business Rules
- Platform deletion blocked if deposits, withdrawals, sessions, or adjustments exist
- Pull to refresh

---

## Add Deposit Sheet

**File:** `Views/Platforms/DepositFormView.swift`
**Entry Point:** Platform Detail → Deposit button

### Fields
- Date (default: now)
- Amount Sent (base currency)
- FX toggle: when ON → exchange rate fields appear; when OFF → same-currency
- Amount Received (platform currency; auto-calculated from rate in Mode A)
- Exchange rate (or amounts for Mode B)
- Processing fee
- Method (picker: E-Transfer, Debit Card, Credit Card, Crypto, Wire Transfer, Other)
- Notes

### Actions
- Cancel → dismiss
- Save → creates Deposit record, saves context, dismisses

### Business Rules
- Same-currency: `amountReceived = amountSent − processingFee`, rate = 1.0
- Deposits are permanent — cannot be deleted after save
- Only `method` is editable after save

---

## Add Withdrawal Sheet

**File:** `Views/Platforms/WithdrawalFormView.swift`
**Entry Point:** Platform Detail → Withdraw button

### Fields
- Date (default: now)
- Amount Requested (platform currency)
- FX toggle (same pattern as deposit)
- Method
- Notes

### Actions
- Cancel → dismiss
- Save → creates Withdrawal with status `"pending"`, deducts from balance, dismisses

### Business Rules
- Cannot create if `amountRequested > platform.currentBalance`
- Status starts as `"pending"` always
- Permanent record — only deleted on "failed" action

---

## Mark Withdrawal Received Sheet

**Entry Point:** Platform Detail → Withdrawal row → "Mark as Received"
**Purpose:** Transitions withdrawal from pending to received state

### Fields
- Amount Received (base currency)
- Received Date
- Exchange rate (if FX)

### Actions
- Confirm → sets `withdrawalStatus = "received"`, records `amountReceived`, `receivedDate`, saves
- Mark Failed → deletes the withdrawal record entirely
- Cancel → dismiss

---

## Add Adjustment Sheet

**File:** `Views/Adjustments/AddAdjustmentView.swift`
**Entry Points:** Platform Detail → Adjust button; More → Adjustments → +; direct trigger from `ActiveSessionCoordinator`

### Fields
- Platform (required — pre-selected if opened from platform detail)
- Name / description
- Amount (signed — positive = credit, negative = debit)
- Date
- Notes

### Business Rules
- Currency auto-set to platform currency; cannot be changed
- Amount and date locked after save
- Name and notes editable after save
- Affects platform balance immediately

---

## Adjustments List

**File:** `Views/Adjustments/AdjustmentsListView.swift`
**Entry Point:** More → Adjustments

### Data Displayed
- All adjustments across all platforms, sorted by date descending
- Each row: name, platform, amount (in platform currency), date

### Actions
- + button → `AddAdjustmentView` sheet
- Tap row → `AdjustmentDetailView` push

---

## Adjustment Detail

**File:** `Views/Adjustments/AdjustmentDetailView.swift`
**Entry Point:** Adjustments list tap

### Data Displayed
- Name (editable), platform name, amount (locked), date (locked), currency, notes (editable)

### Actions
- Save name/notes changes
- No delete option (adjustments are permanent)

---

## Locations List

**File:** `Views/Locations/LocationsListView.swift`
**Entry Point:** More → Locations

### Data Displayed
- All saved locations sorted alphabetically
- Each row: location name, session count

### Actions
- + button → `AddLocationSheet` sheet
- Tap row → `LocationDetailView` push

---

## Location Detail

**File:** `Views/Locations/LocationDetailView.swift`
**Entry Point:** Locations list tap

### Data Displayed
- Location name (editable)
- Session history for this location
- Total sessions, total hours, net result at this location

### Actions
- Edit name → saves on dismiss
- Tap session → `LiveSessionDetailView` push
- Delete Location → deletes record; live sessions retain legacy `location` String

---

## Add Location Sheet

**File:** `Views/Locations/AddLocationSheet.swift`
**Entry Point:** Locations list +

### Fields
- Name (text field)

### Actions
- Save → creates Location record
- Cancel → dismiss

---

## Location Picker Sheet

**File:** `Views/Locations/LocationPickerSheet.swift`
**Entry Point:** Live session entry/detail → Location field tap

### Purpose
Select an existing location or type a new one. Returns selected location entity to the calling view.

---

## Settings Screen

**File:** `Views/Settings/SettingsView.swift`
**Entry Point:** More → Settings

### Sections

**General**
- Base Currency: Display only (set during onboarding, permanent)
- Exchange Rate Input: Mode A (Enter Rate Directly) / Mode B (Enter Amounts)

**Hands Per Hour**
- Online Hands/Hour (default 85)
- Live Hands/Hour (default 25)

**Exchange Rate Defaults**
- USD → Base rate (default 1.36)
- EUR → Base rate (default 1.47)
- USD → EUR rate (default 0.92)

**Data**
- Export Data → JSON export via share sheet
- Import Data → JSON import (blocked if any data exists)
- Reset All Data → destructive alert → deletes all records

**About**
- App version
- Replay Tutorial → presents TutorialView as sheet
- Legal / privacy info

### Business Rules
- Base currency is read-only here — it cannot be changed post-onboarding
- Import is hard-blocked if any data exists in any entity
- Export always succeeds (produces JSON regardless of data volume)
- Reset shows a destructive confirmation alert before proceeding

---

## Filter Sheet

**File:** `Views/Filter/FilterSheetView.swift`
**Entry Points:** Sessions list filter button; Stats filter button

### Presentation
`.presentationDetents([.medium, .large])` — starts medium, draggable to large

### Sections (accordion, one open at a time)
1. **Date Range:** All Time, This Week, This Month, This Year, Custom (date pickers)
2. **Session Type:** Live, Online (multi-select toggles) — Sessions screen only
3. **Location:** Multi-select from Location entities — Sessions screen only
4. **Platform:** Multi-select from Platform entities
5. **Game Type:** Multi-select from known game types
6. **Blind Level:** Multi-select from levels seen in session history
7. **Result:** All / Winning / Losing / Break Even — Sessions screen only
8. **Verification:** All / Verified Only / Unverified Only — Sessions screen only

### Toolbar
- Clear All (left): resets all filters, collapses all sections
- Done (right): dismisses sheet

### Active Filter Indicators
- Gold dot beside section title when section has active filter
- Count badge on the filter toolbar button showing total active filter count
- Default values (All Time, etc.) do NOT count as active filters
