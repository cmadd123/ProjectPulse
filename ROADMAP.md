# ProjectPulse Launch Roadmap

Organized so each phase has a clear **gate** — don't advance until the gate is met.

## Current state (as of last session)

- ✅ iOS TestFlight build working (Codemagic wired, App Store Connect app record created as "ProjectPulse HQ")
- ✅ Android debug loop working (ADB install flow on Samsung A15)
- ✅ Demo project seeder — Johnson Kitchen Remodel fully populated: 4 milestones, photos, CO, 2 client_changes, 4 expenses, 4 time entries, 2 crew, 3 subs w/ mixed COI states, 1 accepted estimate, 7 schedule entries
- ✅ Firestore rules fixed for client_changes subcollection
- ✅ All_projects_screen chip overflow fixed
- ✅ Schedule chip abbreviation fixed ("JKR" not "KR-")
- ✅ Contractor CO view confirmed (read-only in Activity tab, renders alongside photos + completed milestones)
- ✅ Raw `print()` calls replaced with `debugPrint()` in shipped code
- ✅ Phase 1c: Analytics + Crashlytics live (10 conversion events wired, user_role as user property, first-* events gated on SharedPreferences)
- ⏳ Need logo (1024×1024 PNG, user working on it)

## Next up (in order)

1. **Fake invitation flow** (Phase 1a) — "auto-send" is fake; replace with real shareable link OR wire up email Cloud Function
2. **Silent catch blocks** (Phase 1a) — surface SnackBars on failure
3. **Push notifications diagnosis** (Phase 1a) — known broken
4. **Empty-state "Try demo project" button** (Phase 1b finish) — currently only via dev tools
5. **Public demo URL** (Phase 1d) — `/c/johnson-kitchen` client-portal preview

---

---

## Phase 0 — Ship iOS build (this week)

**Goal:** installable on your phone via TestFlight.

- [ ] Logo (in progress) — 1024×1024 PNG, no transparency, no rounded corners
- [ ] Drop logo in repo root → wire up `flutter_launcher_icons` → one command generates all iOS + Android sizes → commit + push (~30 min when you have the PNG)
- [ ] Codemagic rebuilds automatically on push → TestFlight upload
- [ ] Install on your iPhone, poke around, file any obvious issues

**Gate to Phase 1:** app installs from TestFlight, you can sign in and see your existing data on iOS.

---

## Phase 1 — Pre-tester hardening (1–2 weeks)

**Goal:** app doesn't embarrass itself in front of a real contractor.

### 1a — Pre-tester blockers (~3 days)
- [ ] Fix invitation flow — replace fake "auto-send" with real shareable link OR wire up email Cloud Function
- [ ] Strip all `debugPrint` / `print` from production code
- [ ] Fix silent `catch {}` blocks — at minimum surface a SnackBar
- [ ] Logout confirmation dialog
- [ ] Push notifications — diagnose why they're not firing, fix the token save or rule issue

### 1b — Demo project wiring (~1 day)
- [ ] Wire up `lib/data/demo_project_data.dart` (already imported at [main.dart:30](lib/main.dart#L30), unused)
- [ ] "Try a demo project" button on empty-state GC dashboard
- [ ] `is_demo: true` flag so notifications / invoicing don't fire for fake data
- [ ] "Exit demo" path that clears it and starts a real project

### 1c — Analytics (~half a day)
- [ ] Add `firebase_analytics` + `firebase_crashlytics` to pubspec
- [ ] Wire up ~10 events: `signed_up`, `role_selected`, `first_project_created`, `first_invite_sent`, `milestone_completed`, `milestone_approved`, `invoice_generated`, `payment_marked_paid`, `photo_uploaded`, `client_portal_opened`
- [ ] Crashlytics automatic crash reporting

### 1d — Public demo URL (~1 day)
- [ ] `projectpulsehub.com/demo/johnson-kitchen` — read-only client-portal view of the demo project
- [ ] Shareable link for cold outreach emails or GC bid meetings

**Gate to Phase 2:** you can hand your phone to a stranger, they poke a demo project, it works; you can send them a link and they see what clients see.

---

## Phase 2 — Recruit 3–5 testers (1–2 weeks of conversations)

**Goal:** real contractors running real projects through the app, in parallel with their existing workflow.

- [ ] Warm-list outreach first (friends, friends-of-friends, your bid-winner GCs)
- [ ] Lumber yards / Home Depot pro desks / HBA meetings for cold leads
- [ ] Pitch: parallel usage, 1 project, weekly 15-min call with you, direct text access, free forever
- [ ] Each tester: start them on the demo, then help them create their first real project
- [ ] Fake payments — manually mark invoices paid for now
- [ ] Watch Firebase Analytics daily, take notes on drop-off points

**Gate to Phase 3:** ≥2 testers have run at least one project end-to-end (project → milestone → approval → invoice) and say some version of "this is better than what I had."

---

## Phase 3 — Fix what testers hit (2–4 weeks rolling)

**Goal:** app survives real-world usage without breaking trust.

- [ ] Weekly 15-min calls with each tester
- [ ] Triage ruthlessly: fix only blocker-level bugs (data loss, broken notifications, missed invoices). Ignore nits.
- [ ] Kill features no one uses — analytics will tell you
- [ ] Document recurring issues → these become your v1.0 blockers

**Gate to Phase 4:** tester says "I'd pay for this" OR testers keep using it for 3+ weeks without you nudging them.

---

## Phase 4 — Stripe Connect payout (2–3 focused days)

**Goal:** real money can flow from client → your platform → GC.

- [ ] Port MomRise's `createCreatorOnboardingLink` → `createContractorOnboardingLink`
- [ ] Store `stripe_connect_account_id` + onboarding status on contractor user docs
- [ ] Block the client "Pay" button until GC has a verified connected account
- [ ] Add `on_behalf_of` + `application_fee_amount` (your 1%) to Payment Intent creation
- [ ] Transfer to GC on `payment_intent.succeeded` webhook
- [ ] Build contractor earnings ledger (`contractor_earnings` collection + mobile UI)
- [ ] Monthly payout scheduler (copy MomRise's pattern)
- [ ] Switch `pk_test_*` → live keys, move to Secret Manager
- [ ] Refund handling in webhook
- [ ] Move invoice creation from client-side writes to a Cloud Function (security)

**Gate to Phase 5:** test transactions route correctly in Stripe Connect test mode end-to-end.

---

## Phase 5 — Live payments, slowly (1–2 weeks)

**Goal:** first real dollars flow without incident.

- [ ] One tester flips from fake to real payments
- [ ] Watch the first 10 transactions in Stripe dashboard live
- [ ] Fix what breaks immediately
- [ ] Second tester flips
- [ ] Continue to 3–5 live testers

**Gate to Phase 6:** ≥3 GCs have received real payouts from real clients via the app.

---

## Phase 6 — Web dashboard MVP (3–5 days)

**Goal:** back-office users (spouse, admin, bookkeeper) can do invoicing and reporting from a laptop.

- [ ] Fork MomRise creator dashboard skeleton (same Firebase, same auth)
- [ ] Projects list + financial summary
- [ ] Invoices tab — bulk print, resend, mark paid, CSV export for QuickBooks
- [ ] Revenue dashboard — collected vs. outstanding, chart over time
- [ ] Team/sub management
- [ ] Ship at `projectpulsehub.com/dashboard` (or a subdomain)

**Gate to Phase 7:** 1 tester's back-office (spouse/admin) uses the web dashboard weekly.

---

## Phase 7 — Landing page + outreach (2–3 days)

**Goal:** cold prospects can discover and try the app without a 1:1 call.

- [ ] Hero: headline + 30s screen-recording loop
- [ ] 3 specific benefits (not 12)
- [ ] 2-3 tester quotes — real names, photos, crew sizes
- [ ] "See a demo" button → Phase 1d public demo URL
- [ ] "Book a call" → Calendly
- [ ] Single CTA: "Try it free"

**Gate to Phase 8:** landing page → demo → signup conversion measurable.

---

## Phase 8 — Growth mechanics (ongoing)

**Goal:** app starts growing without 1:1 effort per user.

- [ ] Subcontractor-driven referral ($100 on activation, funded by 1% markup)
- [ ] GC → GC cash referral ($100 / $100 on first-payment activation)
- [ ] Project-completion summary page (peak emotional moment → share + review prompt)
- [ ] "Managed with ProjectPulse" watermark on photo exports
- [ ] Before/after photo generator — free marketing for the GC
- [ ] Rate-us in app (port MomRise `ReviewService` pattern)
- [ ] Content marketing / SEO
- [ ] Pro subscription tier ($29-49/mo) with feature gating (only if GCs ask for it — validate demand first)

---

## Critical constraints across all phases

- **Never skip a gate.** Each one exists because the downstream phase assumes its precondition is true. Skipping = wasted work.
- **Don't build Phase 4 (Stripe Connect) until Phase 3 gate is met.** Payment infrastructure on top of a product nobody loves is a vanity project.
- **Don't build Phase 7 (landing page) until you have Phase 6 tester quotes.** A landing page without social proof is a page.
- **Analytics (Phase 1c) must exist before testers (Phase 2).** Otherwise you're flying blind.
- **Logo (Phase 0.1) isn't on the critical path for anything except TestFlight.** If you can't ship a logo this week, put a placeholder and move on. Don't let perfect block good.

## Total rough budget

Phases 0–5 ≈ **5–8 weeks** of real work + tester conversations. That gets you to "real GCs paying real money through the app." Phases 6–8 compound after that.
