# ProjectPulse — Claude Code Notes

## TEMPORARY: Cloud Functions Migration (2026-02-27)

Migrated Cloud Functions from 1st Gen (v1) to 2nd Gen (v2) with Node 22.

### What changed:
- `firebase.json` — runtime `nodejs20` → `nodejs22`
- `functions/index.js` — rewritten with v2 imports (`onDocumentCreated`, `onDocumentUpdated`, `onSchedule` from `firebase-functions/v2/*`)
- `functions/package.json` — `firebase-functions` upgraded to `^7.0.6`, removed unused `twilio` dependency
- Config uses `defineString`/`defineSecret` from `firebase-functions/params` (replaces deprecated `functions.config()`)
- SendGrid API key stored in Cloud Secret Manager, from-email in `functions/.env`

### IAM bindings added via gcloud:
- `roles/iam.serviceAccountTokenCreator` — Pub/Sub service agent
- `roles/run.invoker` — compute service account
- `roles/eventarc.eventReceiver` — compute service account
- `roles/eventarc.serviceAgent` — Eventarc service agent

### Deployed functions (all Node.js 22, 2nd Gen):
1. `sendPushNotification` — Firestore onCreate on `notifications/{id}`
2. `cleanupOldNotifications` — daily schedule, deletes notifications >30 days
3. `checkCoiExpiry` — daily schedule, alerts on expiring COIs
4. `sendProjectInvitation` — Firestore onUpdate on `projects/{id}`, sends SendGrid email

### Remove this section once verified stable in production.

---

## TEMPORARY: Pre-Testing Bugs Found (2026-02-27)

### Items 1-8 — Bugs found during GC testing:

1. **Milestones template section not scrollable** — "What type of project?" cards take 80% of screen, can't scroll past them. Needs to be in a constrained/scrollable container.
2. **Invitation needs SMS option** — Client invitation only shows email. Need SMS send option + preview of email/SMS before sending.
3. **Project link needs permanent home** — No place for clients to share the project link with others (e.g., spouse). Need a "Copy Link" or share option visible in the project.
4. **Email invitation not sending** — Cloud Function deployed but emails not arriving. Debug sendProjectInvitation trigger and SendGrid delivery.
5. **Request changes button cramped** — Client-side request changes button is visually cramped, needs spacing/layout fix.
6. **Push notifications not firing** — GC posts update but client doesn't receive push. Debug FCM token saving, notification creation, and Cloud Function processing.
7. **Today section missing schedule** — GC dashboard "Today" section doesn't show the day's schedule entries.
8. **Schedule snackbar says "you're" for everyone** — Should only say "you're" when GC schedules for themselves; should show the person's name otherwise.
9. **Templates not prefilling** — Selecting a milestone template (Kitchen, Bathroom, etc.) doesn't pre-fill the milestones.

### Items 9-15 — Still need testing:

9. Skeleton loading (shimmer) on key screens
10. Client preview mode (eye icon on GC project details)
11. Client portal polish (Phase X of Y, approval hints, empty states, footer)
12. Invoice generation after milestone approval
13. Mark invoice as paid
14. Cloud Functions end-to-end (invitation email + push notification)
15. Demo project for new GC with zero projects

### Remove this section as bugs are fixed and items are verified.

---

## ACTION PLAN: Bug Fixes & Verification (2026-03-02)

Start here. This is the full implementation plan with root causes and fixes for bugs 1-9, plus items 9-15 that still need testing. Work through Phase 1 first, then Phase 2, then Phase 3, then Verification Items.

### Phase 1 — Quick Code Fixes (do these first)

**Bug 7: Today Section Missing Schedule (CRITICAL)**
- File: `lib/main.dart` — `_loadTodaySchedule()` method (~line 1111)
- Root cause: Queries `where('date', isEqualTo: todayStr)` with a STRING like "2026-03-02", but `schedule_screen.dart` stores `date` as a `Timestamp.fromDate()`. Type mismatch = zero results.
- Secondary: ~line 1505 reads `entry['member_name']` but the field is actually `user_name`.
- Fix: Replace string equality with Timestamp range query (`isGreaterThanOrEqualTo` start-of-day, `isLessThan` start-of-next-day). Fix field name to `user_name`.

**Bug 9: Templates Not Prefilling (CRITICAL)**
- File: `lib/screens/contractor/create_milestones_screen.dart` — `_loadTemplate()` method (~line 35)
- Root cause: Creates empty `TextEditingController()` and puts template values as `nameHint`/`descriptionHint`. The `_MilestoneCard` widget shows these as grey hint text, not actual editable content.
- Fix: Use `TextEditingController(text: entry.value.name)` and `TextEditingController(text: entry.value.description)`. Dispose old controllers before reassigning to prevent memory leaks.

**Bug 8: Schedule Snackbar Says "You're" for Everyone**
- File: `lib/screens/contractor/schedule_screen.dart` — `_assignProject()` method (~line 118)
- Root cause: No local confirmation snackbar for the GC. The push notification body ("You're scheduled...") goes to the recipient which is correct, but the GC doing the scheduling has no feedback.
- Fix: Add a SnackBar after the schedule entry is created. Compare `memberUid == FirebaseAuth.instance.currentUser!.uid` — if same, say "You're scheduled for [project] on [date]". If different, say "[Name] scheduled for [project] on [date]".

**Bug 1: Milestones Template Section Not Scrollable**
- File: `lib/screens/contractor/create_milestones_screen.dart` (~lines 243-327)
- Root cause: 5 template cards stacked vertically in a non-scrollable Column. Each card ~60px + padding = ~340px total = 80% of screen.
- Fix: Convert to a horizontal `ListView` row (height ~72px) with compact icon+label cards. Icons: Kitchen=countertops, Bathroom=bathtub, Roofing=roofing, Deck=deck, Custom=tune.

### Phase 2 — Medium UI Changes

**Bug 5: Request Changes Button Cramped**
- File: `lib/components/milestone_list_widget.dart` (~lines 318-340)
- Already shortened from "Request Changes" to "Changes" in v0.0.45. Verify current state on device. If still cramped: remove icon from button and increase gap between "Changes" and "Approve" buttons from 8→12px.

**Bug 3: Project Link Needs Permanent Home**
- GC side: Add a share `IconButton` to the AppBar in `lib/screens/contractor/project_details_screen.dart`. The `_shareProjectInvite()` method already exists (~line 93) — just wire it to a new AppBar button.
- Client side: Add a share `IconButton` to the AppBar in `lib/screens/client/client_project_timeline.dart`. Use `Share.share()` from `share_plus` package with the project link (`https://projectpulsehub.com/join/{projectId}`). Import `package:share_plus/share_plus.dart`.

### Phase 3 — Investigation + Fixes

**Bug 6: Push Notifications Not Firing**
- File: `lib/services/notification_service.dart`
- Multiple potential failure points: (a) `getToken()` returns null if permissions denied — no error handling at ~line 52, (b) `client_user_ref` null on project doc causes silent skip at ~line 129, (c) `fcm_tokens` array empty = silent skip.
- Fix: Add `debugPrint` at every silent return point. Then test: check Cloud Function logs (`firebase functions:log --only sendPushNotification`), check Firestore `notifications` collection for `processed` status, verify a test user's `users/{uid}` doc has `fcm_tokens` array populated.

**Bug 4: Email Invitation Not Sending**
- Files: `functions/index.js` (~line 197), `lib/screens/contractor/send_invitation_screen.dart` (~line 77)
- Likely a config issue. Check in this order: (1) `firebase functions:secrets:access SENDGRID_API_KEY` — is it set? (2) `functions/.env` has `SENDGRID_FROM_EMAIL`? (3) Is the from-email verified as a sender in the SendGrid dashboard?
- Code fix: The Cloud Function only triggers when `invitation_ready` goes from false→true. If the first send fails, re-clicking does nothing because the flag is already true. Fix: In `_sendInvitation()`, reset `invitation_ready` to false, wait 500ms, then set to true to re-trigger.

**Bug 2: SMS Invitation Preview**
- File: `lib/screens/contractor/send_invitation_screen.dart`
- Currently has email preview (lines 268-499) and a "Send Text" button (lines 580-594) that jumps to native SMS with no preview.
- Fix: Add an Email/SMS segmented toggle above the preview. When SMS is selected, show the formatted text message in a preview card (reuse the message-building logic from `_sendContractText()`). The main send button changes dynamically: "Send Email Invitation" or "Send Text Message". Remove the separate "Send Text" button from the bottom.

### Verification Items (9-15) — Test after bug fixes

These features were built in earlier phases. They need hands-on testing to confirm they work correctly. If broken, fix them.

9. **Skeleton loading (shimmer)** — `lib/components/skeleton_loader.dart` has 4 skeleton types. Used in `all_projects_screen.dart`. Open the app, check that project lists show shimmer placeholders while loading (not a spinner).

10. **Client preview mode** — `lib/screens/contractor/project_details_screen.dart` has an eye icon in the AppBar (~line 1486). Tap it → should open `ClientProjectTimeline` with `isPreview: true`. Verify it shows the client view read-only.

11. **Client portal polish** — Check `client_project_timeline.dart` and `client_dashboard_screen.dart` for: Phase X of Y labels on milestones, approval hint text ("Approving releases $X to contractor"), empty states with helpful messages, "Powered by ProjectPulse" footer.

12. **Invoice generation** — `lib/services/invoice_service.dart` generates a PDF after milestone approval. In `project_timeline_widget.dart` (~line 184), client approves milestone → `InvoiceService.generateAndSave()` is called. Check that a PDF is created in Firebase Storage and an invoice doc appears in `projects/{id}/invoices/`.

13. **Mark invoice as paid** — `lib/screens/contractor/project_details_screen.dart` has an Invoices tab (~line 1255). Find an invoice with status "sent" → tap "Mark as Paid" → confirm → status should change to "paid" with a timestamp.

14. **Cloud Functions end-to-end** — Trigger both: (a) Set `invitation_ready: true` on a project → check if `sendProjectInvitation` fires and email arrives. (b) Create a notification doc → check if `sendPushNotification` fires and push arrives on device.

15. **Demo project** — `lib/data/demo_project_data.dart` has a "Kitchen Remodel - Johnson Residence" demo. New GC with zero projects should see a "See a Demo Project" button on the dashboard (~line 1332 of `main.dart`). Tap it → should show the demo timeline.

### Files Reference

| File | Bugs/Items |
|------|------------|
| `lib/main.dart` | Bug 7, Item 15 |
| `lib/screens/contractor/create_milestones_screen.dart` | Bugs 1, 9 |
| `lib/screens/contractor/schedule_screen.dart` | Bug 8 |
| `lib/components/milestone_list_widget.dart` | Bug 5 |
| `lib/screens/contractor/project_details_screen.dart` | Bug 3, Items 10, 13 |
| `lib/screens/client/client_project_timeline.dart` | Bug 3, Items 10, 11 |
| `lib/services/notification_service.dart` | Bug 6 |
| `lib/screens/contractor/send_invitation_screen.dart` | Bugs 2, 4 |
| `lib/components/skeleton_loader.dart` | Item 9 |
| `lib/services/invoice_service.dart` | Item 12 |
| `lib/data/demo_project_data.dart` | Item 15 |
| `functions/index.js` | Bug 4, Item 14 |
