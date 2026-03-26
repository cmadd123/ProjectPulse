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

      // DEBUG: Log what we actually received
      console.log('Full notificationData:', JSON.stringify(notificationData));
      console.log('fcm_tokens value:', fcm_tokens);
      console.log('fcm_tokens type:', typeof fcm_tokens);
      console.log('fcm_tokens is array?', Array.isArray(fcm_tokens));
      console.log('fcm_tokens length:', fcm_tokens?.length);

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
      // Extract first name only from client_name
      const fullClientName = projectData.client_name || 'there';
      const clientName = fullClientName.split(' ')[0];
      const clientEmail = projectData.client_email;
      const clientPhone = projectData.client_phone;
      const inviteLink = `https://projectpulse-7d258.web.app/join/${projectId}`;

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

// ── 5. Milestone Email Notification ─────────────────────────────
// Triggered when a notification document is created with type 'milestone_completed'
exports.sendMilestoneEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('❌ Milestone email: No snap');
      return;
    }
    const notificationData = snap.data();
    console.log('📧 Milestone email triggered, type:', notificationData.type);

    // Only process milestone_completed notifications
    if (notificationData.type !== 'milestone_completed') {
      console.log('❌ Not milestone_completed type:', notificationData.type);
      return;
    }

    // Skip if email already sent
    if (notificationData.email_sent) {
      console.log('❌ Email already sent for this milestone notification');
      return;
    }

    const apiKey = sendgridApiKey.value();
    if (!apiKey) {
      console.error('SendGrid API key not configured');
      return;
    }

    sgMail.setApiKey(apiKey);

    try {
      // Get client info
      const clientRef = notificationData.recipient_ref;
      if (!clientRef) {
        console.error('No recipient_ref in notification');
        return;
      }

      const clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        console.error('Client document does not exist');
        return;
      }

      const clientData = clientDoc.data();
      const clientEmail = clientData.email;

      if (!clientEmail) {
        console.log('Client has no email address, skipping email notification');
        await snap.ref.update({ email_sent: false, email_skipped: 'no_email' });
        return;
      }

      // Get project info
      const projectId = notificationData.data?.project_id;
      if (!projectId) {
        console.error('No project_id in notification data');
        return;
      }

      const projectDoc = await getFirestore().collection('projects').doc(projectId).get();
      if (!projectDoc.exists) {
        console.error('Project document does not exist');
        return;
      }

      const projectData = projectDoc.data();
      const projectName = projectData.project_name || 'Your Project';
      // Extract first name from project's client_name field (more reliable than user doc)
      const fullClientName = projectData.client_name || clientData.name || 'there';
      const clientName = fullClientName.split(' ')[0];
      // Updated: Link opens app to homepage (not project-specific join page)
      const projectLink = `https://projectpulse-7d258.web.app/app`;

      // Get contractor info
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

      // Extract milestone name from notification body
      const notificationBody = notificationData.body || '';
      const milestoneName = notificationBody.split(': ')[1] || 'A milestone';

      // Build email HTML
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
              background: linear-gradient(135deg, #10B981 0%, #059669 100%);
              color: white;
              padding: 40px 30px;
              text-align: center;
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
            .content {
              padding: 30px;
            }
            .milestone-box {
              background: #f0fdf4;
              border-left: 4px solid #10B981;
              padding: 20px;
              margin: 20px 0;
              border-radius: 8px;
            }
            .milestone-name {
              color: #065f46;
              font-weight: 600;
              font-size: 20px;
              margin: 0 0 8px 0;
            }
            .project-name {
              color: #6b7280;
              font-size: 14px;
              margin: 0;
            }
            .button {
              display: inline-block;
              padding: 14px 32px;
              background: linear-gradient(135deg, #10B981 0%, #059669 100%);
              color: white;
              text-decoration: none;
              border-radius: 8px;
              font-weight: 600;
              font-size: 16px;
              margin: 20px 0;
              box-shadow: 0 2px 4px rgba(16, 185, 129, 0.3);
            }
            .button:hover {
              box-shadow: 0 4px 8px rgba(16, 185, 129, 0.4);
            }
            .info-box {
              background: #f8f9fa;
              padding: 16px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .info-box p {
              margin: 0 0 8px 0;
              font-size: 14px;
              color: #4b5563;
            }
            .info-box p:last-child {
              margin-bottom: 0;
            }
            .footer {
              background: #f8f9fa;
              padding: 20px 30px;
              text-align: center;
              color: #6b7280;
              font-size: 14px;
            }
            .footer p {
              margin: 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>✓ Milestone Completed</h1>
              <p>Ready for your approval</p>
            </div>

            <div class="content">
              <p>Hi <strong>${clientName}</strong>!</p>

              <p><strong>${contractorName}</strong> has marked a milestone as complete on your project.</p>

              <div class="milestone-box">
                <p class="milestone-name">${milestoneName}</p>
                <p class="project-name">${projectName}</p>
              </div>

              <div class="info-box">
                <p><strong>What happens next?</strong></p>
                <p>• Review the completed work and photos</p>
                <p>• Approve the milestone if you're satisfied</p>
                <p>• Payment will be processed upon approval</p>
              </div>

              <p style="text-align: center;">
                <a href="${projectLink}" class="button">Review & Approve →</a>
              </p>

              <p style="font-size: 13px; color: #6b7280; margin-top: 30px;">
                You're receiving this email because you have a project with ${contractorName} on ProjectPulse.
              </p>
            </div>

            <div class="footer">
              <p><strong>ProjectPulse</strong> · Real-time project communication</p>
            </div>
          </div>
        </body>
        </html>
      `;

      // Get contractor email for reply-to
      let contractorEmail = null;
      if (contractorRef) {
        const contractorDoc = await contractorRef.get();
        if (contractorDoc.exists) {
          contractorEmail = contractorDoc.data().email;
        }
      }

      const emailMsg = {
        to: clientEmail,
        from: {
          email: sendgridFromEmail.value(),
          name: contractorName,
        },
        replyTo: contractorEmail || sendgridFromEmail.value(),
        subject: `✓ Milestone Complete: ${milestoneName}`,
        text: `Hi ${clientName}!\n\n${contractorName} has completed: ${milestoneName}\n\nProject: ${projectName}\n\nPlease review and approve the milestone in ProjectPulse:\n${projectLink}\n\n- ProjectPulse Team`,
        html: emailHtml,
      };

      await sgMail.send(emailMsg);

      // Mark notification as email sent
      await snap.ref.update({
        email_sent: true,
        email_sent_at: FieldValue.serverTimestamp(),
      });

      console.log(`Milestone email sent to ${clientEmail} for project ${projectId}`);
    } catch (error) {
      console.error('Error sending milestone email:', error);
      await snap.ref.update({
        email_sent: false,
        email_error: error.message,
      });
    }
  }
);

// ── 6. Change Order Email Notification ──────────────────────────
// Triggered when a notification document is created with type 'change_order'
exports.sendChangeOrderEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('❌ Change order email: No snap');
      return;
    }
    const notificationData = snap.data();
    console.log('📧 Change order email triggered, type:', notificationData.type);

    // Only process change_order notifications
    if (notificationData.type !== 'change_order') {
      console.log('❌ Not change_order type:', notificationData.type);
      return;
    }

    // Skip if email already sent
    if (notificationData.email_sent) {
      console.log('❌ Email already sent for this change order notification');
      return;
    }

    const apiKey = sendgridApiKey.value();
    if (!apiKey) {
      console.error('SendGrid API key not configured');
      return;
    }

    sgMail.setApiKey(apiKey);

    try {
      // Get client info
      const clientRef = notificationData.recipient_ref;
      if (!clientRef) {
        console.error('No recipient_ref in notification');
        return;
      }

      const clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        console.error('Client document does not exist');
        return;
      }

      const clientData = clientDoc.data();
      const clientEmail = clientData.email;

      if (!clientEmail) {
        console.log('Client has no email address, skipping email notification');
        await snap.ref.update({ email_sent: false, email_skipped: 'no_email' });
        return;
      }

      // Get project info
      const projectId = notificationData.data?.project_id;
      if (!projectId) {
        console.error('No project_id in notification data');
        return;
      }

      const projectDoc = await getFirestore().collection('projects').doc(projectId).get();
      if (!projectDoc.exists) {
        console.error('Project document does not exist');
        return;
      }

      const projectData = projectDoc.data();
      const projectName = projectData.project_name || 'Your Project';
      // Extract first name from project's client_name field (more reliable than user doc)
      const fullClientName = projectData.client_name || clientData.name || 'there';
      const clientName = fullClientName.split(' ')[0];
      // Updated: Link opens app to homepage (not project-specific join page)
      const projectLink = `https://projectpulse-7d258.web.app/app`;

      // Get contractor info
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

      // Parse change order details from notification body
      // Format: "ProjectName: Description ($+123 or $-123)"
      const notificationBody = notificationData.body || '';
      const parts = notificationBody.split(': ');
      const descriptionAndCost = parts[1] || '';
      const lastParenIndex = descriptionAndCost.lastIndexOf('(');

      let description = descriptionAndCost;
      let costChange = '';
      if (lastParenIndex !== -1) {
        description = descriptionAndCost.substring(0, lastParenIndex).trim();
        costChange = descriptionAndCost.substring(lastParenIndex + 1, descriptionAndCost.length - 1);
      }

      // Determine if cost increase or decrease
      const isIncrease = costChange.startsWith('+') || (!costChange.startsWith('-') && costChange.startsWith('$'));
      const headerColor = isIncrease ? '#DC2626' : '#10B981';
      const headerGradient = isIncrease
        ? 'linear-gradient(135deg, #DC2626 0%, #B91C1C 100%)'
        : 'linear-gradient(135deg, #10B981 0%, #059669 100%)';
      const boxBackground = isIncrease ? '#fef2f2' : '#f0fdf4';
      const boxBorder = isIncrease ? '#DC2626' : '#10B981';
      const headerText = isIncrease ? 'Change Order - Cost Increase' : 'Change Order - Cost Adjustment';

      // Build email HTML
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
              background: ${headerGradient};
              color: white;
              padding: 40px 30px;
              text-align: center;
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
            .content {
              padding: 30px;
            }
            .change-order-box {
              background: ${boxBackground};
              border-left: 4px solid ${boxBorder};
              padding: 20px;
              margin: 20px 0;
              border-radius: 8px;
            }
            .cost-change {
              color: ${headerColor};
              font-weight: 700;
              font-size: 24px;
              margin: 0 0 12px 0;
            }
            .description {
              color: #374151;
              font-size: 16px;
              margin: 0 0 8px 0;
              line-height: 1.5;
            }
            .project-name {
              color: #6b7280;
              font-size: 14px;
              margin: 0;
            }
            .button {
              display: inline-block;
              padding: 14px 32px;
              background: ${headerGradient};
              color: white;
              text-decoration: none;
              border-radius: 8px;
              font-weight: 600;
              font-size: 16px;
              margin: 20px 0;
              box-shadow: 0 2px 4px rgba(0, 0, 0, 0.2);
            }
            .button:hover {
              box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
            }
            .info-box {
              background: #f8f9fa;
              padding: 16px;
              border-radius: 8px;
              margin: 20px 0;
            }
            .info-box p {
              margin: 0 0 8px 0;
              font-size: 14px;
              color: #4b5563;
            }
            .info-box p:last-child {
              margin-bottom: 0;
            }
            .footer {
              background: #f8f9fa;
              padding: 20px 30px;
              text-align: center;
              color: #6b7280;
              font-size: 14px;
            }
            .footer p {
              margin: 0;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>${headerText}</h1>
              <p>Action required</p>
            </div>

            <div class="content">
              <p>Hi <strong>${clientName}</strong>!</p>

              <p><strong>${contractorName}</strong> has submitted a change order for your project.</p>

              <div class="change-order-box">
                <p class="cost-change">${costChange}</p>
                <p class="description">${description}</p>
                <p class="project-name">${projectName}</p>
              </div>

              <div class="info-box">
                <p><strong>What happens next?</strong></p>
                <p>• Review the change order details</p>
                <p>• Approve or decline the request</p>
                <p>• Project cost will be adjusted if approved</p>
              </div>

              <p style="text-align: center;">
                <a href="${projectLink}" class="button">Review Change Order →</a>
              </p>

              <p style="font-size: 13px; color: #6b7280; margin-top: 30px;">
                You're receiving this email because you have a project with ${contractorName} on ProjectPulse.
              </p>
            </div>

            <div class="footer">
              <p><strong>ProjectPulse</strong> · Real-time project communication</p>
            </div>
          </div>
        </body>
        </html>
      `;

      // Get contractor email for reply-to
      let contractorEmail = null;
      if (contractorRef) {
        const contractorDoc = await contractorRef.get();
        if (contractorDoc.exists) {
          contractorEmail = contractorDoc.data().email;
        }
      }

      const emailMsg = {
        to: clientEmail,
        from: {
          email: sendgridFromEmail.value(),
          name: contractorName,
        },
        replyTo: contractorEmail || sendgridFromEmail.value(),
        subject: `Change Order Pending: ${projectName}`,
        text: `Hi ${clientName}!\n\n${contractorName} has submitted a change order:\n\n${description}\nCost change: ${costChange}\n\nProject: ${projectName}\n\nPlease review and approve/decline in ProjectPulse:\n${projectLink}\n\n- ProjectPulse Team`,
        html: emailHtml,
      };

      await sgMail.send(emailMsg);

      // Mark notification as email sent
      await snap.ref.update({
        email_sent: true,
        email_sent_at: FieldValue.serverTimestamp(),
      });

      console.log(`Change order email sent to ${clientEmail} for project ${projectId}`);
    } catch (error) {
      console.error('Error sending change order email:', error);
      await snap.ref.update({
        email_sent: false,
        email_error: error.message,
      });
    }
  }
);

// ── 7. Milestone Started Email (to Client) ─────────────────────
exports.sendMilestoneStartedEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('❌ Milestone started: No snap');
      return;
    }
    const notificationData = snap.data();
    console.log('📧 Milestone started email triggered, type:', notificationData.type);

    if (notificationData.type !== 'milestone_started') {
      console.log('❌ Not milestone_started type:', notificationData.type);
      return;
    }
    if (notificationData.email_sent) {
      console.log('❌ Email already sent');
      return;
    }

    const apiKey = sendgridApiKey.value();
    if (!apiKey) {
      console.log('❌ No SendGrid API key');
      return;
    }
    sgMail.setApiKey(apiKey);

    try {
      const clientRef = notificationData.recipient_ref;
      if (!clientRef) {
        console.log('❌ No client ref');
        return;
      }

      const clientDoc = await clientRef.get();
      if (!clientDoc.exists) {
        console.log('❌ Client doc does not exist');
        return;
      }

      const clientData = clientDoc.data();
      const clientEmail = clientData.email;
      const clientName = clientData.name || 'there';

      if (!clientEmail) {
        console.log('❌ Client has no email');
        await snap.ref.update({ email_sent: false, email_skipped: 'no_email' });
        return;
      }

      const projectId = notificationData.data?.project_id;
      if (!projectId) {
        console.log('❌ No project_id in notification data');
        return;
      }

      console.log(`✅ Sending milestone started email to ${clientEmail}`);

      const projectDoc = await getFirestore().collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return;

      const projectData = projectDoc.data();
      const projectName = projectData.project_name || 'Your Project';
      // Updated: Link opens app to homepage (not project-specific join page)
      const projectLink = `https://projectpulse-7d258.web.app/app`;

      const contractorRef = projectData.contractor_ref;
      let contractorName = 'Your contractor';
      let contractorEmail = null;
      if (contractorRef) {
        const contractorDoc = await contractorRef.get();
        if (contractorDoc.exists) {
          const contractorData = contractorDoc.data();
          const profile = contractorData.contractor_profile;
          contractorName = profile?.business_name || contractorData.email?.split('@')[0] || 'Your contractor';
          contractorEmail = contractorData.email;
        }
      }

      const notificationBody = notificationData.body || '';
      const milestoneName = notificationBody.split(': ')[1] || 'A milestone';

      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: -apple-system, sans-serif; margin: 0; padding: 0; background: #f8f9fa; }
            .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
            .header { background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%); color: white; padding: 40px 30px; text-align: center; }
            .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
            .header p { margin: 0; opacity: 0.95; font-size: 16px; }
            .content { padding: 30px; }
            .milestone-box { background: #eff6ff; border-left: 4px solid #3B82F6; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .milestone-name { color: #1e40af; font-weight: 600; font-size: 20px; margin: 0 0 8px 0; }
            .project-name { color: #6b7280; font-size: 14px; margin: 0; }
            .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; font-size: 16px; margin: 20px 0; }
            .info-box { background: #f8f9fa; padding: 16px; border-radius: 8px; margin: 20px 0; }
            .info-box p { margin: 0 0 8px 0; font-size: 14px; color: #4b5563; }
            .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>🚀 Work Started</h1>
              <p>New milestone in progress</p>
            </div>
            <div class="content">
              <p>Hi <strong>${clientName}</strong>!</p>
              <p><strong>${contractorName}</strong> has started work on a new milestone.</p>
              <div class="milestone-box">
                <p class="milestone-name">${milestoneName}</p>
                <p class="project-name">${projectName}</p>
              </div>
              <div class="info-box">
                <p><strong>What's happening:</strong></p>
                <p>• Work is now in progress on this phase</p>
                <p>• You'll see photo updates as work progresses</p>
                <p>• You'll be notified when it's ready for approval</p>
              </div>
              <p style="text-align: center;">
                <a href="${projectLink}" class="button">View Project →</a>
              </p>
            </div>
            <div class="footer">
              <p><strong>ProjectPulse</strong> · Real-time project communication</p>
            </div>
          </div>
        </body>
        </html>
      `;

      await sgMail.send({
        to: clientEmail,
        from: { email: sendgridFromEmail.value(), name: contractorName },
        replyTo: contractorEmail || sendgridFromEmail.value(),
        subject: `🚀 Work Started: ${milestoneName}`,
        text: `Hi ${clientName}!\n\n${contractorName} has started work on: ${milestoneName}\n\nProject: ${projectName}\n\nView progress: ${projectLink}`,
        html: emailHtml,
      });

      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`Milestone started email sent to ${clientEmail}`);
    } catch (error) {
      console.error('Error sending milestone started email:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 8. Milestone Approved Email (to Contractor) ────────────────
exports.sendMilestoneApprovedEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notificationData = snap.data();

    if (notificationData.type !== 'milestone_approved') return;
    if (notificationData.email_sent) return;

    const apiKey = sendgridApiKey.value();
    if (!apiKey) return;
    sgMail.setApiKey(apiKey);

    try {
      const contractorRef = notificationData.recipient_ref;
      if (!contractorRef) return;

      const contractorDoc = await contractorRef.get();
      if (!contractorDoc.exists) return;

      const contractorData = contractorDoc.data();
      const contractorEmail = contractorData.email;
      const profile = contractorData.contractor_profile || {};
      // Extract first name only from owner_name
      const fullContractorName = profile.owner_name || 'there';
      const contractorName = fullContractorName.split(' ')[0];

      if (!contractorEmail) {
        await snap.ref.update({ email_sent: false, email_skipped: 'no_email' });
        return;
      }

      const projectId = notificationData.data?.project_id;
      if (!projectId) return;

      const projectDoc = await getFirestore().collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return;

      const projectData = projectDoc.data();
      const projectName = projectData.project_name || 'Project';
      // Extract first name only from client_name
      const fullClientName = projectData.client_name || 'Your client';
      const clientName = fullClientName.split(' ')[0];
      // Updated: Link opens app to homepage (not project-specific join page)
      const projectLink = `https://projectpulse-7d258.web.app/app`;

      const notificationBody = notificationData.body || '';
      const milestoneName = notificationBody.split(': ')[1]?.split(' -')[0] || 'Milestone';

      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: -apple-system, sans-serif; margin: 0; padding: 0; background: #f8f9fa; }
            .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
            .header { background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; padding: 40px 30px; text-align: center; }
            .header h1 { margin: 0 0 8px 0; font-size: 28px; font-weight: 700; }
            .content { padding: 30px; }
            .milestone-box { background: #f0fdf4; border-left: 4px solid #10B981; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .milestone-name { color: #065f46; font-weight: 600; font-size: 20px; margin: 0 0 8px 0; }
            .button { display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #10B981 0%, #059669 100%); color: white; text-decoration: none; border-radius: 8px; font-weight: 600; }
            .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>✓ Milestone Approved!</h1>
              <p>Payment processing</p>
            </div>
            <div class="content">
              <p>Hi <strong>${contractorName}</strong>!</p>
              <p><strong>${clientName}</strong> has approved your milestone.</p>
              <div class="milestone-box">
                <p class="milestone-name">${milestoneName}</p>
                <p style="color: #6b7280; font-size: 14px;">${projectName}</p>
              </div>
              <p>Payment will be processed and you'll receive funds within 2-3 business days.</p>
              <p style="text-align: center;">
                <a href="${projectLink}" class="button">View Project →</a>
              </p>
            </div>
            <div class="footer">
              <p><strong>ProjectPulse</strong> · Real-time project communication</p>
            </div>
          </div>
        </body>
        </html>
      `;

      await sgMail.send({
        to: contractorEmail,
        from: { email: sendgridFromEmail.value(), name: 'ProjectPulse' },
        subject: `✓ Milestone Approved: ${milestoneName}`,
        text: `Hi ${contractorName}!\n\n${clientName} approved: ${milestoneName}\n\nProject: ${projectName}\n\nPayment will be processed within 2-3 business days.\n\nView project: ${projectLink}`,
        html: emailHtml,
      });

      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`Milestone approved email sent to ${contractorEmail}`);
    } catch (error) {
      console.error('Error sending milestone approved email:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 9. Change Order Response Email (to Contractor) ─────────────
exports.sendChangeOrderResponseEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notificationData = snap.data();

    if (notificationData.type !== 'change_order_approved' && notificationData.type !== 'change_order_declined') return;
    if (notificationData.email_sent) return;

    const apiKey = sendgridApiKey.value();
    if (!apiKey) return;
    sgMail.setApiKey(apiKey);

    try {
      const contractorRef = notificationData.recipient_ref;
      if (!contractorRef) return;

      const contractorDoc = await contractorRef.get();
      if (!contractorDoc.exists) return;

      const contractorData = contractorDoc.data();
      const contractorEmail = contractorData.email;
      const profile = contractorData.contractor_profile || {};
      // Extract first name only from owner_name
      const fullContractorName = profile.owner_name || 'there';
      const contractorName = fullContractorName.split(' ')[0];

      if (!contractorEmail) {
        await snap.ref.update({ email_sent: false, email_skipped: 'no_email' });
        return;
      }

      const projectId = notificationData.data?.project_id;
      if (!projectId) return;

      const projectDoc = await getFirestore().collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return;

      const projectData = projectDoc.data();
      const projectName = projectData.project_name || 'Project';
      // Extract first name only from client_name
      const fullClientName = projectData.client_name || 'Your client';
      const clientName = fullClientName.split(' ')[0];
      // Updated: Link opens app to homepage (not project-specific join page)
      const projectLink = `https://projectpulse-7d258.web.app/app`;

      const isApproved = notificationData.type === 'change_order_approved';
      const headerColor = isApproved ? '#10B981' : '#DC2626';
      const headerGradient = isApproved
        ? 'linear-gradient(135deg, #10B981 0%, #059669 100%)'
        : 'linear-gradient(135deg, #DC2626 0%, #B91C1C 100%)';
      const headerText = isApproved ? '✓ Change Order Approved' : '✗ Change Order Declined';
      const boxBackground = isApproved ? '#f0fdf4' : '#fef2f2';
      const boxBorder = headerColor;

      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: -apple-system, sans-serif; margin: 0; padding: 0; background: #f8f9fa; }
            .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
            .header { background: ${headerGradient}; color: white; padding: 40px 30px; text-align: center; }
            .header h1 { margin: 0; font-size: 28px; font-weight: 700; }
            .content { padding: 30px; }
            .box { background: ${boxBackground}; border-left: 4px solid ${boxBorder}; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .button { display: inline-block; padding: 14px 32px; background: ${headerGradient}; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; }
            .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>${headerText}</h1>
            </div>
            <div class="content">
              <p>Hi <strong>${contractorName}</strong>!</p>
              <p><strong>${clientName}</strong> has ${isApproved ? 'approved' : 'declined'} your change order.</p>
              <div class="box">
                <p style="font-size: 16px; margin: 0;">${projectName}</p>
              </div>
              <p>${isApproved ? 'The project cost has been updated. You can proceed with the approved changes.' : 'Please contact your client to discuss alternative options.'}</p>
              <p style="text-align: center;">
                <a href="${projectLink}" class="button">View Project →</a>
              </p>
            </div>
            <div class="footer">
              <p><strong>ProjectPulse</strong> · Real-time project communication</p>
            </div>
          </div>
        </body>
        </html>
      `;

      await sgMail.send({
        to: contractorEmail,
        from: { email: sendgridFromEmail.value(), name: 'ProjectPulse' },
        subject: `${isApproved ? '✓' : '✗'} Change Order ${isApproved ? 'Approved' : 'Declined'}: ${projectName}`,
        text: `Hi ${contractorName}!\n\n${clientName} ${isApproved ? 'approved' : 'declined'} your change order for ${projectName}.\n\nView project: ${projectLink}`,
        html: emailHtml,
      });

      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`Change order response email sent to ${contractorEmail}`);
    } catch (error) {
      console.error('Error sending change order response email:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 10. Client Request Email (Quality Issue or Addition) ───────
exports.sendClientRequestEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const notificationData = snap.data();

    // Handle both quality issues and addition requests
    if (notificationData.type !== 'quality_issue_reported' && notificationData.type !== 'addition_requested') return;
    if (notificationData.email_sent) return;

    const apiKey = sendgridApiKey.value();
    if (!apiKey) return;
    sgMail.setApiKey(apiKey);

    try {
      const contractorRef = notificationData.recipient_ref;
      if (!contractorRef) return;

      const contractorDoc = await contractorRef.get();
      if (!contractorDoc.exists) return;

      const contractorData = contractorDoc.data();
      const contractorEmail = contractorData.email;
      const profile = contractorData.contractor_profile || {};
      // Extract first name only from owner_name
      const fullContractorName = profile.owner_name || 'there';
      const contractorName = fullContractorName.split(' ')[0];

      if (!contractorEmail) {
        await snap.ref.update({ email_sent: false, email_skipped: 'no_email' });
        return;
      }

      const projectId = notificationData.data?.project_id;
      if (!projectId) return;

      const projectDoc = await getFirestore().collection('projects').doc(projectId).get();
      if (!projectDoc.exists) return;

      const projectData = projectDoc.data();
      const projectName = projectData.project_name || 'Project';
      // Extract first name only from client_name
      const fullClientName = projectData.client_name || 'Your client';
      const clientName = fullClientName.split(' ')[0];
      // Updated: Link opens app to homepage (not project-specific join page)
      const projectLink = `https://projectpulse-7d258.web.app/app`;

      // Determine if quality issue or addition request
      const isQualityIssue = notificationData.type === 'quality_issue_reported';
      const headerColor = isQualityIssue ? '#F59E0B' : '#8B5CF6';
      const headerGradient = isQualityIssue
        ? 'linear-gradient(135deg, #F59E0B 0%, #D97706 100%)'
        : 'linear-gradient(135deg, #8B5CF6 0%, #7C3AED 100%)';
      const boxBackground = isQualityIssue ? '#fffbeb' : '#faf5ff';
      const boxBorder = headerColor;
      const headerIcon = isQualityIssue ? '⚠️' : '💡';
      const headerText = isQualityIssue ? 'Quality Issue Reported' : 'Addition Requested';
      const bodyText = isQualityIssue
        ? 'has reported a quality issue on your project.'
        : 'wants to add something to your project.';
      const actionText = isQualityIssue
        ? 'Please review the details in the app and respond to your client promptly.'
        : 'Please review the request and provide a quote for the addition.';
      const buttonText = isQualityIssue ? 'View Issue →' : 'View Request →';
      const emailSubject = isQualityIssue
        ? `⚠️ Quality Issue: ${projectName}`
        : `💡 Addition Request: ${projectName}`;

      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body { font-family: -apple-system, sans-serif; margin: 0; padding: 0; background: #f8f9fa; }
            .container { max-width: 600px; margin: 20px auto; background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
            .header { background: ${headerGradient}; color: white; padding: 40px 30px; text-align: center; }
            .header h1 { margin: 0; font-size: 28px; font-weight: 700; }
            .content { padding: 30px; }
            .box { background: ${boxBackground}; border-left: 4px solid ${boxBorder}; padding: 20px; margin: 20px 0; border-radius: 8px; }
            .button { display: inline-block; padding: 14px 32px; background: ${headerGradient}; color: white; text-decoration: none; border-radius: 8px; font-weight: 600; }
            .footer { background: #f8f9fa; padding: 20px 30px; text-align: center; color: #6b7280; font-size: 14px; }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="header">
              <h1>${headerIcon} ${headerText}</h1>
            </div>
            <div class="content">
              <p>Hi <strong>${contractorName}</strong>!</p>
              <p><strong>${clientName}</strong> ${bodyText}</p>
              <div class="box">
                <p style="font-size: 16px; margin: 0;">${projectName}</p>
              </div>
              <p>${actionText}</p>
              <p style="text-align: center;">
                <a href="${projectLink}" class="button">${buttonText}</a>
              </p>
            </div>
            <div class="footer">
              <p><strong>ProjectPulse</strong> · Real-time project communication</p>
            </div>
          </div>
        </body>
        </html>
      `;

      await sgMail.send({
        to: contractorEmail,
        from: { email: sendgridFromEmail.value(), name: 'ProjectPulse' },
        subject: emailSubject,
        text: `Hi ${contractorName}!\n\n${clientName} ${bodyText.replace('your project.', projectName + '.')}\n\n${actionText}\n\nView request: ${projectLink}`,
        html: emailHtml,
      });

      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`Client request email sent to ${contractorEmail} (${notificationData.type})`);
    } catch (error) {
      console.error('Error sending quality issue email:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);
