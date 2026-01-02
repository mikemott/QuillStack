/**
 * TestFlight Welcome Email Worker
 *
 * Cloudflare Worker that runs every 15 minutes to:
 * 1. Fetch all accepted TestFlight beta testers via App Store Connect API
 * 2. Check which testers haven't received welcome emails yet
 * 3. Send personalized welcome emails via Resend
 * 4. Track sent emails in Cloudflare KV to prevent duplicates
 */

import { generateJWT } from './jwt';
import { fetchBetaTesters, BetaTester } from './appStoreConnect';
import { sendWelcomeEmail } from './resend';

/**
 * Environment bindings and secrets
 */
export interface Env {
  // KV namespace binding
  SENT_EMAILS: KVNamespace;

  // App Store Connect credentials (secrets)
  APP_STORE_ISSUER_ID: string;
  APP_STORE_KEY_ID: string;
  APP_STORE_PRIVATE_KEY: string;

  // App Store Connect config (public var)
  APP_STORE_APP_ID: string;

  // Resend credentials (secret)
  RESEND_API_KEY: string;

  // Email config (public vars)
  FROM_EMAIL: string;
  FROM_NAME: string;
}

/**
 * Stored email record in KV
 */
interface SentEmailRecord {
  email: string;
  sentAt: string;
}

/**
 * Worker result for logging
 */
interface WorkerResult {
  success: boolean;
  testersChecked: number;
  emailsSent: number;
  errors: string[];
}

export default {
  /**
   * Scheduled handler - runs every 15 minutes via cron trigger
   */
  async scheduled(
    event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    console.log('🚀 TestFlight welcome email check started');

    const result: WorkerResult = {
      success: true,
      testersChecked: 0,
      emailsSent: 0,
      errors: []
    };

    try {
      // Step 1: Generate JWT for App Store Connect authentication
      console.log('🔑 Generating App Store Connect JWT...');
      const jwt = await generateJWT(
        env.APP_STORE_ISSUER_ID,
        env.APP_STORE_KEY_ID,
        env.APP_STORE_PRIVATE_KEY
      );

      // Step 2: Fetch all accepted beta testers
      console.log('📱 Fetching beta testers from App Store Connect...');
      const testers = await fetchBetaTesters(jwt, env.APP_STORE_APP_ID);
      result.testersChecked = testers.length;
      console.log(`✅ Found ${testers.length} accepted testers`);

      // Step 3: Filter to new testers (not in KV)
      console.log('🔍 Checking for new testers...');
      const newTesters: BetaTester[] = [];

      for (const tester of testers) {
        const alreadySent = await env.SENT_EMAILS.get(tester.id);
        if (!alreadySent) {
          newTesters.push(tester);
        }
      }

      console.log(`📧 ${newTesters.length} new testers to email`);

      // Step 4: Send welcome emails to new testers
      if (newTesters.length > 0) {
        for (const tester of newTesters) {
          try {
            console.log(`📤 Sending welcome email to ${tester.email}...`);

            await sendWelcomeEmail(
              tester,
              env.RESEND_API_KEY,
              env.FROM_EMAIL,
              env.FROM_NAME
            );

            // Step 5: Mark as sent in KV
            const record: SentEmailRecord = {
              email: tester.email,
              sentAt: new Date().toISOString()
            };

            await env.SENT_EMAILS.put(
              tester.id,
              JSON.stringify(record),
              {
                // Keep for 1 year
                expirationTtl: 60 * 60 * 24 * 365
              }
            );

            result.emailsSent++;
            console.log(`✅ Welcome email sent to ${tester.email}`);
          } catch (error) {
            const errorMessage = error instanceof Error
              ? error.message
              : String(error);

            console.error(`❌ Failed to email ${tester.email}:`, errorMessage);
            result.errors.push(`${tester.email}: ${errorMessage}`);
            result.success = false;
          }
        }
      } else {
        console.log('✨ No new testers - all caught up!');
      }

      // Log final result
      console.log(JSON.stringify({
        event: 'testflight_check_complete',
        timestamp: new Date().toISOString(),
        result
      }));

      console.log('🏁 TestFlight welcome email check completed');
    } catch (error) {
      const errorMessage = error instanceof Error
        ? error.message
        : String(error);

      console.error('❌ Worker failed:', errorMessage);
      result.success = false;
      result.errors.push(errorMessage);

      console.log(JSON.stringify({
        event: 'testflight_check_failed',
        timestamp: new Date().toISOString(),
        result
      }));

      throw error;
    }
  },

  /**
   * HTTP fetch handler - for manual triggers and testing
   * Requires Bearer token authentication matching RESEND_API_KEY
   */
  async fetch(
    request: Request,
    env: Env,
    ctx: ExecutionContext
  ): Promise<Response> {
    // Simple authentication
    const authHeader = request.headers.get('Authorization');
    const expectedAuth = `Bearer ${env.RESEND_API_KEY}`;

    if (authHeader !== expectedAuth) {
      return new Response('Unauthorized', {
        status: 401,
        headers: { 'Content-Type': 'text/plain' }
      });
    }

    // Run the same logic as scheduled
    console.log('🔧 Manual trigger initiated via HTTP request');
    await this.scheduled({} as ScheduledEvent, env, ctx);

    return new Response('Email check completed. See logs for details.', {
      status: 200,
      headers: { 'Content-Type': 'text/plain' }
    });
  }
};
