# ProjectPulse Development Guide

Complete development documentation including architecture decisions, implementation guides, and system designs.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Change System Design](#change-system-design)
3. [Deep Linking Implementation](#deep-linking-implementation)
4. [Notification System](#notification-system)
5. [Integration Guides](#integration-guides)
6. [Key Implementation Decisions](#key-implementation-decisions)

---

## Architecture Overview

### Tech Stack
- **Frontend**: Flutter (iOS + Android)
- **Backend**: Firebase
  - Authentication (email/password + Google)
  - Firestore (NoSQL database)
  - Cloud Storage (photos, documents)
  - Cloud Functions (Node.js 22, 2nd gen)
  - Cloud Messaging (push notifications)
  - Hosting (web landing pages)
- **Email**: SendGrid API
- **Deep Linking**: Universal links (iOS) + Android App Links

### Core Collections

```javascript
// users
{
  uid: string,
  role: 'contractor' | 'client',
  email: string,
  fcm_tokens: string[], // For push notifications

  contractor_profile: {
    business_name: string,
    owner_name: string,
    phone: string,
    logo_url: string,
  } | null,

  client_profile: {
    name: string,
    phone: string,
  } | null,
}

// projects
{
  project_id: string,
  contractor_uid: string, // For list queries
  contractor_ref: DocumentReference,
  contractor_business_name: string, // For client display

  project_name: string,
  client_name: string,
  client_email: string,
  client_phone: string,
  client_user_ref: DocumentReference | null,

  start_date: timestamp,
  estimated_end_date: timestamp,
  status: 'active' | 'completed',

  original_cost: number,
  current_cost: number,
}

// projects/{project_id}/milestones
{
  milestone_id: string,
  name: string,
  description: string,
  status: 'pending' | 'in_progress' | 'completed' | 'awaiting_approval' | 'approved',
  start_date: timestamp,
  end_date: timestamp | null,
  payment_amount: number,
  order: number, // Display order
}

// projects/{project_id}/updates
{
  update_id: string,
  photo_url: string,
  thumbnail_url: string,
  caption: string,
  posted_by_ref: DocumentReference,
  milestone_ref: DocumentReference | null,
  created_at: timestamp,
}

// projects/{project_id}/change_orders
{
  order_id: string,
  description: string,
  cost_change: number, // Positive or negative
  photo_url: string | null,
  status: 'pending' | 'approved' | 'declined',
  created_at: timestamp,
  responded_at: timestamp | null,
}

// projects/{project_id}/client_changes
{
  change_id: string,
  type: 'quality_issue' | 'addition_request',
  request_text: string,
  photo_url: string | null,
  milestone_ref: DocumentReference | null,
  requested_by_ref: DocumentReference,
  status: 'pending' | 'addressed' | 'completed',

  // For addition requests
  contractor_quote: {
    amount: number,
    description: string,
    responded_at: timestamp,
  } | null,

  created_at: timestamp,
  updated_at: timestamp,
}

// notifications
{
  notification_id: string,
  recipient_uid: string,
  recipient_ref: DocumentReference,
  fcm_tokens: string[], // Copied from user doc

  title: string,
  body: string,
  data: {
    project_id: string,
    type: string, // 'milestone_started', 'change_order', etc.
    // Additional type-specific data
  },

  email_sent: boolean, // Prevents duplicate emails
  created_at: timestamp,
  read: boolean,
}
```

---

## Change System Design

### Overview
ProjectPulse has **three distinct change types** to handle different scenarios:

### Type 1: Change Orders (Contractor-Initiated) ✅ IMPLEMENTED
**Purpose**: Contractor discovers unexpected work requiring additional cost.

**Example**: "Found rotted subflooring that needs replacement - add $800"

**Flow**:
1. Contractor encounters unexpected issue
2. Creates change order with description + cost + optional photo
3. Client gets notification (email + push)
4. Client reviews and approves/declines
5. If approved → Added to project total cost

**Status**: Fully functional

**Location**: `lib/screens/contractor/create_change_order_screen.dart`

---

### Type 2: Quality Issues (Client-Initiated) ✅ IMPLEMENTED
**Purpose**: Client reports quality problems or work needing correction.

**Example**: "Tile in bottom right corner is crooked"

**Flow**:
1. Client sees problem during in-progress milestone
2. Taps "Report Quality Issue"
3. Describes issue + optional photo
4. Contractor gets notification (email + push)
5. Contractor fixes and marks "Addressed"
6. Client confirms or reopens

**Status**: Fully functional (renamed from "Request Changes")

**Key Features**:
- Available during milestone (not just after completion)
- Red/warning color scheme
- Photo attachment support
- Contractor response flow

**Location**: `lib/components/quality_issue_form_bottom_sheet.dart`

---

### Type 3: Addition Requests (Client-Initiated) ✅ IMPLEMENTED
**Purpose**: Client requests additional work or scope changes mid-project.

**Example**: "Can you add an outlet in the pantry?"

**Flow**:
1. Client wants additional work
2. Taps "Request Addition"
3. Describes desired work + optional reference photo
4. Contractor gets notification (email + push)
5. Contractor provides quote OR declines
6. If quoted → Client approves/declines
7. If approved → Becomes change order (added to cost)

**Status**: Fully functional

**Key Features**:
- Purple/addition color scheme
- Contractor quote flow
- Converts to change order when approved
- Reference photo attachment

**Location**: `lib/components/addition_request_form_bottom_sheet.dart`

---

### Change Type Selector

**Problem**: Clients need to choose between quality issues and addition requests.

**Solution**: `ChangeTypeSelectorBottomSheet` - Shows two cards:
1. "Report Quality Issue" (red) - Something needs fixing (no extra cost)
2. "Request Addition" (blue) - New work not in original plan (will be quoted)

**Location**: `lib/components/change_type_selector_bottom_sheet.dart`

**Triggered From**:
- Milestone "Request Change" button
- Client Changes tab "+" button

---

## Deep Linking Implementation

### Current Status
- **Initial invitations**: `projectpulse.app/join/{projectId}` → join.html
- **Notification emails**: `projectpulse.app/app` → app.html
- **Custom scheme**: `projectpulse://`

### How It Works

#### 1. Project Invitation Flow
```
Client receives email
  ↓
Clicks link: projectpulse.app/join/{projectId}
  ↓
Opens join.html (attempts app launch)
  ↓
If app installed: Opens to project
If not installed: Shows download page
```

#### 2. Notification Email Flow
```
User receives notification email
  ↓
Clicks link: projectpulse.app/app
  ↓
Opens app.html (attempts app launch)
  ↓
If app installed: Opens to homepage
If not installed: Shows download page
```

#### 3. Deep Link Handler
**Location**: `lib/services/deep_link_service.dart`

Handles custom scheme URLs: `projectpulse://app`, `projectpulse://join/{projectId}`

Routes to appropriate screen based on user role (RoleDetectionScreen).

### Future Enhancement: Deep Link Parameters

**Goal**: Navigate directly to specific items (milestones, change orders) from emails.

**URL Pattern Examples**:
- Milestone: `/join/{projectId}?type=milestone&id={milestoneId}`
- Change order: `/join/{projectId}?type=changeOrder&id={orderId}`
- Quality issue: `/join/{projectId}?type=clientChange&id={changeId}`

**Implementation Steps** (Not Yet Done):
1. Add IDs to notification data (notification_service.dart)
2. Update email functions to include parameters (functions/index.js)
3. Update landing page to parse parameters (join.html)
4. Update deep link handler to navigate (deep_link_service.dart)

**Why Not Implemented**: Lower priority (current links work, just go to timeline instead of specific item).

**Recommendation**: Implement post-launch in phases (most important emails first).

---

## Notification System

### Architecture

**Two Types of Notifications**:
1. **Push Notifications** (19 types) - In-app, via FCM
2. **Email Notifications** (7 types) - Via SendGrid

**Flow**:
```
User action (e.g., mark milestone complete)
  ↓
NotificationService creates Firestore document
  ↓
Cloud Function triggers (onCreate)
  ↓
If email-worthy: Sends email via SendGrid
  ↓
Marks notification as email_sent: true
  ↓
App listens to notifications collection
  ↓
Displays push notification (if app backgrounded)
```

### Email Notification Types

#### Client Emails (4 types)
Appear from contractor's business name, reply-to contractor email.

1. **Project Invitation** (Purple) - When contractor sends invitation
2. **Milestone Started** (Blue) - When contractor starts milestone
3. **Milestone Completed** (Green) - When contractor marks complete
4. **Change Order Submitted** (Orange) - When contractor submits change order

#### Contractor Emails (3 types)
Appear from "ProjectPulse" for business operations.

5. **Milestone Approved** (Green) - When client approves milestone
6. **Change Order Response** (Green/Red) - When client approves/declines
7. **Client Requests** (Orange/Purple) - When client reports issue or requests addition

### Push Notification Types

**Contractor Receives** (10 types):
- Change order approved/declined
- Quality issue reported
- Addition requested
- Chat message from client
- Quality issue fixed confirmation
- Addition quote response
- Milestone approved
- Change request addressed
- Payment processed (future)
- Crew assignment (future)

**Client Receives** (9 types):
- Photo update
- Change order submitted
- Milestone completed
- Milestone started
- Chat message from contractor
- Quality issue fixed
- Addition quoted
- Milestone schedule created
- Project completed

### Email Personalization

**Problem Solved**: Emails were using generic "Hi there!" instead of actual names.

**Solution**:
- Use `projectData.client_name` (not `clientData.name` which is often empty)
- Extract first name: `fullName.split(' ')[0]`
- Same pattern for contractor names: `profile.owner_name`

**Location**: Cloud Functions (`functions/index.js`) - All email functions updated.

### Debug Logging

**DebugLogger Service**: Real-time notification logging for troubleshooting.

**Features**:
- Emoji indicators (✅ success, ❌ error, 🚀 start, 📋 info)
- In-memory log storage (last 100 entries)
- Listener pattern for UI updates
- Timestamp on each log entry

**Location**: `lib/services/debug_logger.dart`

**Debug Tools Screen**: `lib/screens/contractor/debug_tools_screen.dart`
- Shows FCM token status (green = enabled, orange = not ready)
- Token count and copy button
- Real-time log viewer
- Clear logs button

**Important**: Remove debug tools screen before production launch.

---

## Integration Guides

### SendGrid Email Integration

**Setup**:
1. Create SendGrid account
2. Generate API key with mail send permission
3. Add to Firebase Functions config: `firebase functions:config:set sendgrid.api_key="SG.xxx"`
4. Set from email: `SENDGRID_FROM_EMAIL=noreply@projectpulse.app`
5. Verify sender domain in SendGrid

**Email Template Structure**:
- Gradient header (color-coded by notification type)
- Personalized greeting with first name
- Project/business name in header
- CTA button with deep link
- ProjectPulse branding footer

**Important**: Emails only sent once per notification (checks `email_sent: true` flag).

---

### Firebase Cloud Messaging (FCM)

**Setup**:
1. Enable Cloud Messaging in Firebase Console
2. Add FCM configuration to Flutter app
3. Request notification permissions on app launch
4. Save FCM token to user document in Firestore

**Token Management**:
- Tokens stored as array in user document: `fcm_tokens: []`
- Updated on app launch (FCMService.initializeFCM)
- Checked in Debug Tools screen
- Notifications fail silently if no tokens (graceful degradation)

**Platform-Specific**:
- **Android**: Requires notification channel setup (Android 8.0+)
- **iOS**: Requires notification permissions prompt

---

### Firebase Hosting

**Purpose**: Serve landing pages for deep links.

**Pages**:
- `hosting/join.html` - Project invitation landing
- `hosting/app.html` - Notification email landing

**Deployment**: `firebase deploy --only hosting`

**Features**:
- Auto-attempts app launch (intent URLs for Android, universal links for iOS)
- Fallback to download page after 1.5 seconds
- Detects platform (iOS vs Android) for appropriate download buttons
- "Coming Soon" for app store links (until published)

---

## Key Implementation Decisions

### 1. Unified Change Type Selector

**Decision**: Use single entry point ("Request Change" button) that opens selector sheet.

**Why**:
- Clients confused by difference between quality issues and additions
- Single button reduces cognitive load
- Selector sheet explains difference clearly

**Alternative Considered**: Two separate buttons ("Report Issue" + "Request Addition")
**Rejected Because**: Too much UI clutter, confusing labels

---

### 2. Email Link Strategy

**Decision**: All notification emails link to `/app` (not `/join/{projectId}`).

**Why**:
- Simpler deep link handling (one target, role-based routing)
- `/join` is for initial invitations only (better semantics)
- Notifications always open to homepage (safe fallback)

**Alternative Considered**: Include project ID in notification links
**Rejected Because**: Adds complexity, homepage is acceptable landing page

---

### 3. Keyboard Overflow Fix

**Problem**: Bottom sheets had overflow errors when keyboard appeared.

**Solution**: `ConstrainedBox` with `maxHeight` calculation:
```dart
final screenHeight = MediaQuery.of(context).size.height;
final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
final maxHeight = screenHeight - keyboardHeight - 100;

Container(
  padding: EdgeInsets.only(bottom: keyboardHeight + 24),
  child: ConstrainedBox(
    constraints: BoxConstraints(maxHeight: maxHeight),
    child: SingleChildScrollView(
      child: Column(/* form content */),
    ),
  ),
)
```

**Why This Works**: Gives `SingleChildScrollView` a concrete max height, enabling proper scrolling.

**Applied To**:
- `quality_issue_form_bottom_sheet.dart`
- `addition_request_form_bottom_sheet.dart`

---

### 4. Button Text Cutoff Fix

**Problem**: ElevatedButton text cut off at bottom.

**Solution**: Increase height to 56px, add explicit vertical padding:
```dart
SizedBox(
  height: 56,  // Increased from 50
  child: ElevatedButton(
    style: ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(vertical: 16),  // Explicit padding
      // ...
    ),
  ),
)
```

**Applied To**:
- Sign in button (main.dart)
- Create change order button (create_change_order_screen.dart)

---

### 5. Notification Center Flash Fix

**Problem**: Notification list briefly showed loading spinner on every update.

**Solution**: Only show loading on first load (when no data):
```dart
builder: (context, snapshot) {
  // Only show loading on first load, not on subsequent updates
  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
    return const Center(child: CircularProgressIndicator());
  }
  // ...
}
```

**Applied To**: `notification_center_screen.dart`

---

## Archived Development Docs

Older implementation documentation moved to `archive/` folder:
- `3-TYPE-CHANGE-SYSTEM-DESIGN.md` - Consolidated into this guide
- `DEEP_LINKING_IMPLEMENTATION.md` - Consolidated into this guide
- `UNIFIED-CHANGE-SYSTEM-IMPLEMENTATION.md` - Consolidated into this guide
- `UNIFIED-CHANGE-SYSTEM-INTEGRATION-GUIDE.md` - Consolidated into this guide
- `ACTIVITY-FEED-INTEGRATION.md` - Consolidated into this guide
- `INTEGRATION-SUMMARY.md` - Consolidated into this guide
- `NOTIFICATION_GUIDE.md` - Consolidated into this guide (also in TESTING.md)

For historical reference and detailed implementation notes, see `archive/` folder.
