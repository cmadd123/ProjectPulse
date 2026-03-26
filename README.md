# ProjectPulse

Beautiful project communication app for contractors and clients. Track milestones, share photo updates, manage change orders, and keep everyone informed throughout the project lifecycle.

---

## Quick Links

- **[CLAUDE.md](CLAUDE.md)** - Main context for AI development sessions
- **[DEVELOPMENT.md](DEVELOPMENT.md)** - Architecture, implementation guides, and design decisions
- **[TESTING.md](TESTING.md)** - Complete testing procedures and checklists
- **[PENDING_ISSUES.md](PENDING_ISSUES.md)** - Current work and known issues
- **[PRE_LAUNCH_CHECKLIST.md](PRE_LAUNCH_CHECKLIST.md)** - Pre-launch tasks

---

## Project Overview

**Firebase Project**: projectpulse-7d258
**Web App**: https://projectpulse-7d258.web.app
**Repository**: https://github.com/cmadd123/ProjectPulse

### Tech Stack
- **Frontend**: Flutter (iOS + Android)
- **Backend**: Firebase (Auth, Firestore, Storage, Functions, Hosting, FCM)
- **Email**: SendGrid API
- **Notifications**: Firebase Cloud Messaging + SendGrid

### Key Features
- 📸 Photo updates with captions
- 📋 Milestone tracking with payment approvals
- 💰 Change order management
- 🔧 Client quality issue reporting
- ➕ Addition request system with quotes
- 📧 Email notifications (7 types)
- 🔔 Push notifications (19 types)
- 🔗 Deep linking from emails

---

## Getting Started

### Prerequisites
- Flutter SDK (3.x+)
- Firebase CLI (`npm install -g firebase-tools`)
- Node.js 22 (for Cloud Functions)
- Android Studio / Xcode
- SendGrid account (for emails)

### Setup
1. Clone repository
2. Install dependencies: `flutter pub get`
3. Set up Firebase project (already configured for projectpulse-7d258)
4. Configure SendGrid API key in Cloud Functions
5. Run: `flutter run`

### Firebase Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

### Firebase Hosting
```bash
firebase deploy --only hosting
```

---

## Documentation Structure

### [CLAUDE.md](CLAUDE.md)
**Purpose**: Main development context for Claude Code sessions.

**Contains**:
- Complete project history
- Architectural decisions
- Critical notes for future sessions
- Firebase project configuration
- MomRise app context (sibling project)

**When to Use**: Always read this first when starting a new Claude session.

---

### [DEVELOPMENT.md](DEVELOPMENT.md)
**Purpose**: Implementation guides and technical architecture.

**Contains**:
- Architecture overview (tech stack, database schema)
- Change system design (3 types: change orders, quality issues, additions)
- Deep linking implementation
- Notification system architecture
- Integration guides (SendGrid, FCM, Hosting)
- Key implementation decisions

**When to Use**: Implementing new features, understanding system design, integrating services.

---

### [TESTING.md](TESTING.md)
**Purpose**: Complete testing procedures and checklists.

**Contains**:
- Quick test guide (core flows)
- Notification testing (19 push + 7 email types)
- Deep linking testing
- Email testing procedures
- Manual testing workflows
- Troubleshooting guide
- Pre-launch testing checklist

**When to Use**: Before releases, debugging issues, validating features, pre-launch verification.

---

### [PENDING_ISSUES.md](PENDING_ISSUES.md)
**Purpose**: Current work, known issues, and priorities.

**Contains**:
- Completed fixes (timestamped)
- Pending issues (high priority)
- Pre-launch checklist
- Next session priorities

**When to Use**: Planning work, tracking bugs, understanding current status.

---

### [PRE_LAUNCH_CHECKLIST.md](PRE_LAUNCH_CHECKLIST.md)
**Purpose**: Final pre-launch tasks and verification.

**Contains**:
- Code review checklist
- Security verification
- Final testing procedures
- App store preparation

**When to Use**: Final week before launch, pre-release verification.

---

## Key Concepts

### User Roles
- **Contractor**: Creates projects, posts updates, manages milestones, responds to client requests
- **Client**: Views project timeline, approves milestones, reports issues, requests additions

### Change System (3 Types)
1. **Change Orders** (Contractor → Client) - Unexpected work requiring additional cost
2. **Quality Issues** (Client → Contractor) - Problems that need fixing
3. **Addition Requests** (Client → Contractor) - New work requests (contractor quotes)

### Notifications
- **Email**: 7 types (SendGrid), sent once per notification
- **Push**: 19 types (FCM), require app backgrounded
- **Debug Tools**: Real-time notification logging (beta only)

### Deep Linking
- **Invitations**: `projectpulse.app/join/{projectId}` → Opens to project
- **Notifications**: `projectpulse.app/app` → Opens to homepage
- **Custom scheme**: `projectpulse://`

---

## Project Structure

```
projectpulse/
├── lib/
│   ├── screens/
│   │   ├── contractor/      # Contractor-specific screens
│   │   ├── client/          # Client-specific screens
│   │   └── shared/          # Shared screens (notifications, etc.)
│   ├── components/          # Reusable UI components
│   │   ├── quality_issue_form_bottom_sheet.dart
│   │   ├── addition_request_form_bottom_sheet.dart
│   │   ├── change_type_selector_bottom_sheet.dart
│   │   └── project_timeline_widget.dart
│   ├── services/
│   │   ├── notification_service.dart    # Push notification logic
│   │   ├── deep_link_service.dart       # Deep link handler
│   │   ├── debug_logger.dart            # Real-time logging
│   │   └── fcm_service.dart             # FCM token management
│   └── main.dart
├── functions/               # Cloud Functions (Node.js 22)
│   ├── index.js            # Email functions (SendGrid)
│   └── package.json
├── hosting/                # Landing pages
│   ├── join.html           # Project invitation page
│   └── app.html            # Notification email page
├── android/                # Android config
├── ios/                    # iOS config
├── firestore.rules         # Security rules
├── CLAUDE.md               # Main development context
├── DEVELOPMENT.md          # Implementation guides
├── TESTING.md              # Testing procedures
├── PENDING_ISSUES.md       # Current work
├── PRE_LAUNCH_CHECKLIST.md # Pre-launch tasks
└── archive/                # Old documentation
```

---

## Common Commands

### Development
```bash
# Run app
flutter run

# Build APK
flutter build apk --debug
flutter build apk --release

# Deploy Cloud Functions
cd functions && firebase deploy --only functions

# Deploy Hosting
firebase deploy --only hosting

# View Functions logs
firebase functions:log
```

### Testing
```bash
# Run tests
flutter test

# Check FCM token
# Open Debug Tools screen in app (Settings → Debug Tools)

# Test deep links
# Android: adb shell am start -W -a android.intent.action.VIEW -d "projectpulse://app"
# iOS: xcrun simctl openurl booted "projectpulse://app"
```

---

## Troubleshooting

### Emails Not Arriving
- Check spam folder
- Verify SendGrid API key in Functions config
- Check Functions logs: `firebase functions:log`
- Verify `email_sent: false` in Firestore notification document

### Push Notifications Not Working
- Check FCM token in Debug Tools screen
- Ensure notification permissions granted
- Background the app (notifications only show when backgrounded)
- Verify notification document created in Firestore

### Deep Links Not Working
- Verify hosting deployed: `firebase deploy --only hosting`
- Check AndroidManifest.xml intent filters
- Test custom scheme: `projectpulse://app`

---

## Contributing

### Before Starting Work
1. Read [CLAUDE.md](CLAUDE.md) for project context
2. Check [PENDING_ISSUES.md](PENDING_ISSUES.md) for current priorities
3. Review [DEVELOPMENT.md](DEVELOPMENT.md) for architecture

### Making Changes
1. Create feature branch
2. Update relevant documentation
3. Test thoroughly (see [TESTING.md](TESTING.md))
4. Update [PENDING_ISSUES.md](PENDING_ISSUES.md) with completed work

---

## Archived Documentation

Older documentation moved to `archive/` folder for historical reference:
- Email testing guides
- Notification testing procedures
- Implementation design documents
- Debugging guides
- Fix logs and deployment notes

---

## License

Proprietary - All rights reserved

---

## Support

For questions or issues, contact the development team or create an issue in the GitHub repository.
