/**
 * Resend Email Client
 * Sends welcome emails to beta testers
 */

import { BetaTester } from './appStoreConnect';
import { getWelcomeEmailHTML, getWelcomeEmailText } from './emailTemplate';

interface ResendEmailRequest {
  from: string;
  to: string;
  subject: string;
  html: string;
  text: string;
  tags?: Array<{ name: string; value: string }>;
}

interface ResendEmailResponse {
  id?: string;
  error?: {
    message: string;
    name: string;
  };
}

/**
 * Send a welcome email to a beta tester via Resend
 *
 * @param tester - Beta tester information
 * @param betaCode - Unique beta access code for this tester
 * @param resendApiKey - Resend API key
 * @param fromEmail - Sender email address
 * @param fromName - Sender name
 * @returns Promise that resolves when email is sent
 */
export async function sendWelcomeEmail(
  tester: BetaTester,
  betaCode: string,
  resendApiKey: string,
  fromEmail: string,
  fromName: string
): Promise<void> {
  // Personalization
  const firstName = tester.firstName || 'there';

  const emailData: ResendEmailRequest = {
    from: `${fromName} <${fromEmail}>`,
    to: tester.email,
    subject: 'Welcome to QuillStack Beta!',
    html: getWelcomeEmailHTML(firstName, betaCode),
    text: getWelcomeEmailText(firstName, betaCode),
    tags: [
      { name: 'type', value: 'testflight-welcome' },
      { name: 'automation', value: 'cloudflare-worker' }
    ]
  };

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${resendApiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(emailData)
  });

  if (!response.ok) {
    const errorData: ResendEmailResponse = await response.json();
    throw new Error(
      `Resend API error: ${response.status} - ${errorData.error?.message || 'Unknown error'}`
    );
  }

  const result: ResendEmailResponse = await response.json();
  console.log(`Email sent successfully. Resend ID: ${result.id}`);
}
