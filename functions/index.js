// 2nd Gen (v2) Cloud Functions — runs on Node 22
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { defineString, defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const sgMail = require('@sendgrid/mail');

initializeApp();

// ── Configuration via params ─────────────────────────────────────
// Non-secret values come from functions/.env
const sendgridFromEmail = defineString('SENDGRID_FROM_EMAIL');

// Secret values come from Cloud Secret Manager
const sendgridApiKey = defineSecret('SENDGRID_API_KEY');

// Twilio is not yet configured — to enable SMS, run:
//   firebase functions:secrets:set TWILIO_ACCOUNT_SID
//   firebase functions:secrets:set TWILIO_AUTH_TOKEN
//   firebase functions:secrets:set TWILIO_PHONE_NUMBER

// ── 1. Push Notifications ───────────────────────────────────────
// Triggered when a new document is created in the 'notifications' collection
exports.sendPushNotification = onDocumentCreated(
  'notifications/{notificationId}',
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notificationData = snap.data();

    // Skip if already processed
    if (notificationData.processed) {
      console.log('Notification already processed, skipping');
      return;
    }

    try {
      const { fcm_tokens, title, body, data } = notificationData;

      if (!fcm_tokens || fcm_tokens.length === 0) {
        console.log('No FCM tokens found');
        await snap.ref.update({ processed: true, error: 'No FCM tokens' });
        return;
      }

      // Prepare notification message
      const message = {
        notification: {
          title: title || 'ProjectPulse',
          body: body || 'You have a new update',
        },
        data: data || {},
        tokens: fcm_tokens,
      };

      // Send to multiple devices
      const response = await getMessaging().sendEachForMulticast(message);

      console.log(`Successfully sent ${response.successCount} notifications`);
      console.log(`Failed to send ${response.failureCount} notifications`);

      // Update notification document as processed
      await snap.ref.update({
        processed: true,
        processed_at: FieldValue.serverTimestamp(),
        success_count: response.successCount,
        failure_count: response.failureCount,
      });

      // Remove invalid tokens
      if (response.failureCount > 0) {
        const failedTokens = [];
        response.responses.forEach((resp, idx) => {
          if (!resp.success) {
            failedTokens.push(fcm_tokens[idx]);
            console.error(`Failed to send to token: ${resp.error}`);
          }
        });

        // If tokens are invalid, remove them from user document
        if (failedTokens.length > 0 && notificationData.recipient_ref) {
          await notificationData.recipient_ref.update({
            fcm_tokens: FieldValue.arrayRemove(...failedTokens),
          });
          console.log(`Removed ${failedTokens.length} invalid tokens`);
        }
      }
    } catch (error) {
      console.error('Error sending notification:', error);
      await snap.ref.update({
        processed: true,
        error: error.message,
      });
    }
  }
);

// ── 2. Cleanup Old Notifications ────────────────────────────────
// Runs daily to delete notifications older than 30 days
exports.cleanupOldNotifications = onSchedule('every 24 hours', async () => {
  const db = getFirestore();
  const thirtyDaysAgo = Timestamp.fromDate(
    new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
  );

  const oldNotifications = await db
    .collection('notifications')
    .where('created_at', '<', thirtyDaysAgo)
    .limit(500)
    .get();

  const batch = db.batch();
  let count = 0;

  oldNotifications.docs.forEach((doc) => {
    batch.delete(doc.ref);
    count++;
  });

  if (count > 0) {
    await batch.commit();
    console.log(`Deleted ${count} old notification documents`);
  }
});

// ── 3. COI Expiry Check ─────────────────────────────────────────
// Sends push notification to team owner for COIs expiring within 30 days
exports.checkCoiExpiry = onSchedule('every 24 hours', async () => {
  const db = getFirestore();
  const now = new Date();
  const thirtyDaysFromNow = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);

  const teamsSnapshot = await db.collection('teams').get();

  for (const teamDoc of teamsSnapshot.docs) {
    const teamData = teamDoc.data();
    const ownerUid = teamData.owner_uid;

    const subsSnapshot = await teamDoc.ref.collection('subcontractors')
      .where('status', '==', 'active').get();

    const expiringCois = [];
    const expiredCois = [];

    for (const subDoc of subsSnapshot.docs) {
      const subData = subDoc.data();
      const coisSnapshot = await subDoc.ref.collection('coi').get();

      for (const coiDoc of coisSnapshot.docs) {
        const coiData = coiDoc.data();
        if (!coiData.expiry_date) continue;
        const expiryDate = coiData.expiry_date.toDate();

        if (expiryDate < now) {
          expiredCois.push({ sub: subData.company_name, type: coiData.coverage_type });
        } else if (expiryDate <= thirtyDaysFromNow) {
          expiringCois.push({ sub: subData.company_name, type: coiData.coverage_type });
        }
      }
    }

    if (expiringCois.length > 0 || expiredCois.length > 0) {
      const ownerDoc = await db.collection('users').doc(ownerUid).get();
      const ownerData = ownerDoc.data();
      const fcmTokens = ownerData?.fcm_tokens || [];

      if (fcmTokens.length > 0) {
        let body = '';
        if (expiredCois.length > 0) {
          body += `${expiredCois.length} expired COI(s). `;
        }
        if (expiringCois.length > 0) {
          body += `${expiringCois.length} expiring within 30 days.`;
        }

        await db.collection('notifications').add({
          type: 'coi_expiry',
          recipient_ref: db.doc(`users/${ownerUid}`),
          fcm_tokens: fcmTokens,
          title: 'COI Alert',
          body: body.trim(),
          data: { type: 'coi_expiry' },
          created_at: FieldValue.serverTimestamp(),
          processed: false,
        });
      }
    }
  }

  console.log('COI expiry check complete');
});

// ── 4. Project Invitation Email/SMS ─────────────────────────────
// Triggered when invitation_ready flag is set to true on a project
exports.sendProjectInvitation = onDocumentUpdated(
  {
    document: 'projects/{projectId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const beforeData = event.data.before.data();
    const afterData = event.data.after.data();
    const projectId = event.params.projectId;

    // Only send invitation if invitation_ready was just set to true
    if (beforeData.invitation_ready === true || afterData.invitation_ready !== true) {
      return;
    }

    // Initialize SendGrid with the secret value
    const apiKey = sendgridApiKey.value();
    if (apiKey) {
      sgMail.setApiKey(apiKey);
    }

    const projectData = afterData;

    try {
      const projectName = projectData.project_name || 'Your Project';
      const clientName = projectData.client_name || 'there';
      const clientEmail = projectData.client_email;
      const clientPhone = projectData.client_phone;
      const inviteLink = `https://projectpulsehub.com/join/${projectId}`;

      // Get contractor info for personalized message
      const contractorRef = projectData.contractor_ref;
      let contractorName = 'Your contractor';
      if (contractorRef) {
        const contractorDoc = await contractorRef.get();
        if (contractorDoc.exists) {
          const contractorData = contractorDoc.data();
          const profile = contractorData.contractor_profile;
          contractorName = profile?.business_name || contractorData.email?.split('@')[0] || 'Your contractor';
        }
      }

      const results = { sms: null, email: null };

      // SMS: Twilio not configured yet — skip
      if (clientPhone) {
        results.sms = { success: false, error: 'Twilio not configured' };
      }

      // Send Email if email address provided and SendGrid is configured
      if (clientEmail && apiKey) {
        try {
          const emailHtml = `
            <!DOCTYPE html>
            <html>
            <head>
              <meta charset="UTF-8">
              <meta name="viewport" content="width=device-width, initial-scale=1.0">
              <style>
                body {
                  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
                  line-height: 1.6;
                  color: #333;
                  margin: 0;
                  padding: 0;
                  background-color: #f8f9fa;
                }
                .container {
                  max-width: 600px;
                  margin: 20px auto;
                  background: white;
                  border-radius: 12px;
                  overflow: hidden;
                  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                }
                .header {
                  background: linear-gradient(135deg, #2D3748 0%, #FF6B35 100%);
                  color: white;
                  padding: 40px 0;
                  text-align: center;
                }
                .header-content {
                  padding: 0 30px;
                }
                .header h1 {
                  margin: 0 0 8px 0;
                  font-size: 28px;
                  font-weight: 700;
                }
                .header p {
                  margin: 0;
                  opacity: 0.95;
                  font-size: 16px;
                }
                .contractor-section {
                  background: #f8f9fa;
                  padding: 20px 0;
                  border-bottom: 1px solid #e2e8f0;
                }
                .contractor-content {
                  padding: 0 30px;
                  display: flex;
                  align-items: center;
                  gap: 16px;
                }
                .contractor-logo {
                  width: 60px;
                  height: 60px;
                  border-radius: 8px;
                  background: #e9ecef;
                  display: flex;
                  align-items: center;
                  justify-content: center;
                  flex-shrink: 0;
                  border: 2px solid #dee2e6;
                }
                .contractor-logo-placeholder {
                  color: #adb5bd;
                  font-size: 28px;
                }
                .contractor-info {
                  flex: 1;
                }
                .contractor-name {
                  color: #2D3748;
                  font-weight: 600;
                  font-size: 18px;
                  margin: 0 0 4px 0;
                }
                .contractor-label {
                  color: #718096;
                  font-size: 14px;
                  margin: 0;
                }
                .content {
                  padding: 30px;
                }
                .project-name {
                  color: #2D3748;
                  font-weight: 600;
                  font-size: 22px;
                  margin: 20px 0;
                  padding: 15px 20px;
                  background: #f8f9fa;
                  border-left: 4px solid #FF6B35;
                  border-radius: 4px;
                }
                .button {
                  display: inline-block;
                  background: linear-gradient(135deg, #2D3748 0%, #FF6B35 100%);
                  color: white;
                  padding: 16px 32px;
                  text-decoration: none;
                  border-radius: 8px;
                  font-weight: 600;
                  font-size: 16px;
                  margin: 20px 0;
                  box-shadow: 0 4px 6px rgba(45, 55, 72, 0.3);
                }
                .link-box {
                  background: #f8f9fa;
                  padding: 12px;
                  border-radius: 6px;
                  margin: 20px 0;
                  text-align: center;
                }
                .link-box code {
                  color: #718096;
                  font-size: 13px;
                  word-break: break-all;
                }
                .footer {
                  text-align: center;
                  padding: 30px;
                  background: #f8f9fa;
                  color: #718096;
                  font-size: 14px;
                  border-top: 1px solid #e2e8f0;
                }
                .footer strong {
                  color: #2D3748;
                }
              </style>
            </head>
            <body>
              <div class="container">
                <div class="header">
                  <div class="header-content">
                    <h1>ProjectPulse</h1>
                    <p>You've been invited to view your project</p>
                  </div>
                </div>

                <div class="contractor-section">
                  <div class="contractor-content">
                    <div class="contractor-logo">
                      <span class="contractor-logo-placeholder">&#128679;</span>
                    </div>
                    <div class="contractor-info">
                      <p class="contractor-label">Your Contractor</p>
                      <p class="contractor-name">${contractorName}</p>
                    </div>
                  </div>
                </div>

                <div class="content">
                  <p>Hi <strong>${clientName}</strong>!</p>

                  <p>${contractorName} has invited you to track your project in real-time:</p>

                  <div class="project-name">"${projectName}"</div>

                  <p>View daily photo updates, track milestones, and stay connected throughout your project.</p>

                  <p style="text-align: center;">
                    <a href="${inviteLink}" class="button">View Your Project &rarr;</a>
                  </p>

                  <div class="link-box">
                    <p style="margin: 0 0 8px 0; font-size: 13px; color: #718096;">Or copy this link:</p>
                    <code>${inviteLink}</code>
                  </div>
                </div>

                <div class="footer">
                  <p><strong>ProjectPulse</strong> &middot; Real-time project communication</p>
                  <p style="font-size: 12px; margin-top: 8px;">Keeping contractors and clients connected</p>
                </div>
              </div>
            </body>
            </html>
          `;

          const emailMsg = {
            to: clientEmail,
            from: {
              email: sendgridFromEmail.value(),
              name: 'ProjectPulse',
            },
            subject: `${contractorName} invited you to: ${projectName}`,
            text: `Hi ${clientName}!\n\n${contractorName} has created a project for you: "${projectName}"\n\nView real-time updates here: ${inviteLink}\n\nProjectPulse keeps you connected with your contractor through real-time updates, photo timelines, and instant messaging.\n\n- ProjectPulse Team`,
            html: emailHtml,
          };

          await sgMail.send(emailMsg);
          results.email = { success: true };
          console.log(`Email invitation sent to ${clientEmail}`);
        } catch (error) {
          results.email = { success: false, error: error.message };
          console.error(`Error sending email to ${clientEmail}:`, error);
        }
      }

      // Log invitation results to project document
      await event.data.after.ref.update({
        invitation_sent: {
          sms: results.sms,
          email: results.email,
          sent_at: FieldValue.serverTimestamp(),
        },
      });
    } catch (error) {
      console.error('Error sending project invitation:', error);
    }
  }
);
