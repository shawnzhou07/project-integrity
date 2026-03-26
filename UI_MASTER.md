# Veritas UI Master Reference

---
> ⚠️ MAINTENANCE REQUIREMENT: This document must be updated whenever related code changes are made. Before closing any coding session, review changes made and update all affected sections in the relevant .md files. Outdated documentation is worse than no documentation.
---

> ⚠️ All UI changes must reference this document first. Do not deviate from these standards without updating this document.

---

## Brand Identity
- **App name:** Veritas: Poker Bankroll Tracker
- **Tagline:** "Precision Truth in Every Session"
- **Logo:** Spiral truth symbol rendered in gold on black background
- **Design philosophy:** Premium, dark, precise — no clutter, no decoration for its own sake

---

## Color System

| Name | Hex | Usage Rule |
|------|-----|-----------|
| Background | `#000000` | Root app background only |
| Surface | `#0D0D0D` | Cards, sheets, form backgrounds |
| Secondary Surface | `#1A1A1A` | Nested cards, table headers, secondary backgrounds |
| Borders/Dividers | `#2A2A2A` | Separators, dividers, outlines |
| Primary Text | `#FFFFFF` | Main content text |
| Secondary Text | `#8A8A8A` | Labels, captions, placeholders |
| Accent/Gold | `#C9B47A` | Primary brand accent, selected states, verified indicators, icons |
| Positive | `#4CAF50` | Profits, wins, deposits received |
| Negative | `#F44336` | Losses, costs, deposits sent |
| Pending/Warning | `#FF9500` | Pending withdrawals, warnings |
| Destructive | `#F44336` | Delete actions, irreversible operations |

---

## Typography

- **Font family:** SF Pro (system default)
- **Navigation titles:** `.navigationBarTitleDisplayMode(.inline)` everywhere, no exceptions
- **Hero values (net result):** 32pt, weight `.bold`
- **Section headers:** 18pt, weight `.semibold`, gold (`#C9B47A`)
- **Body text:** 15pt, weight `.regular`
- **Labels/captions:** 13pt, weight `.regular`, gray (`#8A8A8A`)
- **Table values:** 13pt, right-aligned
- **Badge text:** Small caps, 11pt
- **Max corner radius:** 16pt cards · 12pt inner cards · 8pt pills/chips · 6pt badges

---

## Spacing System

| Context | Value |
|---------|-------|
| Screen horizontal padding | 16pt |
| Card internal padding | 16–20pt |
| Section spacing (major) | 24pt |
| Row internal padding | 12pt horizontal · 10pt vertical |
| Icon-to-text spacing | 8pt |
| Between related elements | 8pt |
| Between unrelated sections | 16–24pt |

---

## Number Formatting

- **Monetary values:** `[sign][amount] [currencyCode]` — currency code AFTER number, never before
- **Positive values:** Explicit `+` prefix in lists and cards
- **Negative values:** `-` prefix
- **Zero values:** Gray (`#8A8A8A`), no sign
- **Decimal places:** Always 2 for monetary values
- **Thousands separator:** Applied
- **BB metrics (BB/100, BB/hour):** `%.1f BB` — number followed by space and "BB" suffix
- **Calendar smart format:** 3 significant digits max with k/m suffix, strip trailing zeros

---

## Verified Session Visual Language

- **Net result value:** Gold (`#C9B47A`) instead of green/red
- **Glow on net result:** `.shadow(color: gold.opacity(0.6), radius: 8)` + `.shadow(color: gold.opacity(0.3), radius: 16)`
- **Locked fields:** Gold lock icon (`"lock.fill"`) to LEFT of value
- **Locked field glow:** Scoped only to the value HStack, never the full row
- **Session list row:** Gold border (`lineWidth: 1.5`, `opacity: 0.45`) on card
- **Start/end time after verification:** Read-only with lock icon and glow on value only

---

## Component Patterns

### Cards
- Background: `#0D0D0D`
- Corner radius: 16pt
- No border by default
- Verified sessions: gold border overlay (`lineWidth: 1.5`, `opacity: 0.45`)

### Action Buttons (Deposit / Withdraw / Adjust / Analytics)
- Style: Outlined — border in button's accent color, matching text and icon color
- Deposit: red (`#F44336`)
- Withdraw: green (`#4CAF50`)
- Adjust: gold (`#C9B47A`)
- Analytics: gold (`#C9B47A`)
- Corner radius: 12pt
- Layout: icon + label horizontal

### Form Fields
- **Editable:** `[Label] ... [gray currencyCode] [TextField]`
- **Locked/verified:** `[Label] ... [lock icon] [value currencyCode]`
- **Read-only calculated:** Right-aligned value, no lock icon
- Numeric placeholder: `"0"`
- Select-all on focus
- Max 2 decimal places enforced
- `.keyboardType(.decimalPad)` for all numeric inputs

### Navigation
- All nav bars: black background
- Tab bar: black background, gold selected, gray unselected
- Tab icons: Sessions (`rectangle.stack.fill`), Stats (`chart.bar.fill`), Platforms (`building.columns.fill`), More (`ellipsis`)

### Badges/Pills
| State | Text Color | Background | Corner Radius |
|-------|-----------|-----------|---------------|
| Verified | Gold `#C9B47A` | `#1A1500` | 6pt |
| Pending | `#FF9500` | `#2A1500` | 6pt |
| Failed | Red | Dark red bg | 6pt |

### Filter Sheets
- `.presentationDetents([.medium, .large])`
- Collapsible accordion sections, one open at a time
- Section header: gold title left, chevron right rotating on expand
- Active filter: gold dot beside section title + count badge
- Default on open: nothing expanded (`openSection = nil`)
- Top bar buttons: `Clear All` (left) + `Done` (right)
- Clear All behavior: resets filters to defaults and collapses all sections
- Default values do NOT count as filters:
  - Date Range `All Time` is not counted
  - Chart axis defaults (X: Sessions, Y: Net Result) are not counted as filters
- Toolbar badge safety: badges must not clip when offset; use `frame(minWidth:minHeight:)` and add padding when needed

### Empty States
- Large SF Symbol in gold at 48pt, opacity 0.6
- Title: white, 17pt, weight `.semibold`
- Subtitle: gray (`#8A8A8A`), 14pt

### Floating Action Buttons
- 56pt diameter circle
- Gold background (`#C9B47A`), black icon
- Shadow: radius 4, black 30% opacity
- Position: bottom trailing, 16pt above tab bar (or above floating session bar if active)

---

## Tab Structure

| # | Label | Icon |
|---|-------|------|
| 1 | Sessions | `rectangle.stack.fill` |
| 2 | Stats | `chart.bar.fill` |
| 3 | Platforms | `building.columns.fill` |
| 4 | More | `ellipsis` |

---

## More Tab
- All row label text: white (`#FFFFFF`)
- SF Symbol icons: gold (`#C9B47A`)
- Standard list disclosure chevrons
- Contains: Charts, Calendar, Adjustments, Locations, Settings

---

## Session States

| State | Visual Indicator |
|-------|-----------------|
| Active | Green filled circle (10pt) top-left of session icon |
| Unverified | Gray question mark icon (`"questionmark.circle.fill"`) beside location name |
| Verified | Gold border on card, gold lock on financial fields |

---

## Platform Rules

- **Foreign platform rows:** Net result base currency (primary white) + current balance platform currency (secondary gray)
- **Same-currency platform rows:** Net result base currency (primary) + current balance base currency (secondary gray)
- **Cannot delete** a platform that has existing records

---

## Data Integrity Rules

- **Verified sessions:** `startTime`, `endTime`, financial fields permanently locked after verification
- **Deposits/withdrawals:** Permanent on save; only the method field is editable afterward
- **Platform balance:** Computed, never stored — derived from most recent verified session anchor
- **One unverified session** at a time enforced

---

## Animations

| Context | Animation |
|---------|-----------|
| Sheet transitions | `.easeInOut(duration: 0.35)` |
| Expand/collapse | Spring or easeInOut |
| Tab bar selection | Default SwiftUI |
| Floating button reposition | `.easeInOut(duration: 0.25)` |

---

## Online Platform Analytics — Summary Cards

The four summary metric cards at the top of `OnlinePlatformAnalyticsView` follow these value formats:

| Card | Format |
|------|--------|
| BB/100 | `"%.1f BB"` — e.g. `35.7 BB` |
| $/100 | `"%.2f [currencyCode]"` — e.g. `12.50 CAD` |
| BB/hour | `"%.1f BB"` — e.g. `83.1 BB` |
| $/hour | `"%.2f [currencyCode]"` — e.g. `45.00 CAD` |

---

## Bottom Safe Area & Dead Space Rules

Every scrollable screen must have sufficient bottom padding to prevent floating UI elements from overlapping content when fully scrolled down. This is mandatory for all screens.

**Base rule:** all screens add bottom padding = 16 pt breathing room. The iOS tab bar and its safe area are handled automatically; do not add 49 pt or `safeAreaInsets.bottom` manually as this double-counts.

**Floating session bar:** when an active session exists, the floating session bar appears above the tab bar at 60 pt height with an 8 pt gap. All screens must detect active session state (`startTime != nil AND endTime == nil`) and add an additional **68 pt** (60 pt bar + 8 pt gap) to bottom padding when a session is active. This padding is reactive — it animates with `.easeInOut(duration: 0.25)` as sessions start and end.

**Statistics screen additional rule:** the two stacked floating action buttons (Charts + Calendar, 56 pt each, 12 pt spacing, 16 pt gap above tab bar or session bar) add an additional **140 pt** on top of the base padding. When a session is also active on the Statistics screen, both the session bar height (68 pt) and button stack height (140 pt) are added.

**Shared implementation — use `smartBottomPadding` (defined in `Utils/AppColors.swift`):**

```swift
func smartBottomPadding(isSessionActive: Bool, isStatisticsScreen: Bool = false) -> CGFloat {
    var padding: CGFloat = 16               // base breathing room
    if isSessionActive    { padding += 68  } // session bar: 60 pt + 8 pt gap
    if isStatisticsScreen { padding += 140 } // two FABs: 56+12+56 + 16 pt gap
    return padding
}
```

| Screen state | Padding |
|---|---|
| No session, no FABs | 16 pt |
| Active session, no FABs | 84 pt |
| No session, Statistics screen | 156 pt |
| Active session, Statistics screen | 224 pt |

**Apply as:**
- ScrollView screens: `.padding(.bottom, smartBottomPadding(isSessionActive: hasActiveSession))` on the content VStack, plus `.animation(.easeInOut(duration: 0.25), value: hasActiveSession)`
- List/Form screens: `.safeAreaInset(edge: .bottom) { Color.clear.frame(height: smartBottomPadding(isSessionActive: hasActiveSession)) }` plus `.animation(.easeInOut(duration: 0.25), value: hasActiveSession)`

**Never hardcode bottom padding values.** Always call `smartBottomPadding`. Every view that needs this must add two `@FetchRequest` properties for active sessions:

```swift
@FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "startTime != nil AND endTime == nil"), animation: .default)
private var activeLiveSessions: FetchedResults<LiveCash>

@FetchRequest(sortDescriptors: [], predicate: NSPredicate(format: "startTime != nil AND endTime == nil"), animation: .default)
private var activeOnlineSessions: FetchedResults<OnlineCash>

private var hasActiveSession: Bool { !activeLiveSessions.isEmpty || !activeOnlineSessions.isEmpty }
```

---

## Do Not

- Never show currency code before the number
- Never use green or red for zero values
- Never use emojis in UI
- Never show coordinates or GPS data to the user
- Never allow verified financial fields to be edited
- Never apply glow or lock highlight to field labels — only to values
- Never store `currentBalance` as a Core Data attribute
- Never include deposits or withdrawals in session-based statistics calculations
