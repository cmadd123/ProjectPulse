const sgMail = require('@sendgrid/mail');

// Get API key from command line argument
const apiKey = process.argv[2];

if (!apiKey) {
  console.error('Usage: node test-sendgrid.js YOUR_SENDGRID_API_KEY');
  process.exit(1);
}

sgMail.setApiKey(apiKey);

const msg = {
  to: 'test@example.com', // This won't actually send
  from: 'noreply@projectpulsehub.com', // Your verified sender
  subject: 'SendGrid Test',
  text: 'Testing SendGrid configuration',
  html: '<strong>Testing SendGrid configuration</strong>',
};

sgMail
  .send(msg)
  .then(() => {
    console.log('✅ SendGrid test PASSED');
    console.log('Email would be sent from: noreply@projectpulsehub.com');
  })
  .catch((error) => {
    console.error('❌ SendGrid test FAILED');
    console.error('Error:', error.message);
    if (error.response) {
      console.error('Response body:', error.response.body);
    }
  });
