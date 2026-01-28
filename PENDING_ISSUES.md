# ProjectPulse - Pending Issues & Features

## UI/UX Issues (Client View - 2026-01-27)

### High Priority

1. **Tab Notification Badges**
   - Add notification dot/badge on "Activity" tab when there are new photo updates or change orders
   - Add notification dot/badge on "Milestones" tab when there are milestones awaiting approval or new progress updates
   - Badge should show count or just be a red dot indicator
   - Clear badge when user views that tab

2. **"Request Changes" Button Layout**
   - Currently showing 4 lines of text - too cramped
   - Button text wrapping poorly
   - Need to adjust button sizing or text to single line
   - Located in: `lib/components/project_timeline_widget.dart` (Approve/Request Changes row)

3. **Project Card Update Count**
   - Project cards showing "0 updates" even when there are:
     - Milestones awaiting approval
     - Change orders to review
     - Progress updates from contractor
   - Need to aggregate all notification types into single count
   - Located in: Client home screen project cards

### Implementation Notes

**Tab Badges:**
```dart
// Suggested approach - track unread counts
Tab(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('Activity'),
      if (unreadActivityCount > 0)
        Container(
          margin: EdgeInsets.only(left: 4),
          padding: EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.red,
            shape: BoxShape.circle,
          ),
          child: Text(
            unreadActivityCount > 9 ? '9+' : '$unreadActivityCount',
            style: TextStyle(fontSize: 10, color: Colors.white),
          ),
        ),
    ],
  ),
)
```

**Request Changes Button:**
```dart
// Current (4 lines):
OutlinedButton(
  child: const Text('Request Changes'),
)

// Options:
// 1. Shorter text: "Request Edits" or "Changes"
// 2. Icon + text
// 3. Smaller font size
// 4. Stack vertically instead of horizontally
```

**Project Card Count:**
- Count should include:
  - Milestones with status `awaiting_approval`
  - Progress updates not yet viewed (need to add `viewed_by_client` field)
  - Change orders with status `pending`
  - New photo updates (need to add `viewed_at` field)

---

## Current Status (v0.0.44)

### Completed Features
- ✅ Interactive milestone timeline with progress updates
- ✅ Start Working, Add Update, Mark Complete buttons (contractor)
- ✅ Reply to updates, Approve milestone buttons (client)
- ✅ Tabbed view: Milestones + Activity
- ✅ Progress bar header (optional via `showProgressHeader` parameter)
- ✅ Real-time milestone status updates
- ✅ Color-coded milestone states (grey, blue, orange, green, red)

### Known Working Features
- Photo updates display in Activity tab
- Change orders display with Approve/Decline buttons
- Milestone timeline with vertical connector lines
- Progress updates show inline with timestamps
- Client responses show in blue containers under contractor updates

---

## Next Session Priorities

1. Fix "Request Changes" button layout
2. Add tab notification badges
3. Fix project card update count aggregation
4. Test full contractor → client update flow
5. Add Firebase Cloud Functions for actual push notifications (currently TODO)
