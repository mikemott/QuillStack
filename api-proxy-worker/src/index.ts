/**
 * QuillStack API Proxy Worker
 *
 * CloudFlare Worker that proxies Anthropic API requests with:
 * - Per-user credits tracking
 * - Rate limiting
 * - Usage analytics
 * - Graceful error handling
 */

interface Env {
  ANTHROPIC_API_KEY: string;
  CREDITS_KV: KVNamespace;
}

interface BetaUser {
  betaCode: string;
  creditsRemaining: number;
  creditsTotal: number;
  createdAt: string;
  lastUsedAt: string;
  requestCount: number;
}

interface UsageStats {
  inputTokens: number;
  outputTokens: number;
  timestamp: string;
}

// Cost per million tokens (in credits, where 1 credit = $0.01)
const COST_PER_INPUT_TOKEN = 3 / 1_000_000;  // $3 per million = 0.000003 per token
const COST_PER_OUTPUT_TOKEN = 15 / 1_000_000; // $15 per million = 0.000015 per token

// Default credits per beta user (500 credits = $5.00)
const DEFAULT_CREDITS = 500;

// Rate limiting: max requests per minute
const MAX_REQUESTS_PER_MINUTE = 10;

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    // CORS headers
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Beta-Code',
    };

    // Handle OPTIONS request for CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    // Only allow POST requests
    if (request.method !== 'POST') {
      return new Response('Method not allowed', {
        status: 405,
        headers: corsHeaders
      });
    }

    try {
      // Extract beta code from header
      const betaCode = request.headers.get('X-Beta-Code');
      if (!betaCode) {
        return new Response(JSON.stringify({
          error: 'Missing beta code',
          message: 'Please enter your beta code in Settings to use AI features.'
        }), {
          status: 401,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Get or create user record
      const user = await getOrCreateUser(env, betaCode);

      // Check if user has credits remaining
      if (user.creditsRemaining <= 0) {
        return new Response(JSON.stringify({
          error: 'Credits exhausted',
          message: 'Your beta credits have been used up. The app will continue to work with basic OCR.',
          creditsRemaining: 0,
          creditsTotal: user.creditsTotal
        }), {
          status: 402,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Rate limiting check
      const rateLimitKey = `ratelimit:${betaCode}:${Math.floor(Date.now() / 60000)}`;
      const requestsThisMinute = parseInt(await env.CREDITS_KV.get(rateLimitKey) || '0');

      if (requestsThisMinute >= MAX_REQUESTS_PER_MINUTE) {
        return new Response(JSON.stringify({
          error: 'Rate limited',
          message: 'Too many requests. Please wait a minute and try again.'
        }), {
          status: 429,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      // Increment rate limit counter (expires after 2 minutes)
      await env.CREDITS_KV.put(rateLimitKey, String(requestsThisMinute + 1), { expirationTtl: 120 });

      // Forward request to Anthropic API
      const requestBody = await request.json();

      const anthropicResponse = await fetch('https://api.anthropic.com/v1/messages', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': env.ANTHROPIC_API_KEY,
          'anthropic-version': '2023-06-01'
        },
        body: JSON.stringify(requestBody)
      });

      if (!anthropicResponse.ok) {
        const errorText = await anthropicResponse.text();
        return new Response(JSON.stringify({
          error: 'API request failed',
          message: 'Failed to process request. Please try again.',
          status: anthropicResponse.status
        }), {
          status: anthropicResponse.status,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' }
        });
      }

      const responseData = await anthropicResponse.json() as any;

      // Calculate token usage and deduct credits
      const inputTokens = responseData.usage?.input_tokens || 0;
      const outputTokens = responseData.usage?.output_tokens || 0;
      const creditsUsed = Math.ceil(
        (inputTokens * COST_PER_INPUT_TOKEN + outputTokens * COST_PER_OUTPUT_TOKEN) * 100
      ) / 100; // Round to 2 decimal places

      // Update user credits
      user.creditsRemaining = Math.max(0, user.creditsRemaining - creditsUsed);
      user.lastUsedAt = new Date().toISOString();
      user.requestCount += 1;

      await env.CREDITS_KV.put(`user:${betaCode}`, JSON.stringify(user));

      // Log usage stats
      const stats: UsageStats = {
        inputTokens,
        outputTokens,
        timestamp: new Date().toISOString()
      };
      await env.CREDITS_KV.put(
        `stats:${betaCode}:${Date.now()}`,
        JSON.stringify(stats),
        { expirationTtl: 60 * 60 * 24 * 30 } // Keep for 30 days
      );

      // Add credits info to response headers
      const responseHeaders = {
        ...corsHeaders,
        'Content-Type': 'application/json',
        'X-Credits-Remaining': String(user.creditsRemaining),
        'X-Credits-Used': String(creditsUsed),
        'X-Credits-Total': String(user.creditsTotal)
      };

      return new Response(JSON.stringify(responseData), {
        status: 200,
        headers: responseHeaders
      });

    } catch (error) {
      console.error('Proxy error:', error);
      return new Response(JSON.stringify({
        error: 'Internal server error',
        message: 'An unexpected error occurred. Please try again.'
      }), {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' }
      });
    }
  }
};

async function getOrCreateUser(env: Env, betaCode: string): Promise<BetaUser> {
  const userKey = `user:${betaCode}`;
  const existingUser = await env.CREDITS_KV.get(userKey);

  if (existingUser) {
    return JSON.parse(existingUser) as BetaUser;
  }

  // Create new user with default credits
  const newUser: BetaUser = {
    betaCode,
    creditsRemaining: DEFAULT_CREDITS,
    creditsTotal: DEFAULT_CREDITS,
    createdAt: new Date().toISOString(),
    lastUsedAt: new Date().toISOString(),
    requestCount: 0
  };

  await env.CREDITS_KV.put(userKey, JSON.stringify(newUser));

  return newUser;
}
