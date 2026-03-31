// 2nd Gen (v2) Cloud Functions — runs on Node 22
const { onDocumentCreated, onDocumentUpdated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { defineString, defineSecret } = require('firebase-functions/params');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const sgMail = require('@sendgrid/mail');

initializeApp();

// ── Configuration via params ─────────────────────────────────────
// Non-secret values come from functions/.env
const sendgridFromEmail = defineString('SENDGRID_FROM_EMAIL');
const stripePlatformFeePercent = defineString('STRIPE_PLATFORM_FEE_PERCENT');

// Secret values come from Cloud Secret Manager
const sendgridApiKey = defineSecret('SENDGRID_API_KEY');
const stripeSecretKey = defineSecret('STRIPE_SECRET_KEY');
const stripeWebhookSecret = defineSecret('STRIPE_WEBHOOK_SECRET');

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
                  <p><strong>${contractorName}</strong></p>
                  <p style="font-size: 12px; margin-top: 8px;">Powered by ProjectPulse</p>
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

// ── 5. Invoice Email ─────────────────────────────────────────────
// Triggered when a new invoice doc is created under a project
exports.sendInvoiceEmail = onDocumentCreated(
  {
    document: 'projects/{projectId}/invoices/{invoiceId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const invoiceData = snap.data();
    const projectId = event.params.projectId;
    const db = getFirestore();

    // Skip if already emailed (prevents re-sends and test data spam)
    if (invoiceData.emailed_at) {
      console.log('Invoice already emailed, skipping');
      return;
    }

    try {
      // Get project data for client info
      const projectDoc = await db.collection('projects').doc(projectId).get();
      if (!projectDoc.exists) {
        console.error('Project not found:', projectId);
        return;
      }
      const projectData = projectDoc.data();
      const clientEmail = projectData.client_email;
      if (!clientEmail) {
        console.log('No client email on project, skipping invoice email');
        return;
      }

      const apiKey = sendgridApiKey.value();
      if (!apiKey) {
        console.error('SendGrid API key not configured');
        return;
      }
      sgMail.setApiKey(apiKey);

      // Get contractor name and email
      let contractorName = 'Your contractor';
      let contractorEmail = null;
      if (projectData.contractor_ref) {
        const contractorDoc = await projectData.contractor_ref.get();
        if (contractorDoc.exists) {
          const cd = contractorDoc.data();
          contractorName = cd.contractor_profile?.business_name || cd.email?.split('@')[0] || 'Your contractor';
          contractorEmail = cd.email || null;
        }
      }

      const clientName = projectData.client_name || 'there';
      const projectName = projectData.project_name || 'Your Project';
      const invoiceNumber = invoiceData.invoice_number || 'Invoice';
      const milestoneName = invoiceData.milestone_name || 'Milestone';
      const amount = invoiceData.amount || 0;
      const fee = invoiceData.transaction_fee || 0;
      const totalDue = invoiceData.total_due || amount + fee;
      const pdfUrl = invoiceData.pdf_url || '';

      const fmtAmount = `$${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
      const fmtTotal = `$${Number(totalDue).toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
      const fmtFee = `$${Number(fee).toLocaleString('en-US', { minimumFractionDigits: 2 })}`;

      const emailHtml = `
        <!DOCTYPE html>
        <html>
        <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
        </head>
        <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f8f9fa;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; padding: 20px 0;">
            <tr><td align="center">
              <table width="600" cellpadding="0" cellspacing="0" style="background: white; border-radius: 12px; overflow: hidden;">
                <!-- Header -->
                <tr>
                  <td style="background: linear-gradient(135deg, #2D3748 0%, #FF6B35 100%); color: white; padding: 30px; text-align: center;">
                    <h1 style="margin: 0; font-size: 24px;">${invoiceNumber}</h1>
                    <p style="margin: 8px 0 0; opacity: 0.9; font-size: 14px;">From ${contractorName}</p>
                  </td>
                </tr>
                <!-- Body -->
                <tr>
                  <td style="padding: 30px;">
                    <p>Hi ${clientName},</p>
                    <p>A new invoice has been generated for your approved milestone on <strong>${projectName}</strong>.</p>
                    <!-- Invoice Box -->
                    <table width="100%" cellpadding="0" cellspacing="0" style="background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 8px; margin: 20px 0;">
                      <tr>
                        <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; color: #718096; font-size: 14px;">Milestone</td>
                        <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; font-weight: 600; font-size: 14px; text-align: right;">${milestoneName}</td>
                      </tr>
                      <tr>
                        <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; color: #718096; font-size: 14px;">Amount</td>
                        <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; font-weight: 600; font-size: 14px; text-align: right;">${fmtAmount}</td>
                      </tr>
                      <tr>
                        <td style="padding: 12px 20px; color: #718096; font-size: 14px;">Payment Processing Fee</td>
                        <td style="padding: 12px 20px; font-weight: 600; font-size: 14px; text-align: right;">${fmtFee}</td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding: 4px 12px 12px;">
                          <table width="100%" cellpadding="0" cellspacing="0" style="background: #2D3748; border-radius: 6px;">
                            <tr>
                              <td style="padding: 12px 16px; color: white; font-size: 14px;">Total Due</td>
                              <td style="padding: 12px 16px; color: white; font-size: 20px; font-weight: 700; text-align: right;">${fmtTotal}</td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>
                    <p>Please contact ${contractorName} for accepted payment methods.</p>
                    ${pdfUrl ? `<p style="text-align:center;"><a href="${pdfUrl}" style="display: inline-block; background: #FF6B35; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; margin-top: 20px;">Download Invoice PDF</a></p>` : ''}
                  </td>
                </tr>
                <!-- Footer -->
                <tr>
                  <td style="text-align: center; padding: 20px; color: #a0aec0; font-size: 12px;">
                    <p style="margin: 0;">Powered by ProjectPulse</p>
                  </td>
                </tr>
              </table>
            </td></tr>
          </table>
        </body>
        </html>
      `;

      const emailMsg = {
        to: clientEmail,
        from: {
          email: sendgridFromEmail.value(),
          name: contractorName,
        },
        replyTo: projectData.contractor_email || sendgridFromEmail.value(),
        subject: `Invoice ${invoiceNumber} - ${milestoneName} | ${projectName}`,
        html: emailHtml,
        trackingSettings: {
          clickTracking: { enable: false, enableText: false },
        },
      };

      await sgMail.send(emailMsg);
      console.log(`✅ Invoice email sent to client ${clientEmail} for ${invoiceNumber}`);

      // Send confirmation email to contractor/GC
      if (contractorEmail) {
        const gcEmailHtml = `
          <!DOCTYPE html>
          <html>
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
          </head>
          <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; background-color: #f8f9fa;">
            <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #f8f9fa; padding: 20px 0;">
              <tr><td align="center">
                <table width="600" cellpadding="0" cellspacing="0" style="background: white; border-radius: 12px; overflow: hidden;">
                  <!-- Header -->
                  <tr>
                    <td style="background: linear-gradient(135deg, #2D3748 0%, #10B981 100%); color: white; padding: 30px; text-align: center;">
                      <h1 style="margin: 0; font-size: 24px;">Invoice Sent</h1>
                      <p style="margin: 8px 0 0; opacity: 0.9; font-size: 14px;">${invoiceNumber}</p>
                    </td>
                  </tr>
                  <!-- Body -->
                  <tr>
                    <td style="padding: 30px;">
                      <p>Hi ${contractorName},</p>
                      <p>An invoice has been sent to <strong>${clientName}</strong> for the approved milestone on <strong>${projectName}</strong>.</p>
                      <!-- Invoice Box -->
                      <table width="100%" cellpadding="0" cellspacing="0" style="background: #f7fafc; border: 1px solid #e2e8f0; border-radius: 8px; margin: 20px 0;">
                        <tr>
                          <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; color: #718096; font-size: 14px;">Milestone</td>
                          <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; font-weight: 600; font-size: 14px; text-align: right;">${milestoneName}</td>
                        </tr>
                        <tr>
                          <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; color: #718096; font-size: 14px;">Amount</td>
                          <td style="padding: 12px 20px; border-bottom: 1px solid #e2e8f0; font-weight: 600; font-size: 14px; text-align: right;">${fmtAmount}</td>
                        </tr>
                        <tr>
                          <td style="padding: 12px 20px; color: #718096; font-size: 14px;">Payment Processing Fee</td>
                          <td style="padding: 12px 20px; font-weight: 600; font-size: 14px; text-align: right;">${fmtFee}</td>
                        </tr>
                        <tr>
                          <td colspan="2" style="padding: 4px 12px 12px;">
                            <table width="100%" cellpadding="0" cellspacing="0" style="background: #10B981; border-radius: 6px;">
                              <tr>
                                <td style="padding: 12px 16px; color: white; font-size: 14px;">Total Due</td>
                                <td style="padding: 12px 16px; color: white; font-size: 20px; font-weight: 700; text-align: right;">${fmtTotal}</td>
                              </tr>
                            </table>
                          </td>
                        </tr>
                      </table>
                      <p>The client has been notified at <strong>${clientEmail}</strong>.</p>
                      ${pdfUrl ? `<p style="text-align:center;"><a href="${pdfUrl}" style="display: inline-block; background: #FF6B35; color: white; padding: 14px 32px; border-radius: 8px; text-decoration: none; font-weight: 600; margin-top: 20px;">Download Invoice PDF</a></p>` : ''}
                    </td>
                  </tr>
                  <!-- Footer -->
                  <tr>
                    <td style="text-align: center; padding: 20px; color: #a0aec0; font-size: 12px;">
                      <p style="margin: 0;">Powered by ProjectPulse</p>
                    </td>
                  </tr>
                </table>
              </td></tr>
            </table>
          </body>
          </html>
        `;

        const gcMsg = {
          to: contractorEmail,
          from: {
            email: sendgridFromEmail.value(),
            name: 'ProjectPulse',
          },
          subject: `Invoice Sent: ${invoiceNumber} - ${milestoneName} | ${projectName}`,
          html: gcEmailHtml,
          trackingSettings: {
            clickTracking: { enable: false, enableText: false },
          },
        };

        await sgMail.send(gcMsg);
        console.log(`✅ Invoice confirmation email sent to GC ${contractorEmail}`);
      } else {
        console.log('No contractor email found, skipping GC notification');
      }

      // Mark invoice as emailed
      await snap.ref.update({ emailed_at: FieldValue.serverTimestamp() });
    } catch (error) {
      console.error(`❌ Error sending invoice email:`, error);
    }
  }
);

// ── Shared helpers for notification-triggered emails ─────────────
async function getEmailContext(notificationData) {
  const db = getFirestore();
  const result = { skip: true };

  if (notificationData.email_sent) return result;

  const apiKey = sendgridApiKey.value();
  if (!apiKey) return result;
  sgMail.setApiKey(apiKey);

  const projectId = notificationData.data?.project_id;
  if (!projectId) return result;

  const projectDoc = await db.collection('projects').doc(projectId).get();
  if (!projectDoc.exists) return result;
  const projectData = projectDoc.data();

  // Get contractor info
  let contractorName = 'Your contractor';
  let contractorEmail = null;
  let contractorPhone = null;
  const contractorRef = projectData.contractor_ref;
  if (contractorRef) {
    const contractorDoc = await contractorRef.get();
    if (contractorDoc.exists) {
      const cd = contractorDoc.data();
      const profile = cd.contractor_profile || {};
      contractorName = profile.business_name || cd.email?.split('@')[0] || 'Your contractor';
      contractorEmail = cd.email || null;
      contractorPhone = profile.phone || null;
    }
  }

  // Get client info
  let clientEmail = null;
  let clientName = 'there';
  const clientRef = notificationData.recipient_ref || projectData.client_user_ref;
  if (clientRef) {
    const clientDoc = await clientRef.get();
    if (clientDoc.exists) {
      const cd = clientDoc.data();
      clientEmail = cd.email || null;
      clientName = (projectData.client_name || cd.name || 'there').split(' ')[0];
    }
  }

  // For GC-facing emails, recipient is the contractor
  let recipientEmail = clientEmail;
  let recipientName = clientName;
  if (notificationData.recipient_ref && contractorRef &&
      notificationData.recipient_ref.path === contractorRef.path) {
    recipientEmail = contractorEmail;
    const profile = (await contractorRef.get()).data()?.contractor_profile || {};
    recipientName = (profile.owner_name || 'there').split(' ')[0];
  }

  const projectName = projectData.project_name || 'Your Project';
  const projectLink = `https://projectpulsehub.com/join/${projectId}`;

  return {
    skip: false,
    projectId, projectName, projectLink, projectData,
    contractorName, contractorEmail, contractorPhone,
    clientEmail, clientName,
    recipientEmail, recipientName,
  };
}

function buildFooter(contractorName, contractorEmail, contractorPhone) {
  let contactLine = '';
  if (contractorPhone || contractorEmail) {
    const parts = [];
    if (contractorPhone) parts.push(contractorPhone);
    if (contractorEmail) parts.push(contractorEmail);
    contactLine = `<p style="margin: 4px 0 0;">${parts.join(' · ')}</p>`;
  }
  return `
    <div style="text-align: center; padding: 24px; background: #f8f9fa; border-top: 1px solid #e2e8f0;">
      <p style="margin: 0; color: #2D3748; font-weight: 600; font-size: 14px;">${contractorName}</p>
      ${contactLine ? `<div style="color: #718096; font-size: 13px;">${contactLine}</div>` : ''}
      <p style="margin: 12px 0 0; color: #a0aec0; font-size: 11px;">Powered by ProjectPulse</p>
    </div>
  `;
}

function buildContractorHeader(contractorName) {
  return `
    <div style="background: #f8f9fa; padding: 16px 30px; border-bottom: 1px solid #e2e8f0;">
      <table cellpadding="0" cellspacing="0"><tr>
        <td style="width: 44px; height: 44px; background: #e9ecef; border-radius: 8px; text-align: center; vertical-align: middle; border: 1px solid #dee2e6;">
          <span style="font-size: 22px;">&#128679;</span>
        </td>
        <td style="padding-left: 12px;">
          <p style="margin: 0; color: #718096; font-size: 12px;">Your Contractor</p>
          <p style="margin: 0; color: #2D3748; font-weight: 600; font-size: 16px;">${contractorName}</p>
        </td>
      </tr></table>
    </div>
  `;
}

function wrapEmail(headerGradient, headerTitle, headerSubtitle, bodyHtml, footer) {
  return `<!DOCTYPE html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"></head>
  <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 0; background: #f8f9fa;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background: #f8f9fa; padding: 20px 0;"><tr><td align="center">
      <table width="600" cellpadding="0" cellspacing="0" style="background: white; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
        <tr><td style="background: ${headerGradient}; color: white; padding: 36px 30px; text-align: center;">
          <h1 style="margin: 0 0 6px; font-size: 24px; font-weight: 700;">${headerTitle}</h1>
          ${headerSubtitle ? `<p style="margin: 0; opacity: 0.95; font-size: 15px;">${headerSubtitle}</p>` : ''}
        </td></tr>
        <tr><td>${bodyHtml}</td></tr>
        <tr><td>${footer}</td></tr>
      </table>
    </td></tr></table>
  </body></html>`;
}

// ── 6. Milestone Completed Email (to Client) ─────────────────────
exports.sendMilestoneEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'milestone_completed') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.clientEmail) return;

    const milestoneName = (nd.body || '').split(': ')[1] || 'A milestone';
    const footer = buildFooter(ctx.contractorName, ctx.contractorEmail, ctx.contractorPhone);
    const contractorSection = buildContractorHeader(ctx.contractorName);

    const body = `
      ${contractorSection}
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${ctx.clientName}</strong>!</p>
        <p>${ctx.contractorName} has marked a milestone as complete on your project.</p>
        <div style="background: #f0fdf4; border-left: 4px solid #10B981; padding: 18px; margin: 20px 0; border-radius: 8px;">
          <p style="color: #065f46; font-weight: 600; font-size: 18px; margin: 0 0 4px;">${milestoneName}</p>
          <p style="color: #6b7280; font-size: 14px; margin: 0;">${ctx.projectName}</p>
        </div>
        <div style="background: #f8f9fa; padding: 14px; border-radius: 8px; margin: 16px 0;">
          <p style="margin: 0 0 6px; font-size: 14px; color: #374151;"><strong>What happens next?</strong></p>
          <p style="margin: 0; font-size: 13px; color: #4b5563;">Review the work and photos, then approve the milestone. Payment will be processed upon approval.</p>
        </div>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #10B981, #059669); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">Review &amp; Approve &rarr;</a>
        </p>
      </div>
    `;

    const html = wrapEmail('linear-gradient(135deg, #10B981, #059669)', '&#10003; Milestone Completed', 'Ready for your approval', body, footer);

    try {
      await sgMail.send({
        to: ctx.clientEmail,
        from: { email: sendgridFromEmail.value(), name: ctx.contractorName },
        replyTo: ctx.contractorEmail || sendgridFromEmail.value(),
        subject: `✓ Milestone Complete: ${milestoneName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Milestone email sent to ${ctx.clientEmail}`);
    } catch (error) {
      console.error('❌ Milestone email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 7. Milestone Started Email (to Client) ───────────────────────
exports.sendMilestoneStartedEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'milestone_started') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.clientEmail) return;

    const milestoneName = (nd.body || '').split(': Started working on "')[1]?.replace('"', '') || (nd.body || '').split(': ')[1] || 'A milestone';
    const footer = buildFooter(ctx.contractorName, ctx.contractorEmail, ctx.contractorPhone);
    const contractorSection = buildContractorHeader(ctx.contractorName);

    const body = `
      ${contractorSection}
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${ctx.clientName}</strong>!</p>
        <p>${ctx.contractorName} has started work on a new phase of your project.</p>
        <div style="background: #eff6ff; border-left: 4px solid #3B82F6; padding: 18px; margin: 20px 0; border-radius: 8px;">
          <p style="color: #1e40af; font-weight: 600; font-size: 18px; margin: 0 0 4px;">${milestoneName}</p>
          <p style="color: #6b7280; font-size: 14px; margin: 0;">${ctx.projectName}</p>
        </div>
        <div style="background: #f8f9fa; padding: 14px; border-radius: 8px; margin: 16px 0;">
          <p style="margin: 0; font-size: 13px; color: #4b5563;">You'll see photo updates as work progresses and be notified when it's ready for approval.</p>
        </div>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #3B82F6, #2563EB); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">View Project &rarr;</a>
        </p>
      </div>
    `;

    const html = wrapEmail('linear-gradient(135deg, #3B82F6, #2563EB)', '&#128640; Work Started', 'New milestone in progress', body, footer);

    try {
      await sgMail.send({
        to: ctx.clientEmail,
        from: { email: sendgridFromEmail.value(), name: ctx.contractorName },
        replyTo: ctx.contractorEmail || sendgridFromEmail.value(),
        subject: `🚀 Work Started: ${milestoneName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Milestone started email sent to ${ctx.clientEmail}`);
    } catch (error) {
      console.error('❌ Milestone started email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 8. Milestone Approved Email (to Contractor) ──────────────────
exports.sendMilestoneApprovedEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'milestone_approved') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.contractorEmail) return;

    const gcName = ctx.recipientName;
    const milestoneName = (nd.body || '').split(': ')[1]?.split(' -')[0] || 'Milestone';

    const body = `
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${gcName}</strong>!</p>
        <p><strong>${ctx.clientName}</strong> has approved your milestone.</p>
        <div style="background: #f0fdf4; border-left: 4px solid #10B981; padding: 18px; margin: 20px 0; border-radius: 8px;">
          <p style="color: #065f46; font-weight: 600; font-size: 18px; margin: 0 0 4px;">${milestoneName}</p>
          <p style="color: #6b7280; font-size: 14px; margin: 0;">${ctx.projectName}</p>
        </div>
        <p>An invoice has been generated and sent to the client.</p>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #10B981, #059669); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">View Project &rarr;</a>
        </p>
      </div>
    `;

    const html = wrapEmail('linear-gradient(135deg, #10B981, #059669)', '&#10003; Milestone Approved!', 'Invoice sent to client', body,
      `<div style="text-align: center; padding: 20px; color: #a0aec0; font-size: 11px;"><p style="margin:0;">Powered by ProjectPulse</p></div>`);

    try {
      await sgMail.send({
        to: ctx.contractorEmail,
        from: { email: sendgridFromEmail.value(), name: 'ProjectPulse' },
        subject: `✓ Milestone Approved: ${milestoneName} — ${ctx.projectName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Milestone approved email sent to ${ctx.contractorEmail}`);
    } catch (error) {
      console.error('❌ Milestone approved email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 9. Change Order Email (to Client) ────────────────────────────
exports.sendChangeOrderEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'change_order') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.clientEmail) return;

    const notifBody = nd.body || '';
    const parts = notifBody.split(': ');
    const descAndCost = parts.slice(1).join(': ');
    const lastParen = descAndCost.lastIndexOf('(');
    let description = descAndCost;
    let costChange = '';
    if (lastParen !== -1) {
      description = descAndCost.substring(0, lastParen).trim();
      costChange = descAndCost.substring(lastParen + 1, descAndCost.length - 1);
    }

    const isIncrease = costChange.startsWith('+') || !costChange.startsWith('-');
    const accentColor = isIncrease ? '#DC2626' : '#10B981';
    const bgColor = isIncrease ? '#fef2f2' : '#f0fdf4';
    const gradient = isIncrease ? 'linear-gradient(135deg, #DC2626, #B91C1C)' : 'linear-gradient(135deg, #10B981, #059669)';

    const footer = buildFooter(ctx.contractorName, ctx.contractorEmail, ctx.contractorPhone);
    const contractorSection = buildContractorHeader(ctx.contractorName);

    const body = `
      ${contractorSection}
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${ctx.clientName}</strong>!</p>
        <p>${ctx.contractorName} has submitted a change order for your project.</p>
        <div style="background: ${bgColor}; border-left: 4px solid ${accentColor}; padding: 18px; margin: 20px 0; border-radius: 8px;">
          ${costChange ? `<p style="color: ${accentColor}; font-weight: 700; font-size: 22px; margin: 0 0 8px;">${costChange}</p>` : ''}
          <p style="color: #374151; font-size: 15px; margin: 0 0 4px;">${description}</p>
          <p style="color: #6b7280; font-size: 13px; margin: 0;">${ctx.projectName}</p>
        </div>
        <div style="background: #f8f9fa; padding: 14px; border-radius: 8px; margin: 16px 0;">
          <p style="margin: 0; font-size: 13px; color: #4b5563;">Review the details and approve or decline. Your project cost will be adjusted if approved.</p>
        </div>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: ${gradient}; color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">Review Change Order &rarr;</a>
        </p>
      </div>
    `;

    const headerTitle = isIncrease ? 'Change Order' : 'Change Order';
    const html = wrapEmail(gradient, headerTitle, 'Action required', body, footer);

    try {
      await sgMail.send({
        to: ctx.clientEmail,
        from: { email: sendgridFromEmail.value(), name: ctx.contractorName },
        replyTo: ctx.contractorEmail || sendgridFromEmail.value(),
        subject: `Change Order: ${ctx.projectName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Change order email sent to ${ctx.clientEmail}`);
    } catch (error) {
      console.error('❌ Change order email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 10. Change Order Response Email (to Contractor) ──────────────
exports.sendChangeOrderResponseEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'change_order_approved' && nd.type !== 'change_order_declined') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.contractorEmail) return;

    const gcName = ctx.recipientName;
    const isApproved = nd.type === 'change_order_approved';
    const gradient = isApproved ? 'linear-gradient(135deg, #10B981, #059669)' : 'linear-gradient(135deg, #DC2626, #B91C1C)';
    const symbol = isApproved ? '&#10003;' : '&#10007;';
    const action = isApproved ? 'Approved' : 'Declined';

    const body = `
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${gcName}</strong>!</p>
        <p><strong>${ctx.clientName}</strong> has ${isApproved ? 'approved' : 'declined'} your change order.</p>
        <div style="background: ${isApproved ? '#f0fdf4' : '#fef2f2'}; border-left: 4px solid ${isApproved ? '#10B981' : '#DC2626'}; padding: 18px; margin: 20px 0; border-radius: 8px;">
          <p style="font-size: 16px; margin: 0;">${ctx.projectName}</p>
        </div>
        <p>${isApproved ? 'The project cost has been updated. You can proceed with the approved changes.' : 'Please contact your client to discuss alternative options.'}</p>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: ${gradient}; color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">View Project &rarr;</a>
        </p>
      </div>
    `;

    const html = wrapEmail(gradient, `${symbol} Change Order ${action}`, '', body,
      `<div style="text-align: center; padding: 20px; color: #a0aec0; font-size: 11px;"><p style="margin:0;">Powered by ProjectPulse</p></div>`);

    try {
      await sgMail.send({
        to: ctx.contractorEmail,
        from: { email: sendgridFromEmail.value(), name: 'ProjectPulse' },
        subject: `${isApproved ? '✓' : '✗'} Change Order ${action}: ${ctx.projectName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Change order response email sent to ${ctx.contractorEmail}`);
    } catch (error) {
      console.error('❌ Change order response email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 11. Client Request Email (Quality Issue / Addition → Contractor) ─
exports.sendClientRequestEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'quality_issue_reported' && nd.type !== 'addition_requested') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.contractorEmail) return;

    const gcName = ctx.recipientName;
    const isQuality = nd.type === 'quality_issue_reported';
    const gradient = isQuality ? 'linear-gradient(135deg, #F59E0B, #D97706)' : 'linear-gradient(135deg, #8B5CF6, #7C3AED)';
    const icon = isQuality ? '&#9888;&#65039;' : '&#128161;';
    const title = isQuality ? 'Quality Issue Reported' : 'Addition Requested';
    const actionText = isQuality
      ? 'Please review the details and respond to your client promptly.'
      : 'Please review the request and provide a quote.';

    const body = `
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${gcName}</strong>!</p>
        <p><strong>${ctx.clientName}</strong> ${isQuality ? 'has reported a quality issue on' : 'wants to add something to'} your project.</p>
        <div style="background: ${isQuality ? '#fffbeb' : '#faf5ff'}; border-left: 4px solid ${isQuality ? '#F59E0B' : '#8B5CF6'}; padding: 18px; margin: 20px 0; border-radius: 8px;">
          <p style="font-size: 16px; margin: 0;">${ctx.projectName}</p>
        </div>
        <p>${actionText}</p>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: ${gradient}; color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">${isQuality ? 'View Issue' : 'View Request'} &rarr;</a>
        </p>
      </div>
    `;

    const html = wrapEmail(gradient, `${icon} ${title}`, '', body,
      `<div style="text-align: center; padding: 20px; color: #a0aec0; font-size: 11px;"><p style="margin:0;">Powered by ProjectPulse</p></div>`);

    try {
      await sgMail.send({
        to: ctx.contractorEmail,
        from: { email: sendgridFromEmail.value(), name: 'ProjectPulse' },
        subject: `${isQuality ? '⚠️ Quality Issue' : '💡 Addition Request'}: ${ctx.projectName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Client request email sent to ${ctx.contractorEmail}`);
    } catch (error) {
      console.error('❌ Client request email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 12. Milestone Schedule Created Email (to Client) ─────────────
exports.sendScheduleCreatedEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'milestone_schedule_created') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.clientEmail) return;

    const footer = buildFooter(ctx.contractorName, ctx.contractorEmail, ctx.contractorPhone);
    const contractorSection = buildContractorHeader(ctx.contractorName);

    // Extract milestone count from body: "ProjectName: Contractor created X milestones..."
    const countMatch = (nd.body || '').match(/(\d+) milestone/);
    const count = countMatch ? countMatch[1] : 'several';

    const body = `
      ${contractorSection}
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${ctx.clientName}</strong>!</p>
        <p>${ctx.contractorName} has created a ${count}-phase plan for your project.</p>
        <div style="background: #eff6ff; border-left: 4px solid #3B82F6; padding: 18px; margin: 20px 0; border-radius: 8px;">
          <p style="color: #1e40af; font-weight: 600; font-size: 18px; margin: 0 0 4px;">${ctx.projectName}</p>
          <p style="color: #6b7280; font-size: 14px; margin: 0;">${count} milestones planned</p>
        </div>
        <p>Open the app to see the full timeline, costs per phase, and track progress as work begins.</p>
        <p style="text-align: center;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #3B82F6, #2563EB); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">View Your Timeline &rarr;</a>
        </p>
      </div>
    `;

    const html = wrapEmail('linear-gradient(135deg, #3B82F6, #2563EB)', '&#128197; Your Project Timeline', 'is ready to review', body, footer);

    try {
      await sgMail.send({
        to: ctx.clientEmail,
        from: { email: sendgridFromEmail.value(), name: ctx.contractorName },
        replyTo: ctx.contractorEmail || sendgridFromEmail.value(),
        subject: `Your project timeline is ready — ${ctx.projectName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Schedule created email sent to ${ctx.clientEmail}`);
    } catch (error) {
      console.error('❌ Schedule created email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 13. Project Completed Email (to Client) ──────────────────────
exports.sendProjectCompletedEmail = onDocumentCreated(
  { document: 'notifications/{notificationId}', secrets: [sendgridApiKey] },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const nd = snap.data();
    if (nd.type !== 'project_completed') return;

    const ctx = await getEmailContext(nd);
    if (ctx.skip || !ctx.clientEmail) return;

    const footer = buildFooter(ctx.contractorName, ctx.contractorEmail, ctx.contractorPhone);
    const contractorSection = buildContractorHeader(ctx.contractorName);

    const body = `
      ${contractorSection}
      <div style="padding: 30px;">
        <p style="margin: 0 0 12px;">Hi <strong>${ctx.clientName}</strong>!</p>
        <p>Congratulations — your project with ${ctx.contractorName} is complete!</p>
        <div style="background: #f0fdf4; border-left: 4px solid #10B981; padding: 18px; margin: 20px 0; border-radius: 8px; text-align: center;">
          <p style="font-size: 36px; margin: 0 0 8px;">&#127881;</p>
          <p style="color: #065f46; font-weight: 700; font-size: 20px; margin: 0 0 4px;">${ctx.projectName}</p>
          <p style="color: #6b7280; font-size: 14px; margin: 0;">All milestones completed</p>
        </div>
        <p>All photos, invoices, and project details are saved in the app for your records.</p>
        <p style="text-align: center; margin: 24px 0 8px;">
          <a href="${ctx.projectLink}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #10B981, #059669); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">View Completed Project &rarr;</a>
        </p>
        <p style="text-align: center; font-size: 13px; color: #6b7280;">Had a great experience? Tell a friend about ${ctx.contractorName}!</p>
      </div>
    `;

    const html = wrapEmail('linear-gradient(135deg, #10B981, #059669)', '&#127881; Project Complete!', 'Congratulations!', body, footer);

    try {
      await sgMail.send({
        to: ctx.clientEmail,
        from: { email: sendgridFromEmail.value(), name: ctx.contractorName },
        replyTo: ctx.contractorEmail || sendgridFromEmail.value(),
        subject: `🎉 Project Complete: ${ctx.projectName}`,
        html,
        trackingSettings: { clickTracking: { enable: false, enableText: false } },
      });
      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Project completed email sent to ${ctx.clientEmail}`);
    } catch (error) {
      console.error('❌ Project completed email error:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);

// ── 14. Stripe: Create PaymentIntent ─────────────────────────────
// Called from the client app to get a client secret for the Payment Sheet
exports.createPaymentIntent = onRequest(
  { secrets: [stripeSecretKey], cors: true },
  async (req, res) => {
    if (req.method !== 'POST') {
      res.status(405).send('Method not allowed');
      return;
    }

    try {
      const stripe = require('stripe')(stripeSecretKey.value());
      const { projectId, invoiceId, amount, milestoneName, clientEmail, contractorName } = req.body;

      if (!projectId || !invoiceId || !amount) {
        res.status(400).json({ error: 'Missing required fields' });
        return;
      }

      const milestoneAmount = parseFloat(amount);
      const platformFeePercent = parseFloat(stripePlatformFeePercent.value() || '2.0');
      const stripeFeePercent = 2.9;
      const stripeFeeFixed = 0.30;
      const totalFeePercent = stripeFeePercent + platformFeePercent;

      const processingFee = Math.round((milestoneAmount * totalFeePercent / 100 + stripeFeeFixed) * 100) / 100;
      const totalChargeCents = Math.round((milestoneAmount + processingFee) * 100);

      // Create or reuse a Stripe customer
      let customerId;
      if (clientEmail) {
        const existing = await stripe.customers.list({ email: clientEmail, limit: 1 });
        if (existing.data.length > 0) {
          customerId = existing.data[0].id;
        } else {
          const customer = await stripe.customers.create({ email: clientEmail });
          customerId = customer.id;
        }
      }

      // Create ephemeral key for the customer (required by Payment Sheet)
      let ephemeralKey;
      if (customerId) {
        ephemeralKey = await stripe.ephemeralKeys.create(
          { customer: customerId },
          { apiVersion: '2024-06-20' },
        );
      }

      // Create PaymentIntent
      const paymentIntent = await stripe.paymentIntents.create({
        amount: totalChargeCents,
        currency: 'usd',
        customer: customerId || undefined,
        metadata: {
          projectId,
          invoiceId,
          milestoneAmount: milestoneAmount.toString(),
          processingFee: processingFee.toString(),
          platformFeePercent: platformFeePercent.toString(),
          milestoneName: milestoneName || '',
        },
        automatic_payment_methods: { enabled: true },
      });

      // Save to invoice doc (non-blocking)
      try {
        await getFirestore()
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .update({
            'stripe_payment_intent_id': paymentIntent.id,
            'processing_fee': processingFee,
          });
      } catch (updateErr) {
        console.log('⚠️ Could not update invoice doc:', updateErr.message);
      }

      console.log(`✅ PaymentIntent created: ${paymentIntent.id} for $${(totalChargeCents / 100).toFixed(2)}`);
      res.json({
        clientSecret: paymentIntent.client_secret,
        customerId: customerId,
        ephemeralKey: ephemeralKey?.secret,
        paymentIntentId: paymentIntent.id,
        milestoneAmount: milestoneAmount,
        processingFee: processingFee,
        totalCharge: totalChargeCents / 100,
      });
    } catch (error) {
      console.error('❌ PaymentIntent error:', error);
      res.status(500).json({ error: error.message });
    }
  }
);

// ── 15. Stripe: Webhook (payment confirmation) ──────────────────
// Stripe sends events here after payment succeeds/fails
exports.stripeWebhook = onRequest(
  { secrets: [stripeSecretKey, stripeWebhookSecret] },
  async (req, res) => {
    const stripe = require('stripe')(stripeSecretKey.value());
    const db = getFirestore();

    let event;
    try {
      const sig = req.headers['stripe-signature'];
      event = stripe.webhooks.constructEvent(req.rawBody, sig, stripeWebhookSecret.value());
    } catch (err) {
      console.error('❌ Webhook signature verification failed:', err);
      res.status(400).send(`Webhook Error: ${err.message}`);
      return;
    }

    if (event.type === 'payment_intent.succeeded') {
      const paymentIntent = event.data.object;
      const { projectId, invoiceId, milestoneAmount, processingFee, platformFeePercent } = paymentIntent.metadata || {};

      if (!projectId || !invoiceId) {
        console.log('❌ Missing metadata in checkout session');
        res.status(200).send('OK - missing metadata');
        return;
      }

      try {
        // Mark invoice as paid via Stripe
        await db
          .collection('projects')
          .doc(projectId)
          .collection('invoices')
          .doc(invoiceId)
          .update({
            'status': 'paid',
            'paid_at': FieldValue.serverTimestamp(),
            'payment_method': 'stripe',
            'payment_intent_id': paymentIntent.id,
            'processing_fee': parseFloat(processingFee || '0'),
            'platform_fee_percent': parseFloat(platformFeePercent || '2.0'),
            'amount_charged': paymentIntent.amount / 100,
          });

        // Notify GC
        const projectDoc = await db.collection('projects').doc(projectId).get();
        if (projectDoc.exists) {
          const projectData = projectDoc.data();
          const contractorRef = projectData.contractor_ref;
          if (contractorRef) {
            const contractorDoc = await contractorRef.get();
            const fcmTokens = contractorDoc.data()?.fcm_tokens || [];
            if (fcmTokens.length > 0) {
              const invoiceDoc = await db.collection('projects').doc(projectId).collection('invoices').doc(invoiceId).get();
              const milestoneName = invoiceDoc.data()?.milestone_name || 'Milestone';
              const amount = parseFloat(milestoneAmount || '0');

              await db.collection('notifications').add({
                type: 'payment_received',
                recipient_ref: contractorRef,
                recipient_uid: contractorRef.id,
                fcm_tokens: fcmTokens,
                title: 'Payment Received!',
                body: `$${amount.toLocaleString()} received for ${milestoneName}`,
                data: {
                  project_id: projectId,
                  type: 'payment_received',
                },
                created_at: FieldValue.serverTimestamp(),
                processed: false,
                read: false,
              });
            }
          }
        }

        console.log(`✅ Payment confirmed for invoice ${invoiceId}: $${session.amount_total / 100}`);
      } catch (error) {
        console.error('❌ Error processing payment webhook:', error);
      }
    }

    res.status(200).send('OK');
  }
);

// ── 16. Invoice Payment Reminder (daily check) ──────────────────
// Sends reminder email for invoices unpaid after 3 days
exports.sendPaymentReminders = onSchedule(
  { schedule: 'every 24 hours', secrets: [sendgridApiKey] },
  async () => {
    const db = getFirestore();
    const threeDaysAgo = Timestamp.fromDate(
      new Date(Date.now() - 3 * 24 * 60 * 60 * 1000)
    );

    // Find all unpaid invoices older than 3 days
    const projectsSnap = await db.collection('projects').get();
    let remindersSent = 0;

    for (const projectDoc of projectsSnap.docs) {
      const projectData = projectDoc.data();
      const clientEmail = projectData.client_email;
      if (!clientEmail) continue;

      const invoicesSnap = await projectDoc.ref
        .collection('invoices')
        .where('status', '==', 'sent')
        .get();

      for (const invoiceDoc of invoicesSnap.docs) {
        const invoiceData = invoiceDoc.data();
        const createdAt = invoiceData.created_at;
        if (!createdAt || createdAt > threeDaysAgo) continue;

        // Skip if reminder already sent
        if (invoiceData.reminder_sent) continue;

        // Get contractor info
        let contractorName = 'Your contractor';
        let contractorEmail = null;
        if (projectData.contractor_ref) {
          const contractorDoc = await projectData.contractor_ref.get();
          if (contractorDoc.exists) {
            const cd = contractorDoc.data();
            contractorName = cd.contractor_profile?.business_name || 'Your contractor';
            contractorEmail = cd.email;
          }
        }

        const clientName = (projectData.client_name || 'there').split(' ')[0];
        const projectName = projectData.project_name || 'Your Project';
        const milestoneName = invoiceData.milestone_name || 'Milestone';
        const amount = invoiceData.amount || 0;
        const fmtAmount = `$${Number(amount).toLocaleString('en-US', { minimumFractionDigits: 2 })}`;
        const projectLink = `https://projectpulsehub.com/join/${projectDoc.id}`;

        const apiKey = sendgridApiKey.value();
        if (!apiKey) continue;
        sgMail.setApiKey(apiKey);

        const emailHtml = `<!DOCTYPE html><html><head><meta charset="UTF-8"></head>
        <body style="font-family: -apple-system, sans-serif; margin: 0; padding: 0; background: #f8f9fa;">
          <table width="100%" cellpadding="0" cellspacing="0" style="background: #f8f9fa; padding: 20px 0;"><tr><td align="center">
            <table width="600" cellpadding="0" cellspacing="0" style="background: white; border-radius: 12px; overflow: hidden;">
              <tr><td style="background: linear-gradient(135deg, #F59E0B, #D97706); color: white; padding: 30px; text-align: center;">
                <h1 style="margin: 0; font-size: 24px;">Payment Reminder</h1>
              </td></tr>
              <tr><td style="padding: 30px;">
                <p>Hi <strong>${clientName}</strong>,</p>
                <p>You have an outstanding invoice from <strong>${contractorName}</strong> for work on <strong>${projectName}</strong>.</p>
                <div style="background: #fffbeb; border-left: 4px solid #F59E0B; padding: 18px; margin: 20px 0; border-radius: 8px;">
                  <p style="margin: 0 0 4px; font-weight: 600; font-size: 18px;">${milestoneName}</p>
                  <p style="margin: 0; font-size: 22px; font-weight: 700; color: #D97706;">${fmtAmount}</p>
                </div>
                <p style="text-align: center;">
                  <a href="${projectLink}" style="display: inline-block; padding: 14px 32px; background: linear-gradient(135deg, #F59E0B, #D97706); color: white; text-decoration: none; border-radius: 8px; font-weight: 600;">Pay Now &rarr;</a>
                </p>
                <p style="font-size: 13px; color: #6b7280; margin-top: 24px;">If you've already paid outside the app, your contractor can mark this invoice as paid.</p>
              </td></tr>
              <tr><td style="text-align: center; padding: 20px; color: #a0aec0; font-size: 11px;">
                <p style="margin: 0;">${contractorName}</p>
                <p style="margin: 4px 0 0;">Powered by ProjectPulse</p>
              </td></tr>
            </table>
          </td></tr></table>
        </body></html>`;

        try {
          await sgMail.send({
            to: clientEmail,
            from: { email: sendgridFromEmail.value(), name: contractorName },
            replyTo: contractorEmail || sendgridFromEmail.value(),
            subject: `Payment Reminder: ${fmtAmount} for ${milestoneName}`,
            html: emailHtml,
            trackingSettings: { clickTracking: { enable: false, enableText: false } },
          });

          await invoiceDoc.ref.update({ reminder_sent: true, reminder_sent_at: FieldValue.serverTimestamp() });
          remindersSent++;
          console.log(`✅ Payment reminder sent to ${clientEmail} for ${invoiceData.invoice_number}`);
        } catch (error) {
          console.error(`❌ Reminder email error for ${invoiceData.invoice_number}:`, error);
        }
      }
    }

    console.log(`Payment reminder check complete: ${remindersSent} reminders sent`);
  }
);
