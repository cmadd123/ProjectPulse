const functions = require('firebase-functions');
const admin = require('firebase-admin');
const twilio = require('twilio');
const sgMail = require('@sendgrid/mail');

admin.initializeApp();

// Initialize Twilio and SendGrid from Firebase config
// Set these in Firebase Console → Functions → Configuration
// firebase functions:config:set twilio.account_sid="YOUR_SID" twilio.auth_token="YOUR_TOKEN" twilio.phone_number="+1234567890"
// firebase functions:config:set sendgrid.api_key="YOUR_API_KEY" sendgrid.from_email="noreply@projectpulsehub.com"
const twilioClient = functions.config().twilio ? twilio(
  functions.config().twilio.account_sid,
  functions.config().twilio.auth_token
) : null;

if (functions.config().sendgrid) {
  sgMail.setApiKey(functions.config().sendgrid.api_key);
}

/**
 * Cloud Function to send push notifications
 * Triggered when a new document is created in the 'notifications' collection
 */
exports.sendPushNotification = functions.firestore
  .document('notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();

    // Skip if already processed
    if (notificationData.processed) {
      console.log('Notification already processed, skipping');
      return null;
    }

    try {
      const { fcm_tokens, title, body, data } = notificationData;

      if (!fcm_tokens || fcm_tokens.length === 0) {
        console.log('No FCM tokens found');
        await snap.ref.update({ processed: true, error: 'No FCM tokens' });
        return null;
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
      const response = await admin.messaging().sendMulticast(message);

      console.log(`Successfully sent ${response.successCount} notifications`);
      console.log(`Failed to send ${response.failureCount} notifications`);

      // Update notification document as processed
      await snap.ref.update({
        processed: true,
        processed_at: admin.firestore.FieldValue.serverTimestamp(),
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
            fcm_tokens: admin.firestore.FieldValue.arrayRemove(...failedTokens),
          });
          console.log(`Removed ${failedTokens.length} invalid tokens`);
        }
      }

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      await snap.ref.update({
        processed: true,
        error: error.message,
      });
      return null;
    }
  });

/**
 * Clean up old notification documents (optional)
 * Runs daily to delete notifications older than 30 days
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    const thirtyDaysAgo = admin.firestore.Timestamp.fromDate(
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000)
    );

    const oldNotifications = await admin
      .firestore()
      .collection('notifications')
      .where('created_at', '<', thirtyDaysAgo)
      .limit(500)
      .get();

    const batch = admin.firestore().batch();
    let count = 0;

    oldNotifications.docs.forEach((doc) => {
      batch.delete(doc.ref);
      count++;
    });

    if (count > 0) {
      await batch.commit();
      console.log(`Deleted ${count} old notification documents`);
    }

    return null;
  });

/**
 * Send Email invitation when contractor explicitly requests it
 * Triggered when invitation_ready flag is set to true
 */
exports.sendProjectInvitation = functions.firestore
  .document('projects/{projectId}')
  .onUpdate(async (change, context) => {
    const beforeData = change.before.data();
    const afterData = change.after.data();
    const projectId = context.params.projectId;

    // Only send invitation if invitation_ready was just set to true
    if (beforeData.invitation_ready === true || afterData.invitation_ready !== true) {
      console.log('Skipping - invitation not ready or already sent');
      return null;
    }

    const projectData = afterData;

    try {
      const projectName = projectData.project_name || 'Your Project';
      const clientName = projectData.client_name || 'there';
      const clientEmail = projectData.client_email;
      const clientPhone = projectData.client_phone;
      // TODO: Update this to your custom domain once DNS is configured
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

      // Send SMS if phone number provided
      if (clientPhone && twilioClient && functions.config().twilio) {
        try {
          const smsMessage = `Hi ${clientName}! ${contractorName} created a project for you: "${projectName}"\n\nView real-time updates here: ${inviteLink}\n\n- ProjectPulse`;

          const smsResult = await twilioClient.messages.create({
            body: smsMessage,
            from: functions.config().twilio.phone_number,
            to: clientPhone,
          });

          results.sms = { success: true, sid: smsResult.sid };
          console.log(`SMS invitation sent to ${clientPhone}: ${smsResult.sid}`);
        } catch (error) {
          results.sms = { success: false, error: error.message };
          console.error(`Error sending SMS to ${clientPhone}:`, error);
        }
      }

      // Send Email if email address provided
      if (clientEmail && functions.config().sendgrid) {
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
                .button:hover {
                  box-shadow: 0 6px 8px rgba(45, 55, 72, 0.4);
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
                    <h1>🏗️ ProjectPulse</h1>
                    <p>You've been invited to view your project</p>
                  </div>
                </div>

                <div class="contractor-section">
                  <div class="contractor-content">
                    <div class="contractor-logo">
                      <span class="contractor-logo-placeholder">🏗️</span>
                      <!-- Logo image will go here: <img src="contractor_logo_url" alt="Logo" style="width: 100%; height: 100%; object-fit: cover; border-radius: 6px;"> -->
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
                    <a href="${inviteLink}" class="button">View Your Project →</a>
                  </p>

                  <div class="link-box">
                    <p style="margin: 0 0 8px 0; font-size: 13px; color: #718096;">Or copy this link:</p>
                    <code>${inviteLink}</code>
                  </div>
                </div>

                <div class="footer">
                  <p><strong>ProjectPulse</strong> · Real-time project communication</p>
                  <p style="font-size: 12px; margin-top: 8px;">Keeping contractors and clients connected</p>
                </div>
              </div>
            </body>
            </html>
          `;

          const emailMsg = {
            to: clientEmail,
            from: {
              email: functions.config().sendgrid.from_email,
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
      await snap.ref.update({
        invitation_sent: {
          sms: results.sms,
          email: results.email,
          sent_at: admin.firestore.FieldValue.serverTimestamp(),
        },
      });

      return results;
    } catch (error) {
      console.error('Error sending project invitation:', error);
      return { error: error.message };
    }
  });
