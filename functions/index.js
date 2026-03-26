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
