/**
 * Beta Registration API Endpoint
 * CloudFlare Pages Function
 */

interface Env {
  CREDITS_KV: KVNamespace; // Shared with API proxy
}

interface BetaUser {
  betaCode: string;
  email: string;
  firstName: string;
  lastName: string;
  creditsRemaining: number;
  creditsTotal: number;
  createdAt: string;
  lastUsedAt: string;
  requestCount: number;
  source: 'testflight' | 'registration';
}

/**
 * Generate a unique beta code from email
 * Format: BETA-XXXX
 */
function generateBetaCode(email: string): string {
  // Create hash from email
  let hash = 0;
  for (let i = 0; i < email.length; i++) {
    hash = ((hash << 5) - hash) + email.charCodeAt(i);
    hash = hash & hash;
  }

  // Add timestamp component for uniqueness
  const timestamp = Date.now();
  const combined = Math.abs(hash) + timestamp;

  // Convert to 4-digit code
  const code = (combined % 10000).toString().padStart(4, '0');
  return `BETA-${code}`;
}

/**
 * Validate email format
 */
function isValidEmail(email: string): boolean {
  const re = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return re.test(email);
}

export const onRequestPost: PagesFunction<Env> = async (context) => {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Content-Type': 'application/json'
  };

  try {
    const body = await context.request.json() as {
      email: string;
      firstName?: string;
    };

    // Validate required fields
    if (!body.email) {
      return new Response(JSON.stringify({
        error: 'Email address is required'
      }), {
        status: 400,
        headers: corsHeaders
      });
    }

    // Validate email format
    if (!isValidEmail(body.email)) {
      return new Response(JSON.stringify({
        error: 'Please enter a valid email address'
      }), {
        status: 400,
        headers: corsHeaders
      });
    }

    const email = body.email.toLowerCase().trim();
    const firstName = body.firstName?.trim() || '';

    // Check if email already registered
    const existingUsers = await context.env.CREDITS_KV.list({ prefix: 'user:' });
    for (const key of existingUsers.keys) {
      const userData = await context.env.CREDITS_KV.get(key.name);
      if (userData) {
        const user: BetaUser = JSON.parse(userData);
        // Skip records without email (e.g., test records from API proxy)
        if (user.email && user.email.toLowerCase() === email) {
          // Return existing code
          return new Response(JSON.stringify({
            betaCode: user.betaCode,
            message: 'Welcome back! Here\'s your existing beta code.'
          }), {
            status: 200,
            headers: corsHeaders
          });
        }
      }
    }

    // Generate new beta code
    const betaCode = generateBetaCode(email);

    // Create beta user record
    const betaUser: BetaUser = {
      betaCode,
      email,
      firstName,
      lastName: '',
      creditsRemaining: 500,
      creditsTotal: 500,
      createdAt: new Date().toISOString(),
      lastUsedAt: new Date().toISOString(),
      requestCount: 0,
      source: 'registration'
    };

    // Store in shared KV namespace
    await context.env.CREDITS_KV.put(
      `user:${betaCode}`,
      JSON.stringify(betaUser)
    );

    // Return success
    return new Response(JSON.stringify({
      betaCode,
      creditsRemaining: 500,
      creditsTotal: 500
    }), {
      status: 200,
      headers: corsHeaders
    });

  } catch (error) {
    console.error('Registration error:', error);
    return new Response(JSON.stringify({
      error: 'Something went wrong. Please try again.'
    }), {
      status: 500,
      headers: corsHeaders
    });
  }
};

// Handle OPTIONS for CORS preflight
export const onRequestOptions: PagesFunction = async () => {
  return new Response(null, {
    headers: {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    }
  });
};
