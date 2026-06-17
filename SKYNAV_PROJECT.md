# SkyNav — Project Brief for AI Sessions

## What This Is
SkyNav is a **premium iOS flight-tracking app** built by Weston K. It is a direct competitor to Flighty — targeting frequent travelers who want real-time flight data, live maps, smart alerts, and a beautiful iOS-native experience. This is a serious, production-intended app, not a demo.

---

## Core Goal
Build the best flight tracking app on the App Store. Every decision — design, architecture, features — should be made with that standard in mind.

---

## Tech Stack
- **SwiftUI** — iOS 17+ minimum, iOS 26 liquid glass design where available
- **SwiftData** — local persistence
- **MVVM** architecture
- **MapKit** — live in-flight map with great-circle arc route
- **WidgetKit** — home screen widgets (small + medium)
- **ActivityKit** — Live Activities + Dynamic Island
- **StoreKit 2** — subscription paywall
- **FlightAware AeroAPI v4** — real flight data (with `MockFlightDataService` fallback)
- **EventKit** — Calendar Sync
- **UserNotifications** — push notifications

---

## API Key (SECURITY CRITICAL)
- FlightAware AeroAPI key: stored in `SkyNav/SkyNav/Resources/Config.plist` (gitignored)
- **NEVER hardcode the key in Swift source files**
- **NEVER commit Config.plist to git**
- `Config.plist` is in `.gitignore` — keep it that way
- The key is loaded at runtime via `NSDictionary(contentsOf:)`

---

## App Structure
```
SkyNav/
├── SkyNav/                        ← Main iOS app target
│   ├── App/SkyNavApp.swift
│   ├── Models/Flight.swift
│   ├── Services/
│   │   ├── FlightDataProvider.swift      ← Protocol (swap mock ↔ real in 1 line)
│   │   ├── MockFlightDataService.swift   ← 12 realistic mock flights
│   │   ├── AeroAPIService.swift          ← FlightAware AeroAPI v4
│   │   ├── AeroAPIModels.swift
│   │   ├── FlightPollingService.swift    ← 20s in-flight, 5min far-out
│   │   ├── NotificationService.swift
│   │   ├── FlightLiveActivityManager.swift
│   │   ├── WidgetDataBridge.swift
│   │   ├── CalendarSyncService.swift     ← EventKit, "SkyNav Flights" calendar
│   │   ├── TaxiTimeService.swift         ← Taxi-out/in lookup (30 airports)
│   │   └── AirportDelayService.swift     ← Ground stop/delay programs
│   ├── ViewModels/ (6 files)
│   └── Views/
│       ├── Components/
│       │   ├── Theme.swift               ← All design tokens + GlassCard modifiers
│       │   ├── StatusPill.swift
│       │   ├── AirlineLogoView.swift     ← Real logos from Google CDN + fallback
│       │   └── TimeDisplay.swift
│       ├── Home/
│       │   ├── HomeView.swift            ← Tab order: Explore first, auto-jumps to Flights when active
│       │   ├── FlightCard.swift          ← Boarding-pass style, liquid glass on iOS 26
│       │   └── EmptyStateView.swift
│       ├── FlightDetail/
│       │   ├── FlightDetailView.swift
│       │   ├── FlightMapView.swift       ← MapKit, great-circle arc
│       │   ├── AircraftPhotoView.swift   ← Planespotters.net API photos
│       │   ├── FlightProgressBar.swift
│       │   └── FlightStatusRow.swift
│       ├── AddFlight/
│       │   ├── FlightSearchView.swift
│       │   └── TripItImportView.swift    ← Paste confirmation email → auto-parse flights
│       ├── Airport/
│       │   ├── AirportView.swift
│       │   └── AirportDelaysView.swift   ← Ground stop/delay program badges
│       ├── Trip/
│       │   ├── TripView.swift
│       │   ├── LayoverCard.swift
│       │   └── ConnectionAssistantView.swift ← Comfortable/tight/at-risk per connection
│       └── Subscription/
│           └── PaywallView.swift         ← $4.99/mo or $29.99/yr, 7-day trial
├── SkyNavWidgets/                 ← WidgetKit target
│   ├── SkyNavWidgets.swift
│   └── FlightLiveActivityWidget.swift
├── SkyNavLiveActivity/
│   └── FlightActivityAttributes.swift
├── project.yml                    ← xcodegen config
├── setup.sh                       ← Run on Mac: generates .xcodeproj
└── website/
    └── index.html                 ← Marketing website (self-contained HTML)
```

---

## Design System (Theme.swift)
| Token | Value | Use |
|-------|-------|-----|
| BG | `#0A0A0F` | App background |
| SURFACE | `#12121A` | Cards |
| SURF_RAISED | `#1C1C28` | Elevated cards |
| ACCENT | `#4A9EFF` | Apple blue, primary actions |
| ON_TIME | `#34C759` | Green status |
| CANCELLED | `#FF453A` | Red, errors, serious delays |
| IN_FLIGHT | `#64D2FF` | Light blue, in-flight status |
| DELAYED | white on `#2C2C2E` | Delayed status (NO orange) |
| GOLD | `#FFD60A` | Premium/paywall only |

**iOS 26:** All major views use `.glassEffect()` with `#available(iOS 26, *)` guards. Every guard has an iOS 17 fallback using `.ultraThinMaterial`.

**No orange anywhere in the app.** Orange was removed — delays use white-on-charcoal.

---

## Key Features Built
- ✅ Live flight tracking (AeroAPI + mock fallback)
- ✅ Live in-flight map (MapKit, great-circle arc, moving plane dot)
- ✅ Push notifications (gate changes, delays, boarding, "time to leave")
- ✅ Live Activities + Dynamic Island
- ✅ Home screen + lock screen widgets
- ✅ Trip view with multi-leg itineraries + layover countdown
- ✅ Connection Assistant (comfortable / tight / at risk, recalculates live)
- ✅ Airport view (departures/arrivals board, weather, ground delays)
- ✅ Calendar Sync (EventKit, "SkyNav Flights" calendar, 2hr alert)
- ✅ TripIt Import (paste confirmation email, regex parses flights)
- ✅ Taxi Times (taxi-out/in for 30 airports in flight detail)
- ✅ Arrival Forecast pill (accounts for current delay)
- ✅ Airport Delays (ground stop/delay program badges)
- ✅ Real airline logos (Google CDN + fallback)
- ✅ Aircraft photos (Planespotters.net API, photographer credit)
- ✅ Subscription paywall (StoreKit 2)
- ✅ iOS 26 liquid glass design (with iOS 17 fallbacks)
- ✅ Boarding-pass style flight cards with progress bar
- ✅ Tab order: Explore first by default, auto-switches to Flights when active
- ✅ Marketing website (website/index.html, mobile-optimized)

---

## Git Repo
- Remote: `https://github.com/vlyrl/SkyNav-Flight-Tracker-.git`
- Branch: `main`
- Config.plist is gitignored — never commit it

---

## Getting Started on Mac
```bash
cd SkyNav
./setup.sh          # generates .xcodeproj via xcodegen
```
Then in Xcode:
1. Set your Development Team
2. Set App Group to `group.com.skynav.shared` for both targets
3. Build & run

---

## What Weston Wants
- Premium, polished, production-quality — think Apple-level fit and finish
- Every screen should feel like it belongs on the App Store front page
- No placeholder UI, no "coming soon" sections — everything should be real and functional
- The app should feel faster and more beautiful than Flighty
- When in doubt, make it better, not safer
