# ProjectPulse Cloud Functions

Firebase Cloud Functions for sending push notifications to clients.

## Setup

1. **Install Firebase CLI** (if not already installed):
   ```bash
   npm install -g firebase-tools
   ```

2. **Login to Firebase**:
   ```bash
   firebase login
   ```

3. **Initialize Firebase project** (if not already done):
   ```bash
   cd projectpulse
   firebase init
   ```
   - Select "Functions"
   - Choose your Firebase project
   - Select JavaScript
   - Install dependencies: Yes

4. **Install dependencies**:
   ```bash
   cd functions
   npm install
   ```

## Deploy

Deploy functions to Firebase:

```bash
firebase deploy --only functions
```

Or deploy a specific function:

```bash
firebase deploy --only functions:sendPushNotification
```

## How It Works

### 1. App Creates Notification Document

When a contractor posts a photo, the app creates a document in the `notifications` collection:

```javascript
{
  type: 'photo_update',
  recipient_ref: DocumentReference,
  fcm_tokens: ['token1', 'token2'],
  title: 'New Photo Update',
  body: 'Kitchen Remodel: Demo complete',
  data: {
    project_id: 'abc123',
    project_name: 'Kitchen Remodel',
    type: 'photo_update'
  },
  created_at: Timestamp,
  processed: false
}
```

### 2. Cloud Function Triggers

The `sendPushNotification` function automatically triggers when the document is created:

- Reads the notification data
- Sends push notification to all FCM tokens
- Marks document as processed
- Removes invalid tokens

### 3. Client Receives Notification

The client's device receives the push notification and can:
- Show it in the notification tray
- Open the app directly to the project
- Update the UI if app is open

## Functions

### sendPushNotification

Triggered when a new document is created in `notifications` collection.

**What it does:**
- Sends push notification via Firebase Cloud Messaging
- Marks notification as processed
- Removes invalid FCM tokens
- Logs success/failure counts

### cleanupOldNotifications

Runs daily to delete notification documents older than 30 days.

**What it does:**
- Finds notifications older than 30 days
- Deletes them in batches (500 at a time)
- Keeps Firestore clean

## Testing

### Test with Firebase Emulator (Local)

```bash
cd functions
npm run serve
```

Then trigger a notification in your app while connected to the emulator.

### View Logs

```bash
firebase functions:log
```

Or view in Firebase Console → Functions → Logs

## Troubleshooting

### Function not triggering?

1. Check Firebase Console → Functions → ensure function is deployed
2. Check Firestore rules allow creating documents in `notifications` collection
3. View logs: `firebase functions:log`

### Notifications not being received?

1. Check FCM tokens are valid (stored in user document)
2. Check client app has notification permissions
3. View function logs for errors
4. Test sending a notification manually from Firebase Console

### Invalid tokens?

The function automatically removes invalid tokens from user documents.

## Cost

Firebase Cloud Functions pricing:
- **Free tier**: 2M invocations/month, 400K GB-seconds, 200K CPU-seconds
- **Paid**: $0.40 per million invocations

For ProjectPulse usage (assuming 100 contractors, 10 updates/day each):
- ~1,000 notifications/day = 30,000/month
- Well within free tier

## Security

The function runs with admin privileges and can:
- Send notifications to any device
- Access all Firestore data
- Remove invalid tokens

**Important**: Firestore security rules should prevent clients from creating notification documents directly.

## Next Steps

After deploying:

1. Test by posting a photo update
2. Check client receives notification
3. Monitor function logs for errors
4. Set up error alerting in Firebase Console
