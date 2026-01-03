/**
 * Send a test welcome email to yourself
 * Usage: npx tsx send-test-email.ts <your-email>
 */

import { getWelcomeEmailHTML, getWelcomeEmailText } from './src/emailTemplate';

const RESEND_API_KEY = process.env.RESEND_API_KEY;
const FROM_EMAIL = 'support@quillstack.io';
const FROM_NAME = 'QuillStack Team';

async function sendTestEmail(toEmail: string) {
  if (!RESEND_API_KEY) {
    console.error('❌ RESEND_API_KEY environment variable not set');
    console.log('');
    console.log('Run: wrangler secret list to see your secrets');
    console.log('Or set it manually: export RESEND_API_KEY=re_...');
    process.exit(1);
  }

  console.log('📧 Sending test welcome email...');
  console.log(`   To: ${toEmail}`);
  console.log(`   From: ${FROM_NAME} <${FROM_EMAIL}>`);
  console.log('');

  // Extract first name from email (or use "there")
  const firstName = toEmail.split('@')[0].split('.')[0] || 'there';
  const capitalizedFirstName = firstName.charAt(0).toUpperCase() + firstName.slice(1);

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${RESEND_API_KEY}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      from: `${FROM_NAME} <${FROM_EMAIL}>`,
      to: [toEmail],
      subject: 'Welcome to QuillStack Beta',
      html: getWelcomeEmailHTML(capitalizedFirstName),
      text: getWelcomeEmailText(capitalizedFirstName)
    })
  });

  const data = await response.json();

  if (response.ok) {
    console.log('✅ Test email sent successfully!');
    console.log('   Email ID:', data.id);
    console.log('');
    console.log('📬 Check your inbox at:', toEmail);
  } else {
    console.error('❌ Failed to send email');
    console.error(JSON.stringify(data, null, 2));
    process.exit(1);
  }
}

// Get email from command line args
const toEmail = process.argv[2];

if (!toEmail) {
  console.error('Usage: npx tsx send-test-email.ts <email>');
  console.error('');
  console.error('Example: npx tsx send-test-email.ts mike@example.com');
  process.exit(1);
}

sendTestEmail(toEmail);
