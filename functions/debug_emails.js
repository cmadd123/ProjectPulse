// Debug logging additions for email Cloud Functions
// Add these console.log statements after each early return condition

// In sendMilestoneStartedEmail:
exports.sendMilestoneStartedEmail = onDocumentCreated(
  {
    document: 'notifications/{notificationId}',
    secrets: [sendgridApiKey],
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      console.log('❌ Milestone started email: No snap');
      return;
    }
    const notificationData = snap.data();
    console.log('📧 Milestone started email triggered, type:', notificationData.type);

    if (notificationData.type !== 'milestone_started') {
      console.log('❌ Not milestone_started type, skipping');
      return;
    }
    if (notificationData.email_sent) {
      console.log('❌ Email already sent, skipping');
      return;
    }

    const apiKey = sendgridApiKey.value();
    if (!apiKey) {
      console.log('❌ No SendGrid API key found');
      return;
    }
    sgMail.setApiKey(apiKey);

    try {
      const clientRef = notificationData.recipient_ref;
      if (!clientRef) {
        console.log('❌ No client ref found');
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

      console.log(`✅ All checks passed, sending email to ${clientEmail}`);

      // ... rest of email sending logic

      await snap.ref.update({ email_sent: true, email_sent_at: FieldValue.serverTimestamp() });
      console.log(`✅ Milestone started email sent to ${clientEmail}`);
    } catch (error) {
      console.error('❌ Error sending milestone started email:', error);
      await snap.ref.update({ email_sent: false, email_error: error.message });
    }
  }
);
