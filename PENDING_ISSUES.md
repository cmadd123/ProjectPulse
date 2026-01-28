# ProjectPulse - Pending Issues & Features

## GitHub Repository

**Repo:** https://github.com/cmadd123/ProjectPulse
**Status:** Backed up and version controlled ✅

---

## Completed Fixes (2026-01-27)

### ✅ 1. "Request Changes" Button Layout (FIXED - v0.0.45)

**Problem:** Button text "Request Changes" wrapping to 4 lines - too cramped

**Solution:** Changed to icon + shorter text
- Now uses `OutlinedButton.icon` with edit icon
- Text changed to just "Changes"
- Consistent styling with Approve button
- Updated in both files:
  - `lib/components/project_timeline_widget.dart`
  - `lib/components/milestone_list_widget.dart`

**Code:**
```dart
OutlinedButton.icon(
  onPressed: () { /* TODO: Request changes */ },
  icon: const Icon(Icons.edit, size: 16),
  label: const Text('Changes'),
  style: OutlinedButton.styleFrom(
    padding: const EdgeInsets.symmetric(vertical: 12),
  ),
)
```

### ✅ 2. Tab Notification Badges (FIXED - v0.0.46)

**Problem:** Users can't tell when there are new updates without opening tabs

**Solution:** Converted to StatefulWidget with real-time Firestore streams
- Converted `ClientProjectTimeline` from StatelessWidget to StatefulWidget
- Added Firestore streams to count pending items:
  - Milestones: Counts milestones with `status == 'awaiting_approval'`
  - Activity: Counts change orders with `status == 'pending'`
- Red notification badges show count (or "9+" if > 9)
- Badges update in real-time when items are added/approved

**Code:**
```dart
// In initState, listen to Firestore
FirebaseFirestore.instance
    .collection('projects')
    .doc(widget.projectId)
    .collection('milestones')
    .where('status', isEqualTo: 'awaiting_approval')
    .snapshots()
    .listen((snapshot) {
  if (mounted) {
    setState(() {
      _pendingMilestonesCount = snapshot.docs.length;
    });
  }
});

// Tabs with badges
Tab(
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Text('Milestones'),
      if (_pendingMilestonesCount > 0) ...[
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            _pendingMilestonesCount > 9 ? '9+' : '$_pendingMilestonesCount',
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    ],
  ),
)
```

---

## Pending Issues (High Priority)

### 1. Project Card Update Count (TODO - Complex)

**Problem:** Users can't tell when there are new updates without opening tabs

**Needed:**
- Notification badge on "Activity" tab for new photo updates/change orders
- Notification badge on "Milestones" tab for milestones awaiting approval
- Badge should show count (e.g., "3") or red dot
- Clear badge when user views that tab

**Challenges:**
- Need to convert `ClientProjectTimeline` from StatelessWidget to StatefulWidget
- Need to add Firestore streams for unread counts
- Need to track which items user has viewed (add `viewed_at` fields)

**Suggested Approach:**
```dart
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

### 2. Project Card Update Count (TODO - Complex)

**Problem:** Project cards showing "0 updates" even when there are pending items

**Needed:**
Count should include:
  - Milestones with status `awaiting_approval`
  - Progress updates not yet viewed (need to add `viewed_by_client` field to milestone_updates)
  - Change orders with status `pending`
  - New photo updates (need to add `viewed_at` field to updates collection)

**Location:** Client home screen project cards (need to find this screen)

---

## Current Status (v0.0.46)

### Completed Features
- ✅ Interactive milestone timeline with progress updates
- ✅ Start Working, Add Update, Mark Complete buttons (contractor)
- ✅ Reply to updates, Approve milestone buttons (client)
- ✅ Tabbed view: Milestones + Activity
- ✅ Progress bar header (optional via `showProgressHeader` parameter)
- ✅ Real-time milestone status updates
- ✅ Color-coded milestone states (grey, blue, orange, green, red)
- ✅ Fixed "Request Changes" button layout (icon + shorter text)
- ✅ Tab notification badges for pending milestones and activities

### Known Working Features
- Photo updates display in Activity tab
- Change orders display with Approve/Decline buttons
- Milestone timeline with vertical connector lines
- Progress updates show inline with timestamps
- Client responses show in blue containers under contractor updates

---

## Next Session Priorities

1. ~~Fix "Request Changes" button layout~~ ✅ DONE
2. ~~Add tab notification badges~~ ✅ DONE
3. Fix project card update count aggregation (requires finding client home screen)
4. Test full contractor → client update flow
5. Add Firebase Cloud Functions for actual push notifications (currently TODO)
