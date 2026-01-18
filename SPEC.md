# Event Swipe App — MVP v0.1 SPEC

## Product Summary

An invite-only, event-scoped web/app experience where attendees can swipe on each other during a limited time window. Organizers create an event, pay a one-time fee, invite attendees, and unlock a time-boxed swipe experience that produces mutual matches.

The MVP is designed to be used **during a live event** (e.g. wedding, party, retreat) and to validate that time-boxed, contextual swiping drives engagement.

---

## Target Users

### Attendees

Guests of a specific event who want to discover and connect with other attendees.

### Organizers (Admins)

People hosting or organizing the event who want to increase guest interaction.

---

## Core Principles (Non‑negotiable)

- All interactions are **scoped to a single event**
- The app events are **invite-only**
- Swiping is **time-boxed**
- Organizers (not attendees) pay
- MVP prioritizes **speed, simplicity, and reliability** over features

---

## MVP Feature Scope

### Pricing & Access Defaults (MVP Decisions)

- **Free tier:** Yes — “Test mode” event allowed (limited attendees) without payment.
- **Timezone:** Yes — swipe windows are set in the organizer’s timezone and enforced server-side.
- **Match expiration:** Yes — matches expire after a fixed retention period (configurable constant for MVP).

### 1. Authentication

**Included**

- Email magic link OR Google login

**Excluded**

- Apple login
- Password recovery flows
- Account deletion

---

### 2. Event Joining

**Included**

- Join event via invite link (token-based)
- View event name on join
- One active event context at a time

**Excluded**

- Public event discovery
- Event search
- Multi-event switching UI

---

### 3. Attendee Profile

**Included**

- 1–3 photos
- First name or nickname
- Optional short bio
- Optional interests (tags or free text)

**Excluded**

- Age, gender, distance filters
- Social links
- Advanced preferences

---

### 4. Swipe Experience (Core User Value)

**Included**

- Swipe left / right
- One profile at a time
- Only attendees of the same event
- No re-swiping on the same profile

**Excluded**

- Super likes
- Undo / rewind
- Boosts or ranking algorithms

---

### 5. Time‑Boxed Availability (Critical)

**Included**

- Each event has:
  - `swipe_start_at`
  - `swipe_end_at`
- Swiping is:
  - Disabled before start time
  - Disabled after end time
- Clear UI states:
  - "Swiping opens at HH\:MM"
  - "Swiping has ended"

**Excluded**

- Multiple swipe rounds
- Organizer live control during event
- Push notifications
- Per-user time windows

---

### 6. Matches

**Included**

- Mutual right swipes create a match
- Matches are visible after they occur
- Matches persist after swipe window ends **until expiration**
- Matches expire after a fixed retention period (MVP constant; e.g. 7 days after `swipe_end_at`)

**Excluded**

- In-app chat
- Messaging requests
- Read receipts

---

### 7. Organizer / Admin

**Included**

- Create event (draft state)
- Set swipe start/end time
- Generate invite link
- View joined attendee count

**Excluded**

- Advanced analytics
- Moderation tools
- Branding customization

---

### 8. Payments (Organizer Only)

**Pricing Model**

- One-time payment per event
- Flat fee (e.g. \$39 per event)
- **Free tier (Test Mode):** organizer can run a limited event without payment (e.g. up to 20 attendees)

**Included**

- Stripe Checkout (single product)
- Organizer pays to unlock event
- Event transitions from `draft` → `paid`

**Behavior Rules**

- Attendees may join before payment
- Swiping is unlocked only if:
  - (Event is paid **OR** event is in free test mode and under the attendee limit)
  - Current time is within swipe window

**Excluded**

- Subscriptions
- Multiple pricing tiers
- Coupons or refunds
- Attendee payments

---

## State Model (Event Lifecycle)

1. **Draft** — event created, not paid
2. **Paid** — payment completed, waiting for swipe window
3. **Live** — within swipe window
4. **Ended** — swipe window closed; matches visible

---

## Success Criteria for MVP

- Attendees successfully join and swipe during the event
- Clear spike in activity during the swipe window
- Organizers are willing to pay for unlocking the event

---

## Explicitly Out of Scope (MVP v0.1)

- Chat
- Games / icebreakers
- Premium add-ons
- Public events
- Monetization beyond per-event fee

---

## Tech Assumptions (Non-binding)

- Flutter (web + mobile)
- Supabase (Auth, Postgres, Storage, RLS)
- Stripe Checkout
- Deployed via Vercel (web)

---

## MVP Definition of Done

The MVP is complete when a real organizer can:

1. Create and pay for an event
2. Share an invite link
3. Have attendees join
4. Observe real-time swiping during the time window
5. See attendees receive matches

