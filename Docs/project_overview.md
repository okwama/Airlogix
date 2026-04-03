# Mc Aviation Airline — Project Overview

> **Status:** Initiating Svelte Web Platform implementation based on Phase 4 progress.
> **Last updated:** 2026-03-31

---

## 1. What Mc Aviation Is

A **modern web-based airline booking and self-service platform** for **Mc Aviation Airline**, targeting passengers across East, Central, and Southern Africa.

- **Platform:** Svelte (Vite) → Responsive Web (Desktop + Mobile)
- **Region:** Key hubs (Nairobi, Dar es Salaam, Entebbe, etc.)
- **Payments:** M-Pesa, Card (DPO/Paystack), Mobile Money (Onafriq)
- **Backend:** PHP 8 REST API (Legacy AirLogix/RoyalAir)
- **Database:** MariaDB 10.6

---

## 2. Brand & Design System (Mc Aviation Blue)

| Token | Value |
|---|---|
| Primary Navy | `#1A237E` |
| Brand Orange (CTA) | `#FF5722` |
| Sky Blue (accents) | `#03A9F4` |
| Background | `#F5F7FA` |
| Surface | `#FFFFFF` |
| Text Primary | `#121212` |
| Text Secondary | `#666666` |
| Border | `#E0E0E0` |
| Success | `#4CAF50` |
| Warning | `#FFC107` |
| Error | `#F44336` |

**Style:** Premium, premium, and stunning. High-quality airline imagery. Rounded components and smooth transitions. Search button should be a vibrant **Orange** as shown in the mockup.

---

## 3. Web Architecture (Svelte)

### Pages
- **Home:** Hero search, featured offers, why us, app download sections.
- **Flight Search:** Real-time availability and pricing.
- **Booking Flow:** Multi-step passenger info, cabin selection, and summary.
- **Payment:** Integrated payment gateways for M-Pesa and cards.
- **Manage Booking:** E-ticket retrieval and check-in initiation.
- **Check-in:** Seat selection and boarding pass generation.
- **Auth:** Modern login/register with session management.

### Modules
- `ui/`: Design system components (AppButton, AppInput, AppCard).
- `features/flights/`: SearchBar, FlightResults, FlightFilters.
- `features/booking/`: PassengerForms, BookingSummary.
- `features/auth/`: AuthGuard, LoginForm, UserSession.
- `services/api/`: Base client + specialized service calls (flightsService, authService).
- `stores/`: Reactive stores for UI state, user data, and booking context.

---

## 4. Implementation Roadmap (Web MVP)

#### Phase 1 — Foundation
- [ ] Initialize Svelte + Vite
- [ ] Implement `index.css` with branding tokens
- [ ] Set up routing (Svelte-SPA-Router or similar)
- [ ] Scaffolding: Layout components (Navbar, Footer, MainLayout)

#### Phase 2 — Core UI Components
- [ ] Build reusable UI library based on Mc Aviation design system
- [ ] Implement Hero section with integrated SearchBar

#### Phase 3 — Flight Search & Results
- [ ] Integrate searching from API
- [ ] Build responsive flight result cards
- [ ] Implement result filtering (price, time, stops)

#### Phase 4 — Booking & Payment
- [ ] Implement multi-passenger data entry
- [ ] Integrate payment initialization and callbacks
- [ ] Confirmation and E-ticket display

#### Phase 5 — Management & Self-Service
- [ ] Guest "Find Booking" functionality
- [ ] Simple check-in flow
- [ ] User profile and history (Authenticated)

#### Phase 6 — Polish & Deployment
- [ ] Performance optimization
- [ ] Cross-browser/device testing
- [ ] Live API synchronization pass

---

## 5. Key Decisions (Web Context)

- **Framework:** Svelte + Vite for high performance and clean logic.
- **State:** Custom Svelte stores for reactive state management.
- **Styling:** Vanilla CSS for maximum flexibility and performance.
- **API Base:** `https://impulsepromotions.co.ke/api/royalair`
- **Auth:** JWT Bearer (stored in Cookie or LocalStorage).
- **Design:** "WOW" Factor based on the `Homepage_sample.jpeg` mockup.


